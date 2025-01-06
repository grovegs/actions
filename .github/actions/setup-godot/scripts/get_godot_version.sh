#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"
godot_version=$(sed -n 's/.*"Godot\.NET\.Sdk": "\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/p' "${global_json_file}")

if [ -z "${godot_version}" ]; then
    echo "::error::Version not found in ${global_json_file}."
    exit 1
fi

IFS='.' read -r major minor patch <<<"${godot_version}"

if [ "${patch}" -eq 0 ]; then
    godot_version=${major}.${minor}
fi

echo "::notice::Godot version is ${godot_version}"
echo godot_version="$godot_version" >>"$GITHUB_OUTPUT"
