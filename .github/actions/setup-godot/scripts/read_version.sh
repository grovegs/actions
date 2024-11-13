#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"
version=$(sed -n 's/.*"Godot\.NET\.Sdk": "\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/p' "${global_json_file}")

if [ -z "${version}" ]; then
    echo "Error: Version not found in ${global_json_file}."
    exit 1
fi

IFS='.' read -r major minor patch <<<"{$version}"

if [ "${patch}" -eq 0 ]; then
    version=${major}.${minor}
fi

echo "${version}"
