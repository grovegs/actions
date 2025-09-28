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

echo "::notice::global.json contents:"
cat "${global_json_file}"

sdk_section=$(awk '/"sdk"[[:space:]]*:/ {p=1} p && /^[[:space:]]*}/ {print; exit} p' "${global_json_file}")
if [ -z "${sdk_section}" ]; then
  echo "::error::No 'sdk' section found in ${global_json_file}"
  exit 1
fi

dotnet_version=$(echo "${sdk_section}" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "${dotnet_version}" ]; then
  echo "::error::Failed to find .NET SDK version in ${global_json_file}"
  exit 1
fi

if ! echo "${dotnet_version}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$'; then
  echo "::error::Invalid .NET SDK version format: ${dotnet_version}"
  exit 1
fi

echo "::notice::Found .NET SDK version: ${dotnet_version}"
echo "dotnet_version=${dotnet_version}" >> "$GITHUB_OUTPUT"
