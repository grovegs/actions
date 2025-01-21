#!/bin/bash

if [ $# -ne 4 ]; then
    echo "::error::Usage: $0 <project_dir> <templates_dir> <version> <stage>"
    exit 1
fi

project_dir="$1"
templates_dir="$2"
version="$3"
stage="$3"

echo "::notice::Installing Android template for Godot ${version}-${stage}..."

template_dir=${templates_dir}/${version}.${stage}.mono
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
