# Callback-Injection Loader

InstallUtil-compatible C# loader that uses **CallWindowProc** for shellcode execution instead of `CreateRemoteThread`. Use this variant when thread creation is being flagged behaviorally by EDR/AV.

## Difference from Section-Injection

| | Section-Injection | Callback-Injection |
|---|---|---|
| Execution primitive | `CreateRemoteThread` | `CallWindowProc` |
| Behavioral indicator | Thread creation in remote process | None (callback invocation) |
| When to use | Default | When CreateRemoteThread is flagged |

Both loaders share the same evasion layers: sandbox checks, AES encryption, section injection, and RW→RX memory transitions.

## Build

Same as section-injection — see `../section-injection/README.md` for the full build workflow. Just use this directory's `Loader.cs` and `compile.bat`.

## Execute

```batch
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe
```

## How callback execution works

```
1. Section injection maps shellcode into target process (RW)
2. NtProtectVirtualMemory flips remote view to RX
3. CallWindowProc(remoteView, 0, 0, 0, 0)
   └─ Invokes the shellcode address as a window procedure callback
   └─ No new thread is created in the remote process
```

## Limitations

- `CallWindowProc` executes in the **calling thread's context** — the shellcode runs synchronously
- For remote callback execution into another process, more advanced techniques are needed (thread hijacking, `QueueUserAPC`, etc.)
- This loader executes the callback in the **local** process context; for true remote callback, the section view address must be valid in the target's address space

## Requirements

- Windows 10/11 (x64)
- .NET Framework 4.x
- user32.dll available (always present on Windows with a desktop session)
