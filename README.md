# for-osep

A collection of modern, evasive payloads and loaders for OSEP/PEN-300 engagements.

## Contents

| Folder | Description |
|--------|-------------|
| installutil/ | PowerShell-free C# loaders |
| shellcode-gen/ | Shellcode generation utilities |
| aes-loaders/ | AES-encrypted shellcode runners (reference) |
| hta-delivery/ | HTA-based delivery methods |
| amsi-bypass/ | AMSI bypass script (reference) |

## 🎯 OSEP Exam Tips

### Quick Start
1. **Build everything**: `build.bat`
2. **Configure C2 IPs** in all HTA files: Search for `YOUR_C2_IP_HERE`
3. **Test AES loader**: `aes-loaders/aes-normal-runner/out/aes-normal-runner.exe`

### Recommended Exam Chain
```
HTA Delivery (http-decode-method) 
  → AES-encrypted payload 
  → AES-256-CBC decryption 
  → Section injection (RW→RX) 
  → Process hollowing / DLL injection
```

### Evasion Layers (Priority Order)
1. **AMSI Bypass**: Kernel patching (E_INVALIDARG) - most reliable
2. **AES-256 Encryption**: Encrypt shellcode at build time
3. **Section Injection**: Avoid VirtualAllocEx (signature-based)
4. **Memory Protection Flip**: RW→RX transition
5. **Sandbox Detection**: FLS check + Sleep timing

### Key Files for OSEP
- `installutil/runspace-loader/Loader.cs` - .NET AMSI bypass
- `installutil/section-injection/Loader.cs` - Section mapping + RW→RX
- `aes-loaders/aes-normal-runner/Program.cs` - AES-encrypted payload runner
- `shellcode-gen/aes-encrypt-shellcode.ps1` - Encrypt your payloads

### Common Pitfalls
- ❌ Hardcoded C2 IPs in HTA files
- ❌ Using notepad.exe as target (heavily monitored)
- ❌ Multi-line Base64 in VBScript without concatenation
- ❌ Forgetting to quote paths (username with spaces breaks execution)
- ❌ Using VirtualAllocEx directly (signature detection)

### Exam-Specific Notes
- **Windows 10/11**: Focus on AES loaders + AMSI bypass
- **Detection Evasion**: Section injection is cleaner than process hollowing
- **PowerShell**: Always use AMSI bypass before executing payloads
- **InstallUtil**: The `/U` flag runs `Uninstall()`, not `Main()` - design accordingly

---
