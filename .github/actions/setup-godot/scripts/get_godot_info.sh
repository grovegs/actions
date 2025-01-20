#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"

# Extract the Godot.NET.Sdk line
sdk_line=$(grep '"Godot\.NET\.Sdk":' "${global_json_file}")

# Extract the full version (strip surrounding characters)
full_version=${sdk_line#*: \"}   # Remove everything up to ": "
full_version=${full_version%\"*} # Remove trailing quote

if [ -z "${full_version}" ]; then
    echo "::error::Version not found in ${global_json_file}."
    exit 1
fi

# Extract version and stage using string replacement
version=${full_version%-*} # Remove everything after the last '-'
stage=${full_version#*-}   # Remove everything up to and including the first '-'

# If there's no '-' in the version, set stage to 'stable'
if [ "${stage}" == "${full_version}" ]; then
    stage="stable"
fi

# Parse major, minor, and patch
IFS='.' read -r major minor patch <<<"${version}"

if [ "${patch}" -eq 0 ]; then
    version=${major}.${minor}
fi

# Output results
echo "::notice::Godot version is ${version}"
echo "::notice::Godot stage is ${stage}"
echo version="$version" >>"$GITHUB_OUTPUT"
echo stage="$stage" >>"$GITHUB_OUTPUT"
