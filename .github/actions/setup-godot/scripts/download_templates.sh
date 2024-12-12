#!/bin/bash

set -x

if [ $# -ne 3 ]; then
    echo "Usage: $0 <version> <templates_dir> <platforms>"
    exit 1
fi

version="$1"
templates_dir="$2"
platforms="$3"

platform_patterns=$(echo "$platforms" | tr ',' '\n' | sed 's/^[[:space:]]*\(.*\)[[:space:]]*$/\1/' | awk '{print "templates/" tolower($0) "*"}' | paste -sd ' ' -)

if ! mkdir -p "${templates_dir}"; then
    echo "Error: Failed to create directory at ${templates_dir}."
    exit 1
fi

file_name=${version}.stable.mono
url=https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_mono_export_templates.tpz
downloaded_file=${templates_dir}/${file_name}.tpz

if ! curl -L -o "${downloaded_file}" "${url}"; then
    echo "Error: Download failed for ${url}."
    exit 1
fi

if [ ! -f "${downloaded_file}" ]; then
    echo "Error: Downloaded file ${downloaded_file} not found!"
    exit 1
fi

# shellcheck disable=SC2086
if ! unzip -o "${downloaded_file}" "templates/version.txt" ${platform_patterns} -d "${templates_dir}"; then
    echo "Error: Extraction failed for ${downloaded_file} with patterns ${platform_patterns}."
    exit 1
fi

rm "${downloaded_file}"
mv "${templates_dir}/templates" "${templates_dir}/${file_name}"
