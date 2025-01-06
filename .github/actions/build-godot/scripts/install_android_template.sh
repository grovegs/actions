#!/bin/bash

if [ $# -ne 3 ]; then
    echo "::error::Usage: $0 <project_dir> <templates_dir> <godot_version>"
    exit 1
fi

project_dir="$1"
templates_dir="$2"
godot_version="$3"

echo "::notice::Installing Android template for Godot ${godot_version}"

template_dir=${templates_dir}/${godot_version}.stable.mono
android_source="${template_dir}/android_source.zip"
android_dir="${project_dir}/android"
build_dir="${android_dir}/build"

if ! mkdir -p "${build_dir}"; then
    echo "::error::Failed to create directory at ${build_dir}"
    exit 1
fi

if ! unzip -o "${android_source}" -d "${build_dir}"; then
    echo "::error::Extraction failed for ${android_source}"
    exit 1
fi

if ! cp "${template_dir}/version.txt" "${android_dir}/.build_version"; then
    echo "::error::Failed to copy version file to ${android_dir}/.build_version"
    exit 1
fi

if ! touch "${build_dir}/.gdignore"; then
    echo "::error::Failed to create .gdignore file in ${build_dir}"
    exit 1
fi

echo "::notice::Android template installation completed successfully"
