#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <sdk_version>"
    exit 1
fi

sdk_version="$1"

if [ -z "${sdk_version}" ]; then
    echo "::error::SDK version not provided."
    exit 1
fi

IFS='.' read -r major minor patch <<<"${sdk_version}"

if [ -z "${major}" ] || [ -z "${minor}" ] || [ -z "${patch}" ]; then
    echo "::error::Invalid SDK version format. Expected format: <major>.<minor>.<patch>"
    exit 1
fi

echo "::notice::Checking for .NET SDK version ${sdk_version}"

if dotnet --list-sdks | grep -q "^${major}.${minor}.${patch}"; then
    is_installed="true"
    echo "::notice::.NET SDK ${sdk_version} is installed"
else
    is_installed="false"
    echo "::warning::.NET SDK ${sdk_version} is not installed"
fi

echo is_installed="${is_installed}" >>"$GITHUB_OUTPUT"
