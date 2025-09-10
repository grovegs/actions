#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <ios_sdk_version>"
    exit 1
fi

ios_version="$1"

echo "::notice::Installing iOS platforms for SDK version $ios_version"

echo "::notice::Running Xcode first launch setup..."
xcodebuild -runFirstLaunch || true

echo "::notice::Downloading iOS device platform..."
xcodebuild -downloadPlatform iOS || true

echo "::notice::Downloading iOS simulator platform..."
xcodebuild -downloadPlatform "iOS Simulator" || true

echo "::notice::iOS platform installation completed"