#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

if [ "${RUNNER_OS}" != "macOS" ]; then
  echo "::error::This action only supports macOS. Current OS: ${RUNNER_OS}"
  exit 1
fi

if ! command -v xcodebuild > /dev/null 2>&1; then
  echo "::error::xcodebuild is not installed or not in PATH"
  exit 1
fi

echo "::notice::Installing iOS platforms for the selected Xcode version"

echo "::notice::Running Xcode first launch setup"
set +e
xcodebuild -runFirstLaunch
FIRST_LAUNCH_EXIT_CODE=$?
set -e

if [ "${FIRST_LAUNCH_EXIT_CODE}" -eq 0 ]; then
  echo "::notice::Xcode first launch setup completed"
else
  echo "::warning::Xcode first launch setup returned exit code ${FIRST_LAUNCH_EXIT_CODE} (this may be normal)"
fi

echo "::notice::Downloading iOS device platform"
set +e
xcodebuild -downloadPlatform iOS
IOS_DOWNLOAD_EXIT_CODE=$?
set -e

if [ "${IOS_DOWNLOAD_EXIT_CODE}" -eq 0 ]; then
  echo "::notice::iOS device platform downloaded successfully"
else
  echo "::warning::iOS device platform download returned exit code ${IOS_DOWNLOAD_EXIT_CODE} (platform may already be installed)"
fi

echo "::notice::Downloading iOS simulator platform"
set +e
xcodebuild -downloadPlatform "iOS Simulator"
SIMULATOR_DOWNLOAD_EXIT_CODE=$?
set -e

if [ "${SIMULATOR_DOWNLOAD_EXIT_CODE}" -eq 0 ]; then
  echo "::notice::iOS simulator platform downloaded successfully"
else
  echo "::warning::iOS simulator platform download returned exit code ${SIMULATOR_DOWNLOAD_EXIT_CODE} (platform may already be installed)"
fi

echo "::notice::Verifying installed platforms"
if xcodebuild -showsdks 2>&1 | grep -q "iOS"; then
  echo "::notice::✓ iOS SDKs are available:"
  xcodebuild -showsdks 2>&1 | grep "iOS" | while IFS= read -r line; do
    echo "::notice::  ${line}"
  done
else
  echo "::warning::No iOS SDKs found in xcodebuild output"
fi

echo "::notice::✓ iOS platform installation completed"
