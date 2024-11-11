#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <runner_os>"
    exit 1
fi

runner_os="$1"

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

echo "$platform"
