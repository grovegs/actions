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
    if sudo ln -sf "$path/Godot_v$version-stable_mono_linux_x86_64/Godot_$version-stable_mono_linux.x86_64" /usr/local/bin/godot; then
        echo "Linked Godot binary for Linux at /usr/local/bin/godot"
    else
        echo "Error: Failed to link Godot binary on Linux"
        exit 1
    fi
    ;;
macOS)
    if sudo ln -sf "$path/Godot_v$version-stable_mono_macos.universal/Godot.app/Contents/MacOS/Godot" /usr/local/bin/godot; then
        echo "Linked Godot binary for macOS at /usr/local/bin/godot"
    else
        echo "Error: Failed to link Godot binary on macOS"
        exit 1
    fi
    ;;
Windows)
    echo "::add-path::$path/Godot_v$version-stable_mono_win64"
    echo "Added Godot path for Windows"
    ;;
*)
    echo "Error: Unsupported platform '$runner_os'"
    exit 1
    ;;
esac

"$path/Godot_v$version-stable_mono_linux_x86_64/Godot_v$version-stable_mono_linux.x86_64" --version

if command -v godot &>/dev/null; then
    godot --version
else
    echo "Error: 'godot' command not found"
    exit 1
fi
