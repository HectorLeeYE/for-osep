#!/usr/bin/env bash
# =============================================================================
# NimSyscallPacker — Linux setup + compile helper
#
# Installs Nim + MinGW-w64 + the required nimble dependencies, then compiles
# the packer. After that, use NimSyscallLoader to pack msfvenom shellcode.
#
# Usage:
#   bash nimsyscallpacker/build.sh setup    # install toolchain + deps
#   bash nimsyscallpacker/build.sh compile  # compile NimSyscallLoader.nim
# =============================================================================
set -euo pipefail

MODE="${1:-setup}"
REPO_DIR="${NIM_SYSCALL_REPO:-$HOME/NimSyscallPacker}"

echo "[*] NimSyscallPacker (Linux, best-effort — Windows is the author's tested target)"

if [ "$MODE" = "setup" ]; then
    echo "[*] Installing nim + mingw-w64 (Debian/Kali) ..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y nim mingw-w64 git python3 python3-pip
    else
        echo "[!] apt-get not found — install nim + mingw-w64 manually" >&2
    fi

    echo "[*] Installing nimble dependencies ..."
    nimble install -y nimcrypto@0.6.0 docopt ptr_math winim "https://github.com/S3cur3Th1sSh1t/nim-strenc/"

    echo "[*] Installing donut (for .NET assembly -> shellcode) ..."
    pip3 install --user donut-shellcode

    echo "[*] Setup complete. Clone the repo if not present:"
    echo "    git clone https://github.com/S3cur3Th1sSh1t/NimSyscallPacker \"$REPO_DIR\""

elif [ "$MODE" = "compile" ]; then
    if [ ! -d "$REPO_DIR" ]; then
        echo "[!] Repo not found at $REPO_DIR. Set NIM_SYSCALL_REPO or clone it first." >&2
        exit 1
    fi
    cd "$REPO_DIR"
    echo "[*] Compiling NimSyscallLoader.nim ..."
    nim c -d:noRES NimSyscallLoader.nim
    echo "[+] Done. Usage (check exact flags with --help):"
    echo "    ./NimSyscallLoader -f /tmp/sc.bin -o /tmp/loader.exe --unhook --indirect-syscalls"

else
    echo "Usage: $0 [setup|compile]" >&2
    exit 1
fi
