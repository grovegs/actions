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

if dotnet --list-sdks | grep -q "^${sdk_version}"; then
    echo "true"
else
    echo "false"
fi
