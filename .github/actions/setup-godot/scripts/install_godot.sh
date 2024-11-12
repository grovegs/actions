#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <version> <path> <runner_os>"
    exit 1
fi

version="$1"
path="$2"
runner_os="$3"

case "$runner_os" in
Linux)
    executable_file="${path}/Godot_v${version}-stable_mono_linux_x86_64/Godot_v${version}-stable_mono_linux.x86_64"
    ;;
macOS)
    executable_file="${path}/Godot_v${version}-stable_mono_macos.universal/Godot.app/Contents/MacOS/Godot"
    ;;
Windows)
    executable_file="${path}/Godot_v${version}-stable_mono_win64_console.exe"
    ;;
*)
    echo "Error: Unsupported platform '$runner_os'"
    exit 1
    ;;
esac

if [ ! -f "$executable_file" ]; then
    echo "Error: File '$executable_file' not found!"
    exit 1
fi

echo "$executable_file"
