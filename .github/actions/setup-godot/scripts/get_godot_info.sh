#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"

sdk_line=$(grep '"Godot\.NET\.Sdk":' "${global_json_file}")
full_version=${sdk_line#*: \"}
full_version=${full_version%\"*}

if [ -z "${full_version}" ]; then
    echo "::error::Version not found in ${global_json_file}."
    exit 1
fi

version=${full_version%-*}
stage=${full_version#*-}

if [ "${stage}" == "${full_version}" ]; then
    stage="stable"
else
    stage=${stage//./}
fi

IFS='.' read -r major minor patch <<<"${version}"

if [ "${patch}" -eq 0 ]; then
    version=${major}.${minor}
fi

echo "::notice::Godot version is ${version}"
echo "::notice::Godot stage is ${stage}"
echo version="$version" >>"$GITHUB_OUTPUT"
echo stage="$stage" >>"$GITHUB_OUTPUT"
