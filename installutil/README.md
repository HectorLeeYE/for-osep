# InstallUtil Loaders

PowerShell-free C# loaders executed via `InstallUtil.exe /U`. These are the modern replacement for the Word macro InstallUtil chain — no AMSI exposure, no PowerShell dependency, modern evasion techniques.

## Loaders

| Folder | Execution primitive | When to use |
|--------|---------------------|-------------|
| `section-injection/` | `CreateRemoteThread` | Default — primary initial-access vector |
| `callback-injection/` | `CallWindowProc` | When `CreateRemoteThread` is flagged behaviorally |
| `runspace-loader/` | PowerShell runspace | When you need PowerShell post-exploitation with C#-native AMSI bypass |

## Shared evasion layers

All loaders include:

- **Sandbox checks** — FLS callback check + Sleep timing check
- **AES-256-CBC** — shellcode encrypted at build time, decrypted in memory
- **Configurable target** — default `RuntimeBroker.exe` (override with `INJ_TARGET` env var)

Section-injection and callback-injection additionally include:

- **Section-based injection** — `NtCreateSection` + `NtMapViewOfSection` (avoids `VirtualAllocEx` + `WriteProcessMemory`)
- **RW→RX transitions** — memory starts RW, flipped to RX before execution (no RWX pages)

## Build workflow

See [shellcode-gen/](../shellcode-gen/README.md) for shellcode generation and encryption, then:

```batch
cd section-injection
.\compile.bat
```

## Execution

```batch
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe
```

The `/U` flag triggers the `Uninstall()` method — that's where the payload runs.

## Requirements for InstallUtil execution

- Class must inherit `System.Configuration.Install.Installer`
- Class must have `[System.ComponentModel.RunInstaller(true)]`
- Method signature: `public override void Uninstall(System.Collections.IDictionary savedState)`
- Must be .NET Framework (not .NET Core / .NET 5+)
- `/U` flag triggers `Uninstall()`; default triggers `Install()`

## Detection

See [detection-matrix.md](../detection-matrix.md) for the full detection layer mapping.
