#!/bin/bash

set -euo pipefail

echo "::notice::Installing iOS platforms for the selected Xcode version"

echo "::notice::Running Xcode first launch setup..."
xcodebuild -runFirstLaunch || true

echo "::notice::Downloading iOS device platform..."
xcodebuild -downloadPlatform iOS || true

echo "::notice::Downloading iOS simulator platform..."
xcodebuild -downloadPlatform "iOS Simulator" || true

echo "::notice::iOS platform installation completed"