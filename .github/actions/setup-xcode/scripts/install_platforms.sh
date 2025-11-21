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

check_platform_installed() {
  local platform_name="$1"

  if xcodebuild -showsdks 2>&1 | grep -q "${platform_name}"; then
    return 0
  else
    return 1
  fi
}

echo "::notice::Checking installed platforms"

IOS_DEVICE_INSTALLED=false
IOS_SIMULATOR_INSTALLED=false

if check_platform_installed "iphoneos"; then
  echo "::notice::iOS device platform already installed"
  IOS_DEVICE_INSTALLED=true
fi

if check_platform_installed "iphonesimulator"; then
  echo "::notice::iOS simulator platform already installed"
  IOS_SIMULATOR_INSTALLED=true
fi

if [ "${IOS_DEVICE_INSTALLED}" = true ] && [ "${IOS_SIMULATOR_INSTALLED}" = true ]; then
  echo "::notice::All iOS platforms already installed, skipping downloads"
  echo "::notice::✅ iOS platform installation completed"
  exit 0
fi

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

if [ "${IOS_DEVICE_INSTALLED}" = false ]; then
  echo "::notice::Downloading iOS device platform"
  set +e
  xcodebuild -downloadPlatform iOS
  IOS_DOWNLOAD_EXIT_CODE=$?
  set -e

  if [ "${IOS_DOWNLOAD_EXIT_CODE}" -eq 0 ]; then
    if check_platform_installed "iphoneos"; then
      echo "::notice::iOS device platform downloaded and installed successfully"
      IOS_DEVICE_INSTALLED=true
    else
      echo "::warning::iOS device platform download succeeded but platform not detected"
    fi
  else
    echo "::warning::iOS device platform download returned exit code ${IOS_DOWNLOAD_EXIT_CODE}"

    if check_platform_installed "iphoneos"; then
      echo "::notice::iOS device platform is available despite download error"
      IOS_DEVICE_INSTALLED=true
    fi
  fi
fi

if [ "${IOS_SIMULATOR_INSTALLED}" = false ]; then
  echo "::notice::Downloading iOS simulator platform"
  set +e
  xcodebuild -downloadPlatform "iOS Simulator"
  SIMULATOR_DOWNLOAD_EXIT_CODE=$?
  set -e

  if [ "${SIMULATOR_DOWNLOAD_EXIT_CODE}" -eq 0 ]; then
    if check_platform_installed "iphonesimulator"; then
      echo "::notice::iOS simulator platform downloaded and installed successfully"
      IOS_SIMULATOR_INSTALLED=true
    else
      echo "::warning::iOS simulator platform download succeeded but platform not detected"
    fi
  else
    echo "::warning::iOS simulator platform download returned exit code ${SIMULATOR_DOWNLOAD_EXIT_CODE}"

    if check_platform_installed "iphonesimulator"; then
      echo "::notice::iOS simulator platform is available despite download error"
      IOS_SIMULATOR_INSTALLED=true
    fi
  fi
fi

echo "::notice::Verifying installed platforms"
if xcodebuild -showsdks 2>&1 | grep -q "iOS"; then
  echo "::notice::✅ Available iOS SDKs:"
  xcodebuild -showsdks 2>&1 | grep "iOS" | while IFS= read -r line; do
    echo "::notice::  ${line}"
  done
else
  echo "::error::No iOS SDKs found after installation"
  exit 1
fi

if [ "${IOS_DEVICE_INSTALLED}" = false ]; then
  echo "::error::iOS device platform installation failed"
  exit 1
fi

if [ "${IOS_SIMULATOR_INSTALLED}" = false ]; then
  echo "::error::iOS simulator platform installation failed"
  exit 1
fi

echo "::notice::✅ iOS platform installation completed"
