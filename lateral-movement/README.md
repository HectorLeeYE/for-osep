# Lateral Movement, Persistence & CLM Bypass

| File | Purpose |
|---|---|
| `winrm-psremoting.ps1` | WinRM/PSRemoting lateral movement — run a Sliver stager on a remote host |
| `wmi-exec.ps1` | WMI lateral movement — spawn a remote process via `Win32_Process` |
| `persistence.ps1` | Persistence — registry Run key, scheduled task, WMI event subscription |
| `clm-bypass.md` | Constrained Language Mode (CLM) bypass techniques |

All payloads are Sliver stager download cradles by default — edit the URL or
swap in your implant.

```bash
sliver > mtls --lhost <IP> --lport 443
```
