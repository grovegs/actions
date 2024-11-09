#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <platform> <version> <path>"
    exit 1
fi

platform="$1"
version="$2"
path="$3"

case "$platform" in
"linux")
    platform="linux_x86_64"
    ;;
"macos")
    platform="macos.universal"
    ;;
"windows")
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
