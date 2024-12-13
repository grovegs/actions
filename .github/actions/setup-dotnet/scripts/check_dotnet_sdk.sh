#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <sdk_version>"
    exit 1
fi

sdk_version="$1"

if [ -z "${sdk_version}" ]; then
    echo "Error: SDK version not provided."
    exit 1
fi

IFS='.' read -r major minor patch <<<"${sdk_version}"

if [ -z "${major}" ] || [ -z "${minor}" ] || [ -z "${patch}" ]; then
    echo "Error: Invalid SDK version format. Expected format: <major>.<minor>.<patch>"
    exit 1
fi

if dotnet --list-sdks | grep -q "^${major}.${minor}.${patch}"; then
    echo "true"
else
    echo "false"
fi
