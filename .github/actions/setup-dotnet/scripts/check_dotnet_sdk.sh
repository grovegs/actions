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

dotnet --list-sdks >/tmp/installed_sdks
echo "::notice::Installed SDKs:"
cat /tmp/installed_sdks
echo ""

if grep -q "^${major}.${minor}.${patch}" /tmp/installed_sdks; then
    is_installed="true"
    echo "::notice::Exact match - .NET SDK ${sdk_version} is installed"

elif grep -q "^${major}.${minor}" /tmp/installed_sdks; then
    is_installed="true"
    installed_version=$(grep "^${major}.${minor}" /tmp/installed_sdks | head -1 | awk '{print $1}')
    echo "::notice::Compatible version found - .NET SDK ${installed_version} (compatible with requested ${sdk_version})"
else
    is_installed="false"
    echo "::warning::.NET SDK ${sdk_version} or compatible version is not installed"
fi

echo "is_installed=${is_installed}" >>"$GITHUB_OUTPUT"
