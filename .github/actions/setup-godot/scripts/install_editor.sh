#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <runner_os>"
    exit 1
fi

version="$1"
runner_os="$2"

case ${runner_os} in
Linux)
    godot_executable=~/.godot/Godot_v${version}/Godot_v${version}-stable_mono_linux.x86_64
    godot_sharp=~/.godot/Godot_v${version}/GodotSharp
    ;;
macOS)
    godot_executable=~/.godot/Godot_v${version}.app/Contents/MacOS/Godot
    godot_sharp=~/.godot/Godot_v${version}.app/Contents/Resources/GodotSharp
    ;;
*)
    echo "Error: Unsupported platform ${runner_os}."
    exit 1
    ;;
esac

if [ ! -f "${godot_executable}" ]; then
    echo "Error: File ${godot_executable} not found!"
    exit 1
fi

if [ ! -d "${godot_sharp}" ]; then
    echo "Error: Directory ${godot_sharp} not found!"
    exit 1
fi

if [ -L "/usr/local/bin/godot" ]; then
    echo "Removing existing Godot symlink..."
    sudo rm -f /usr/local/bin/godot
fi

if [ -L "/usr/local/bin/GodotSharp" ]; then
    echo "Removing existing GodotSharp symlink..."
    sudo rm -f /usr/local/bin/GodotSharp
fi

sudo ln -s "${godot_executable}" /usr/local/bin/godot
sudo ln -s "${godot_sharp}" /usr/local/bin/GodotSharp
