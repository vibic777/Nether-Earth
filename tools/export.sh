#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT:-godot}"
TARGET="${1:-all}"

mkdir -p build/windows build/linux build/android

export_one() {
  echo "Export $1 -> $2"
  "$GODOT_BIN" --headless --path . --export-release "$1" "$2"
}

case "$TARGET" in
  all)
    export_one "Windows Desktop" "build/windows/NetherEarthReloaded.exe"
    export_one "Linux" "build/linux/NetherEarthReloaded.x86_64"
    export_one "Android" "build/android/NetherEarthReloaded.apk"
    ;;
  windows) export_one "Windows Desktop" "build/windows/NetherEarthReloaded.exe" ;;
  linux) export_one "Linux" "build/linux/NetherEarthReloaded.x86_64" ;;
  android) export_one "Android" "build/android/NetherEarthReloaded.apk" ;;
  *)
    echo "Usage: tools/export.sh [all|windows|linux|android]" >&2
    exit 1
    ;;
esac
