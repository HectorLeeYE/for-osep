# OSEP Toolkit

A collection of offensive tools I built and used throughout my OSEP journey. The toolkit covers the full attack chain: initial access via Word macros and HTA files, shellcode encryption and delivery, process injection, AppLocker bypass, AMSI evasion, UAC bypass, lateral movement, and Metasploit C2 integration (with NimSyscallPacker for syscall-based AV evasion).

---

## Tools

### `word-macro/`
VBA macros for Microsoft Word. Covers the full progression from basic shellcode runners to AppLocker bypass.

| Folder | Technique |
|---|---|
| `recon/` | Fingerprint the target before choosing a payload — detects AppLocker, OS arch, Office bitness |
| `caesar-cipher/` | Caesar +2 encrypted shellcode runner |
| `xor-shellcode-runner/` | 3-byte rolling XOR runner — stronger than Caesar, W^X memory model |
| `alternative-shellcode-runner/` | XOR runner using `HeapAlloc` + `EnumSystemGeoID` callback instead of `VirtualAlloc` + `CreateThread` |
| `installutil-applocker-bypass/` | Full AppLocker bypass chain — WMI process spawn, bitsadmin download, `installutil.exe /U` |

---

### `aes-loaders/`
C# shellcode runners using AES-256-CBC encryption. Shellcode is encrypted on the attacker side and decrypted in memory at runtime — nothing plaintext touches disk.

| Folder | Technique |
|---|---|
| `aes-shellcode-encryption/` | Encryptor — always start here to generate your encrypted buf |
| `aes-normal-runner/` | Self-injection via `VirtualAlloc` + `CreateThread` |
| `aes-process-injection/` | Remote injection into a target process via `CreateRemoteThread` |
| `aes-av-evasion/` | Remote injection with sandbox evasion — `VirtualAllocExNuma`, timing checks, DLL presence checks |
| `aes-process-hollowing/` | Hollows `svchost.exe` via suspended process + PEB walk — no `CreateRemoteThread` |

---

### `amsi-bypass/`
PowerShell AMSI bypass scripts. The `amsi-bypass.ps1` patches `AmsiScanBuffer` directly in memory — more reliable than the `amsiInitFailed` reflection trick which gets caught regularly. `amsi-techniques.md` documents all three approaches with code.

---

### `hta-delivery/`
HTA file executed by `mshta.exe`. Two delivery wrappers: `red.hta` runs an in-memory PowerShell download cradle (`payload.ps1`, no disk artifacts); `black.hta` downloads a base64-encoded **.NET InstallUtil payload** (`shell.exe`) via `bitsadmin`, decodes it with `certutil`, and runs it through `installutil.exe /U` (AppLocker bypass). Note that because InstallUtil only executes .NET assemblies, `shell.exe` must be a compiled C# installer payload — not a raw Go/Meterpreter implant. A clean alternative to Word macros when Office isn't available on the target.

---

### `ps-loaders/`
Two PowerShell in-memory execution tools.

| File | Purpose |
|---|---|
| `ps-loader.ps1` | Kills AMSI, ETW, and script block logging before downloading and executing a payload over HTTP — nothing touches disk |
| `ps-shellcode-runner.ps1` | Reflection-based shellcode runner — resolves `VirtualAlloc`, `CreateThread`, `WaitForSingleObject` entirely via `LookupFunc` at runtime, no P/Invoke declarations |

---

### `uac-bypass/`
`fodhelper.exe` registry hijack in two variants: the classic `DelegateExecute` trick (`uac-bypass.ps1`) and the **CurVer** variant (`uac-bypass-curver.ps1`, more reliable on newer Win10/11). Also includes **CMSTP** (`cmstp.ps1`) and **EventViewer** (`invoke-eventviewer.ps1`) UAC bypasses. The PowerShell variants have AMSI bypass baked in and build all sensitive strings from char arrays to avoid static detection.

---

### `cs-loaders/`
Additional C# injection loaders using lower-level Windows APIs for the OSEP techniques not covered by the AES loaders: Nt* direct-API injection (`NtAllocateVirtualMemory`/`NtWriteVirtualMemory`/`NtCreateThreadEx`), APC/Early-Bird injection, dynamic API resolution (DInvoke-style), and ntdll unhooking.

---

### `applocker/`
Additional AppLocker bypass payloads beyond InstallUtil: `msbuild` inline-task execution and `regsvr32` scriptlet execution.

---

### `lateral-movement/`
Lateral movement & persistence: WinRM/PSRemoting, WMI `Win32_Process`, SMB named-pipe fileless remoting (`invoke-smbremoting.ps1`), service hijack (`psexec-lat.cs`), MSSQL CLR (`mssql-clr/`), plus persistence (registry Run key, scheduled task, WMI event subscription) and a Constrained Language Mode (CLM) bypass.

---

### `nimsyscallpacker/`
Integration with [NimSyscallPacker](https://github.com/S3cur3Th1sSh1t/NimSyscallPacker) — packs raw shellcode (msfvenom)/PE/C# into a Nim binary using direct/indirect syscalls, ntdll unhooking, and AMSI/ETW bypass for stronger AV evasion. See its `README.md` for the build setup and workflow.

---

### `supersharpshooter/`
Integration with [SuperSharpShooter](https://github.com/ScriptIdiot/SuperSharpShooter) (a fork of MDSec's SharpShooter) — an optional delivery layer that turns msfvenom raw shellcode into JScript/VBScript/HTA/VBA-macro/Excel-SLK payloads via **DotNetToJScript** (in-memory .NET through `cscript`/`wscript`/`mshta`), **squiblytwo** XSL stylesheets for `wmic`/`regsvr32`, HTML smuggling, and sandbox evasion. Use it for AppLocker bypass / initial access where PowerShell and disk EXEs are blocked. See its `README.md` for setup and step-by-step examples.

---

## Requirements

| Tool | Used for |
|---|---|
| msfvenom / msfconsole | Generate shellcode, payloads, and stagers (Metasploit) |
| Sliver (optional) | Alternative C2 — only if you prefer it over Metasploit |
| Python 3 | Encryption scripts, format conversion |
| Apache2 | HTTP file hosting (`/var/www/html/`) |
| .NET SDK | Compile C# runners |
| Visual Studio / VS Code | Build C# projects (Release, x64) |
| Nim + MinGW-w64 | Build NimSyscallPacker payloads (see `nimsyscallpacker/`) |
| SuperSharpShooter (optional) | DotNetToJScript / squiblytwo delivery (see `supersharpshooter/`) |

