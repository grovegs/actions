#!/bin/bash

if [ $# -ne 3 ]; then
    echo "::error::Usage: $0 <version> <stage> <templates_dir> <platforms>"
    exit 1
fi

version="$1"
stage="$2"
templates_dir="$3"
platforms="$4"

echo "::notice::Processing platforms: $platforms"
platform_patterns=$(echo "$platforms" | tr ',' '\n' | sed 's/^[[:space:]]*\(.*\)[[:space:]]*$/\1/' | awk '{print "templates/" tolower($0) "*"}' | paste -sd ' ' -)

if ! mkdir -p "${templates_dir}"; then
    echo "::error::Failed to create directory at ${templates_dir}"
    exit 1
fi

file_name=${version}.${stage}.mono
url=https://github.com/godotengine/godot/releases/download/${version}-${stage}/Godot_v${version}-${stage}_mono_export_templates.tpz
downloaded_file=${templates_dir}/${file_name}.tpz

echo "::notice::Downloading templates from $url"
if ! curl -L -o "${downloaded_file}" "${url}"; then
    echo "::error::Download failed for ${url}"
    exit 1
fi

if [ ! -f "${downloaded_file}" ]; then
    echo "::error::Downloaded file ${downloaded_file} not found!"
    exit 1
fi

echo "::notice::Extracting templates with patterns: ${platform_patterns}"
# shellcheck disable=SC2086
if ! unzip -o "${downloaded_file}" "templates/version.txt" ${platform_patterns} -d "${templates_dir}"; then
    echo "::error::Extraction failed for ${downloaded_file} with patterns ${platform_patterns}"
    exit 1
fi

rm "${downloaded_file}"
mv "${templates_dir}/templates" "${templates_dir}/${file_name}"
echo "::notice::Successfully completed template setup"
