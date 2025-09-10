#!/bin/bash

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "::error::Usage: $0 <target_ios_sdk_version> <target_xcode_version>"
    exit 1
fi

target_ios_sdk_version="$1"
target_xcode_version="$2"

echo "::notice::Selecting Xcode $target_xcode_version for iOS SDK $target_ios_sdk_version"

xcode_path="/Applications/Xcode_${target_xcode_version}.app"

if [ ! -d "$xcode_path" ]; then
    echo "::error::Xcode $target_xcode_version not found at $xcode_path"
    exit 1
fi

new_dev_path="$xcode_path/Contents/Developer"

echo "::notice::Switching to Xcode at $xcode_path"
sudo xcode-select -s "$new_dev_path"

echo "::notice::Setting environment variables..."
{
    echo "DEVELOPER_DIR=$new_dev_path"
    echo "XCODE_ROOT=$xcode_path"
} >> "$GITHUB_ENV"

ios_sdk_version="$(xcrun --show-sdk-version --sdk iphoneos 2>/dev/null || echo "$target_ios_sdk_version")"
echo "::notice::Using iOS SDK version: $ios_sdk_version"
echo "ios-sdk=$ios_sdk_version" >> "$GITHUB_OUTPUT"

echo "::notice::Xcode selection completed successfully"