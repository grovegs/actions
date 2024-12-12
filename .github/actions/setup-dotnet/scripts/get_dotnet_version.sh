#!/bin/bash

set -x

if [ $# -ne 1 ]; then
    echo "Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"

dotnet_version=$(sed -n 's/.*"version": "\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/p' "${global_json_file}")

if [ -z "${dotnet_version}" ]; then
    echo "Error: .NET SDK version not found in ${global_json_file}."
    exit 1
fi

IFS='.' read -r major minor patch <<<"${dotnet_version}"

if [ "${patch}" -eq 0 ]; then
    dotnet_version=${major}.${minor}
fi

echo "${dotnet_version}"
