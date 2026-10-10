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
HTA files executed by `mshta.exe`. Multiple delivery methods for getting a payload onto the target and running it through `installutil.exe /U`.

| Folder | Technique |
|---|---|
| `black.hta` | bitsadmin download + certutil decode + InstallUtil — LOLBin-heavy |
| `red.hta` | Alternate LOLBin chain |
| `certutil-method/` | certutil download + decode + InstallUtil — simpler, uses monitored LOLBins |
| `self-decode-method/` | Embedded Base64 payload decoded via VBScript (MSXML2 + ADODB.Stream) — no bitsadmin/certutil |
| `http-decode-method/` | HTTP download via MSXML2.XMLHTTP + decode via MSXML2 + write via ADODB.Stream + InstallUtil — no LOLBins, HTA stays ~2KB |

---

### `installutil/`
PowerShell-free InstallUtil loaders. Executed via `InstallUtil.exe /U` — no AMSI exposure, no PowerShell dependency. The modern replacement for the Word macro InstallUtil chain.

| Folder | Technique |
|---|---|
| `section-injection/` | AES-encrypted shellcode + `NtCreateSection`/`NtMapViewOfSection` injection with RW→RX transitions. Targets RuntimeBroker.exe by default. |
| `callback-injection/` | Local execution via `CallWindowProc` callback — no `CreateThread`/`CreateRemoteThread` at all. For when any thread creation is flagged. |
| `runspace-loader/` | C#-native AMSI bypass + PowerShell runspace. For payloads that need PowerShell post-exploitation without AMSI text signatures. |

---

### `shellcode-gen/`
Shellcode generation and encryption tooling. Use these to prepare payloads for the `installutil/` loaders.

| File | Purpose |
|---|---|
| `donut-wrapper.ps1` | Converts PE/.NET/VBS/JS assemblies to Donut shellcode with aPLib compression + Chaskey encryption. Outputs C# byte arrays. |
| `aes-encrypt-shellcode.ps1` | AES-256-CBC encrypts raw shellcode. Outputs C# byte arrays for Key, IV, and ciphertext — ready to paste into a loader. |
| `byte-array-converter.ps1` | Converts any raw binary file to a C# byte array format. |

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

## Quick Start: InstallUtil Section-Injection Workflow

End-to-end workflow for the modern PowerShell-free loader:

```powershell
# 1. Generate shellcode with Donut
cd shellcode-gen
.\donut-wrapper.ps1 -InputFile payload.exe -OutputFile shellcode.cs -Arch x64

# 2. Extract the byte array to a raw .bin (or use msfvenom -f raw)
#    Save the bytes from shellcode.cs as shellcode.bin

# 3. AES-encrypt the shellcode
.\aes-encrypt-shellcode.ps1 -InputFile shellcode.bin -OutputFile aes_data.cs

# 4. Build the loader
cd ..\installutil\section-injection
#    Paste AesKey, AesIV, EncryptedShellcode from aes_data.cs into Loader.cs
.\compile.bat

# 5. Deliver and execute
certutil -encode loader.exe loader.b64
#    Host loader.b64 and use hta-delivery/http-decode-method/loader.hta  ← recommended
#    or embed loader.b64 in hta-delivery/self-decode-method/loader.hta
#    or host it and use hta-delivery/certutil-method/loader.hta

# On target:
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U %TEMP%\svc.exe
```

See [detection-matrix.md](detection-matrix.md) for which tool addresses which detection layer.

---

## Requirements

| Tool | Used for |
|---|---|
| `msfvenom` / Sliver | Generate shellcode |
| [Donut](https://github.com/TheWover/Donut) | Convert PE/.NET assemblies to shellcode |
| Python 3 | Encryption scripts, HTTP server |
| .NET SDK / .NET Framework 4.x | Compile C# runners |
| Visual Studio / VS Code | Build C# projects (Release, x64) |

