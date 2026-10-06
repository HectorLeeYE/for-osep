# OSEP Toolkit

A collection of offensive tools I built and used throughout my OSEP journey. The toolkit covers the full attack chain: initial access via Word macros and HTA files, shellcode encryption and delivery, process injection, AppLocker bypass, AMSI evasion, UAC bypass, lateral movement, and Sliver C2 integration (with NimSyscallPacker for syscall-based AV evasion).

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
PowerShell AMSI bypass scripts. The `amsi-bypass.ps1` patches `AmsiOpenSession` directly in memory — more reliable than the `amsiInitFailed` reflection trick which gets caught regularly. `amsi-techniques.md` documents all three approaches with code.

---

### `hta-delivery/`
HTA file executed by `mshta.exe`. Downloads a base64-encoded payload via `bitsadmin`, decodes it with `certutil`, and runs it through `installutil.exe /U`. A clean alternative to Word macros when Office isn't available on the target.

---

### `ps-loaders/`
Two PowerShell in-memory execution tools.

| File | Purpose |
|---|---|
| `ps-loader.ps1` | Kills AMSI, ETW, and script block logging before downloading and executing a payload over HTTP — nothing touches disk |
| `ps-shellcode-runner.ps1` | Reflection-based shellcode runner — resolves `VirtualAlloc`, `CreateThread`, `WaitForSingleObject` entirely via `LookupFunc` at runtime, no P/Invoke declarations |

---

### `uac-bypass/`
`fodhelper.exe` registry hijack. Writes the payload command into `HKCU\Software\Classes\ms-settings\shell\open\command`, launches `fodhelper.exe`, and cleans up. The `uac-bypass.ps1` has AMSI bypass baked in and builds all sensitive strings from char arrays to avoid static detection. Manual one-liners are also documented for when you already have a shell and just need quick elevation.

---

### `sliver/`
Sliver C2 integration — replaces msfvenom/meterpreter across the toolkit. `README.md` covers listener setup (mtls/http/https/wg/dns), implant generation, and stage listeners; `sliver2arrays.py` converts Sliver raw shellcode into C#/PowerShell/VBA/Nim byte-array syntax for the loaders and encryptors.

---

### `cs-loaders/`
Additional C# injection loaders using lower-level Windows APIs for the OSEP techniques not covered by the AES loaders: Nt* direct-API injection (`NtAllocateVirtualMemory`/`NtWriteVirtualMemory`/`NtCreateThreadEx`), APC/Early-Bird injection, dynamic API resolution (DInvoke-style), and ntdll unhooking.

---

### `applocker/`
Additional AppLocker bypass payloads beyond InstallUtil: `msbuild` inline-task execution and `regsvr32` scriptlet execution.

---

### `lateral-movement/`
WinRM/PSRemoting and WMI lateral-movement helpers, plus persistence (registry Run key, scheduled task, WMI event subscription) and a Constrained Language Mode (CLM) bypass.

---

### `nimsyscallpacker/`
Integration with [NimSyscallPacker](https://github.com/S3cur3Th1sSh1t/NimSyscallPacker) — packs Sliver shellcode/PE/C# into a Nim binary using direct/indirect syscalls, ntdll unhooking, and AMSI/ETW bypass for stronger AV evasion. See its `README.md` for the build setup and workflow.

---

## Requirements

| Tool | Used for |
|---|---|
| Sliver | C2 framework — generates shellcode/implants (replaces msfvenom/meterpreter) |
| Python 3 | Encryption scripts, format conversion, HTTP server |
| .NET SDK | Compile C# runners |
| Visual Studio / VS Code | Build C# projects (Release, x64) |
| Nim + MinGW-w64 | Build NimSyscallPacker payloads (see `nimsyscallpacker/`) |

