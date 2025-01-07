#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"

if [ ! -f "${global_json_file}" ]; then
    echo "::error::File not found: ${global_json_file}"
    exit 1
fi

if [ ! -r "${global_json_file}" ]; then
    echo "::error::Cannot read file: ${global_json_file}"
    exit 1
fi

dotnet_version=$(grep -o '"version": "[^"]*"' "${global_json_file}" | sed 's/"version": "\(.*\)"/\1/')

if [ -z "${dotnet_version}" ]; then
    echo "::error::Failed to find .NET SDK version in ${global_json_file}"
    exit 1
fi

if ! [[ "${dotnet_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::Invalid version format found in ${global_json_file}: ${dotnet_version}"
    exit 1
fi

echo "::notice::Found .NET SDK version: ${dotnet_version}"
echo "dotnet_version=${dotnet_version}" >>"$GITHUB_OUTPUT"
