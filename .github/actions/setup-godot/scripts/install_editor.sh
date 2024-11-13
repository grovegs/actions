#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <runner_os>"
    exit 1
fi

version="$1"
runner_os="$2"

case "${runner_os}" in
Linux)
    executable_file=~/.godot/Godot_v${version}/Godot_v${version}-stable_mono_linux.x86_64
    ;;
macOS)
    executable_file=~/.godot/Godot_v${version}.app/Contents/MacOS/Godot
    ;;
*)
    echo "Error: Unsupported platform ${runner_os}."
    exit 1
    ;;
esac

if [ ! -f "{$executable_file}" ]; then
    echo "Error: File ${executable_file} not found!"
    exit 1
fi

echo "${executable_file}"
