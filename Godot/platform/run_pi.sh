#!/bin/sh
# Starts MARS HOMER from source on a Raspberry Pi (or any Linux machine).
# Usage: platform/run_pi.sh [path-to-godot]     (default: godot on PATH)
set -e
GODOT="${1:-godot}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "python3 is required for the serial bridge: sudo apt install python3"; exit 1; }
command -v "$GODOT" >/dev/null 2>&1 || { echo "Godot 4.6 (linux arm64/x86_64) not found. Download it from godotengine.org and pass its path."; exit 1; }
# Serial devices belong to the dialout group on Raspberry Pi OS.
if ! id -nG | tr ' ' '\n' | grep -qx dialout; then
  echo "Note: add yourself to the dialout group to open /dev/rfcomm0 and USB serial ports:"
  echo "  sudo usermod -aG dialout $USER    (then log out and in again)"
fi
exec "$GODOT" --path "$HERE" "$@"
