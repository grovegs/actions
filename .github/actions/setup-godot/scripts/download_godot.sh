#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <version> <platform> <path>"
    exit 1
fi

version="$1"
path="$2"
runner_os="$3"

if ! mkdir -p "$path"; then
    echo "Failed to create directory."
    exit 1
fi

case "$runner_os" in
"Linux")
    platform="linux_x86_64"
    ;;
"macOS")
    platform="macos.universal"
    ;;
"Windows")
    platform="win64"
    ;;
*)
    echo "Error: Unsupported platform '$platform'."
    exit 1
    ;;
esac

url="https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_mono_${platform}.zip"

if ! curl -L -o "$path/$(basename "$url")" "$url"; then
    echo "Download failed."
    exit 1
fi

file_name=$(basename "$url")
echo "$path/$file_name"
