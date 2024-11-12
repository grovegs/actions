#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <version> <path> <runner_os>"
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

echo "File downloading..."
file_name=Godot_v${version}-stable_mono_${platform}
url="https://github.com/godotengine/godot/releases/download/${version}-stable/${file_name}.zip"
downloaded_file=$path/$file_name.zip

if ! curl -L -o "$downloaded_file" "$url"; then
    echo "Download failed."
    exit 1
fi

if [ ! -f "$downloaded_file" ]; then
    echo "Error: File '$downloaded_file' not found!"
    exit 1
fi

if ! unzip "$downloaded_file" -d "$path"; then
    echo "Error: Extraction failed."
    exit 1
fi

rm "$downloaded_file"

echo "File downloaded: $path"
ls "$path"
