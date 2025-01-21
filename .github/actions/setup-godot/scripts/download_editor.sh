#!/bin/bash

if [ $# -ne 3 ]; then
    echo "::error::Usage: $0 <version> <stage> <runner_os>"
    exit 1
fi

version="$1"
stage="$2"
runner_os="$3"

editor_dir=~/.godot

echo "::notice::Creating Godot directory at ${editor_dir}"
if ! mkdir -p ${editor_dir}; then
    echo "::error::Failed to create directory at ${editor_dir}"
    exit 1
fi

case ${runner_os} in
"Linux")
    platform="linux_x86_64"
    ;;
"macOS")
    platform="macos.universal"
    ;;
*)
    echo "::error::Unsupported platform ${runner_os}"
    exit 1
    ;;
esac

file_name=Godot_v${version}-${stage}_mono_${platform}
url=https://github.com/godotengine/godot/releases/download/${version}-${stage}/${file_name}.zip
downloaded_file=${editor_dir}/${file_name}.zip

echo "::notice::Downloading Godot from ${url}"
if ! curl -L -o "${downloaded_file}" "${url}"; then
    echo "::error::Download failed for ${url}"
    exit 1
fi

if [ ! -f "${downloaded_file}" ]; then
    echo "::error::Downloaded file ${downloaded_file} not found!"
    exit 1
fi

echo "::notice::Extracting ${downloaded_file}"
if ! unzip -o "${downloaded_file}" -d ${editor_dir}; then
    echo "::error::Extraction failed for ${downloaded_file}"
    exit 1
fi

rm "${downloaded_file}"

echo "::notice::Moving Godot to final location"
case "${runner_os}" in
"Linux")
    mv "${editor_dir}/Godot_v${version}-${stage}_mono_linux_x86_64" "${editor_dir}/Godot_v${version}"
    ;;
"macOS")
    mv "${editor_dir}/Godot_mono.app" "${editor_dir}/Godot_v${version}.app"
    ;;
*)
    echo "::error::Unsupported platform ${runner_os}"
    exit 1
    ;;
esac
