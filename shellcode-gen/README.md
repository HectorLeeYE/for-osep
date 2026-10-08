# Shellcode Generation & Encryption

Tooling to prepare payloads for the `installutil/` loaders. Generate shellcode with Donut, encrypt it with AES, and output C# byte arrays ready to paste into a loader.

## Files

| File | Purpose |
|------|---------|
| `donut-wrapper.ps1` | Converts PE/.NET/VBS/JS/XSL assemblies to Donut shellcode with aPLib compression + Chaskey encryption. Outputs a C# byte array. |
| `aes-encrypt-shellcode.ps1` | AES-256-CBC encrypts raw shellcode. Outputs C# byte arrays for `AesKey`, `AesIV`, and `EncryptedShellcode`. |
| `byte-array-converter.ps1` | Converts any raw binary file to a C# byte array format. |

## Workflow

```powershell
# 1. Convert a PE/.NET assembly to Donut shellcode
.\donut-wrapper.ps1 -InputFile payload.exe -OutputFile shellcode.cs -Arch x64

# 2. Extract the byte array from shellcode.cs into a raw shellcode.bin
#    (or generate raw shellcode directly with: msfvenom -f raw -o shellcode.bin ...)

# 3. AES-encrypt the shellcode
.\aes-encrypt-shellcode.ps1 -InputFile shellcode.bin -OutputFile aes_data.cs

# 4. Open aes_data.cs and copy the AesKey, AesIV, and EncryptedShellcode arrays
#    into your loader's Loader.cs (replacing the placeholder arrays)
```

## Donut flags reference

| Flag | Meaning | Values |
|------|---------|--------|
| `-i` | Input file | PE / .NET / VBS / JS / XSL |
| `-a` | Architecture | 1 = x86, 2 = x64, 3 = both |
| `-f` | Output format | 1 = binary, 2 = Base64, 6 = PowerShell |
| `-z` | Compression | 1 = none, 2 = aPLib, 3 = LZNT1, 4 = Xpress, 5 = Xpress Huffman |
| `-e` | Entropy | 1 = none, 2 = random names, 3 = random names + Chaskey encryption |
| `-o` | Output file | path |

For OSEP: always use `-a 2 -f 1 -z 2 -e 3`. The `-z 2` (aPLib) works cross-platform; `-e 3` encrypts so static signatures don't match.

## Requirements

- [Donut](https://github.com/TheWover/Donut) (`donut.exe` in the same directory or specify `-DonutPath`)
- PowerShell 5.1+
- `msfvenom` or Sliver (for raw shellcode generation)
