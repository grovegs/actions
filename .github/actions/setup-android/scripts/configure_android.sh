#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "::error::Usage: $0 <android_packages>"
  exit 1
fi

android_packages="$1"

echo "::notice::Configuring Android environment variables and PATH"

if [[ "$RUNNER_OS" == "macOS" ]]; then
  android_home="$HOME/Library/Android/sdk"
elif [[ "$RUNNER_OS" == "Linux" ]]; then
  android_home="$HOME/Android/Sdk"
else
  echo "::error::Unsupported OS: $RUNNER_OS"
  exit 1
fi

{
  echo "ANDROID_HOME=$android_home"
  echo "ANDROID_SDK_ROOT=$android_home"
} >> "$GITHUB_ENV"

{
  echo "$android_home/platform-tools"
  echo "$android_home/cmdline-tools/latest/bin"
  echo "$android_home/tools/bin"
} >> "$GITHUB_PATH"

if echo "$android_packages" | grep -q "ndk;"; then
  ndk_version=$(echo "$android_packages" | grep -o "ndk;[^[:space:]]*" | cut -d';' -f2)
  ndk_home="$android_home/ndk/$ndk_version"
  if [ -d "$ndk_home" ]; then
    {
      echo "ANDROID_NDK_HOME=$ndk_home"
      echo "ANDROID_NDK_ROOT=$ndk_home"
      echo "NDK_HOME=$ndk_home"
    } >> "$GITHUB_ENV"
    echo "$ndk_home" >> "$GITHUB_PATH"
    echo "::notice::NDK environment configured for version $ndk_version"
  fi
fi

if echo "$android_packages" | grep -q "cmake;"; then
  cmake_version=$(echo "$android_packages" | grep -o "cmake;[^[:space:]]*" | cut -d';' -f2)
  cmake_home="$android_home/cmake/$cmake_version"
  if [ -d "$cmake_home" ]; then
    echo "$cmake_home/bin" >> "$GITHUB_PATH"
    echo "::notice::CMake added to PATH: $cmake_home/bin"
  fi
fi

echo "::notice::Android environment configuration completed"
