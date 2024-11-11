#!/bin/bash

if [ $# -ne 4 ]; then
    echo "Usage: $0 <version> <platform> <path> <runner_os>"
    exit 1
fi

version="$1"
platform="$2"
path="$3"
runner_os="$4"

godot="$path/Godot_v$version-stable_mono_$platform"

if [ ! -e "$godot" ] && [ "$runner_os" != "macOS" ]; then
    echo "Error: Godot binary not found at $godot"
    exit 1
fi

case "$runner_os" in
Linux)
    if ln -sf "$godot" /usr/local/bin/godot; then
        echo "Linked Godot binary for Linux at /usr/local/bin/godot"
    else
        echo "Error: Failed to link Godot binary on Linux"
        exit 1
    fi
    ;;
macOS)
    if ln -sf "$godot/Godot.app/Contents/MacOS/Godot" /usr/local/bin/godot; then
        echo "Linked Godot binary for macOS at /usr/local/bin/godot"
    else
        echo "Error: Failed to link Godot binary on macOS"
        exit 1
    fi
    ;;
Windows)
    echo "::add-path::$godot"
    echo "Added Godot path for Windows"
    ;;
*)
    echo "Error: Unsupported platform '$runner_os'"
    exit 1
    ;;
esac
