#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"

full_version=$(sed -n 's/.*"Godot\.NET\.Sdk": "\([^"]*\)".*/\1/p' "${global_json_file}")

if [ -z "${full_version}" ]; then
    echo "::error::Version not found in ${global_json_file}."
    exit 1
fi

if [[ "${full_version}" == *"-"* ]]; then
    version=${full_version%%-*}
    stage=${full_version#*-}
    stage=${stage//./}
else
    version=${full_version}
    stage="stable"
fi

IFS='.' read -r major minor patch <<<"${version}"

if [ "${patch}" = "0" ]; then
    version="${major}.${minor}"
fi

echo "::notice::Godot version is ${version}"
echo "::notice::Godot stage is ${stage}"
echo "version=${version}" >>"$GITHUB_OUTPUT"
echo "stage=${stage}" >>"$GITHUB_OUTPUT"
