#!/bin/bash

if [ $# -ne 2 ]; then
    echo "::error::Usage: $0 <version> <stage> <runner_os>"
    exit 1
fi

version="$1"
stage="$2"
runner_os="$3"

case ${runner_os} in
Linux)
    godot_executable=~/.godot/Godot_v${version}/Godot_v${version}-${stage}_mono_linux.x86_64
    godot_sharp=~/.godot/Godot_v${version}/GodotSharp
    ;;
macOS)
    godot_executable=~/.godot/Godot_v${version}.app/Contents/MacOS/Godot
    godot_sharp=~/.godot/Godot_v${version}.app/Contents/Resources/GodotSharp
    ;;
*)
    echo "::error::Unsupported platform ${runner_os}."
    exit 1
    ;;
esac

if [ ! -f "${godot_executable}" ]; then
    echo "::error::File ${godot_executable} not found!"
    exit 1
fi

if [ ! -d "${godot_sharp}" ]; then
    echo "::error::Directory ${godot_sharp} not found!"
    exit 1
fi

if [ -L "/usr/local/bin/godot" ]; then
    echo "::notice::Removing existing Godot symlink..."
    sudo rm -f /usr/local/bin/godot
fi

if [ -L "/usr/local/bin/GodotSharp" ]; then
    echo "::notice::Removing existing GodotSharp symlink..."
    sudo rm -f /usr/local/bin/GodotSharp
fi

sudo ln -s "${godot_executable}" /usr/local/bin/godot
sudo ln -s "${godot_sharp}" /usr/local/bin/GodotSharp
