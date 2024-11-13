#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <runner_os>"
    exit 1
fi

version="$1"
runner_os="$2"
editor_dir=~/.godot

if ! mkdir -p ${editor_dir}; then
    echo "Error: Failed to create directory at ${editor_dir}."
    exit 1
fi

case "${runner_os}" in
"Linux")
    platform="linux_x86_64"
    ;;
"macOS")
    platform="macos.universal"
    ;;
*)
    echo "Error: Unsupported platform ${runner_os}."
    exit 1
    ;;
esac

file_name=Godot_v${version}-stable_mono_${platform}
url=https://github.com/godotengine/godot/releases/download/${version}-stable/${file_name}.zip
downloaded_file=${editor_dir}/${file_name}.zip

if ! curl -L -o "${downloaded_file}" "${url}"; then
    echo "Error: Download failed for ${url}."
    exit 1
fi

if [ ! -f "${downloaded_file}" ]; then
    echo "Error: Downloaded file ${downloaded_file} not found!"
    exit 1
fi

if ! unzip -o "${downloaded_file}" -d ${editor_dir}; then
    echo "Error: Extraction failed for ${downloaded_file}."
    exit 1
fi

rm "${downloaded_file}"

case "${runner_os}" in
"Linux")
    mv "${editor_dir}/Godot_v${version}-stable_mono_linux_x86_64" "${editor_dir}/Godot_v${version}"
    ;;
"macOS")
    mv "${editor_dir}/Godot_mono.app" "${editor_dir}/Godot_v${version}.app"
    ;;
*)
    echo "Error: Unsupported platform ${runner_os}."
    exit 1
    ;;
esac
