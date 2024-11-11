#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <version> <platform> <path>"
    exit 1
fi

version="$1"
platform="$2"
path="$3"

mkdir -p "$path"
url="https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_mono_${platform}.zip"

if ! curl -L -o "$path/$(basename "$url")" "$url"; then
    echo "Download failed."
    exit 1
fi

file_name=$(basename "$url")
echo "$path/$file_name"
