# Handoff — osep-tools

**Last updated:** 2026-10-07 (after `21a5214 Fuck sliver, move to metasploit`)

> **Standing decisions**
> - **C2:** Metasploit (`msfvenom` + `multi/handler`). Sliver stays documented as an optional secondary only.
> - **Rust-for-Malware-Development:** out of scope, not exam-relevant.
> - **Technique code is C2-agnostic.** Every VBA/C#/PS loader takes raw shellcode or a byte array, so swapping C2 is a docs change, never a code change. Keep it that way.

---

## Status: the Sliver → Metasploit migration is DONE

All three tasks from the previous handoff closed. Verified against the tree, not just assumed:

| Was | Now |
|---|---|
| README Requirements table was Sliver-primary | `msfvenom`/`msfconsole` first; Sliver is one clearly-optional line (`README.md:90`) |
| RUNBOOK was Sliver-centric | Section 0 is a `multi/handler`; Section 2 is `msfvenom`; transports are `reverse_tcp`/`reverse_https`/`reverse_http` |
| No payload cheat sheet | `MSFVENOM.md` exists — 7 sections incl. a loader → command mapping table |
| `sliver > generate` in loader headers | Every loader header now shows the `msfvenom` equivalent |
| `nimsyscallpacker` said "packs Sliver shellcode" | Now generic (shellcode/PE/C#) with `msfvenom -f raw` examples at lines 48/51 |

`grep -rin sliver` across the repo returns only this file and the one optional-C2 line. Working tree is clean.

**Task 3 format checks (by inspection) all passed:** C# loaders want `-f csharp`, the AES/XOR encryptors take that same array and emit their own, `ps-shellcode-runner.ps1` takes `-f raw` hosted or `-f ps1` inline, the PS/HTA/lateral stagers want `-f psh`, InstallUtil wants a compiled .NET assembly plus `-f psh` text files.

---

## Open work

### 1. Lab validation — NOT RUN (highest value, do before the exam)
The format matches above were confirmed by reading code. Nothing has proved a session actually comes back. These three round-trips are the only real test:

- [ ] **Staged, hosted raw** → `msfvenom -p windows/x64/meterpreter/reverse_tcp ... EXITFUNC=thread -f raw` → host → `ps-shellcode-runner.ps1` and one `cs-loaders` runner → session.
- [ ] **Stageless, encrypted** → `meterpreter_reverse_tcp -f csharp` → `aes-shellcode-encryption.cs` → `aes-normal-runner` → session.
- [ ] **PowerShell payload** → `-f psh` served as `payload.ps1` → `ps-loader.ps1` → session.

### 2. NimSyscallPacker — packing never verified
`nimsyscallpacker/README.md` documents the build and the `msfvenom -f raw` input, but no successful pack-and-callback has been recorded. Optional / EDR-escalation only, so this is below the three round-trips.

- [ ] Build the packer once, pack a stageless raw blob, confirm a session.
- [ ] Note the exact working flags in the README (it currently says "check exact flags with `--help`").

### 3. Cosmetic — two loaders have no generation header
Every other loader carries a header comment naming the `msfvenom` command that feeds it. These two never had one:

- [ ] `aes-loaders/aes-process-hollowing/aes-process-hollowing-runner.cs`
- [ ] `word-macro/caesar-cipher/vba-caesar-cipher-encryption.cs`

---

## Known non-issues (do not "fix" these)
- **`word-macro/installutil-applocker-bypass/__pycache__/`** is on disk but **untracked**, and `.gitignore` already covers `__pycache__/` and `*.pyc`. Nothing to do.
- **`.gitignore` ignores `*.exe` while `reference/` holds committed binaries.** Only the `.sys` drivers under `reference/09 - PPL Bypass/` are tracked; the ignore rule is working as intended.
- **VBA size limit.** Stageless meterpreter is ~200KB and will not fit a single VBA module. Macros use the staged ~500B stager or a download cradle. This is documented in `MSFVENOM.md` and is a constraint, not a bug.

---

## Where things live
| File | Use it for |
|---|---|
| `README.md` | What each folder does, requirements |
| `RUNBOOK.md` | **Exam-time path.** 11 stages, organised by situation ("Office present → macro") |
| `MSFVENOM.md` | Payload generation + which command feeds which loader |
| `handoff.md` | This file — state between sessions |
