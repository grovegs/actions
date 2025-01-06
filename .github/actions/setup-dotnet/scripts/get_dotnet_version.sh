#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <global_json_file>"
    exit 1
fi

global_json_file="$1"

dotnet_version=$(sed -n 's/.*"version": "\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/p' "${global_json_file}")

if [ -z "${dotnet_version}" ]; then
    echo "::error::Failed to find .NET SDK version in ${global_json_file}"
    exit 1
fi

echo "::notice::Found .NET SDK version: ${dotnet_version}"
echo dotnet_version="$dotnet_version" >>"$GITHUB_OUTPUT"
