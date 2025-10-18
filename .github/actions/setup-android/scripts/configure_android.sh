#!/usr/bin/env bash
set -euo pipefail

if [ -z "${ANDROID_PACKAGES:-}" ]; then
  echo "::error::ANDROID_PACKAGES environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

echo "::notice::Configuring Android environment variables and PATH"

if [[ "${RUNNER_OS}" == "macOS" ]]; then
  ANDROID_HOME="${HOME}/Library/Android/sdk"
elif [[ "${RUNNER_OS}" == "Linux" ]]; then
  ANDROID_HOME="${HOME}/Android/Sdk"
else
  echo "::error::Unsupported OS: ${RUNNER_OS}"
  exit 1
fi

if [ ! -d "${ANDROID_HOME}" ]; then
  echo "::warning::Android SDK directory not found: ${ANDROID_HOME}"
fi

{
  echo "ANDROID_HOME=${ANDROID_HOME}"
  echo "ANDROID_SDK_ROOT=${ANDROID_HOME}"
} >> "${GITHUB_ENV}"

{
  echo "${ANDROID_HOME}/platform-tools"
  echo "${ANDROID_HOME}/cmdline-tools/latest/bin"
  echo "${ANDROID_HOME}/tools/bin"
} >> "${GITHUB_PATH}"

echo "::notice::Added Android SDK directories to PATH"

if echo "${ANDROID_PACKAGES}" | grep -q "ndk;"; then
  NDK_VERSION=$(echo "${ANDROID_PACKAGES}" | grep -o "ndk;[^[:space:]]*" | cut -d';' -f2)
  NDK_HOME="${ANDROID_HOME}/ndk/${NDK_VERSION}"

  if [ -d "${NDK_HOME}" ]; then
    {
      echo "ANDROID_NDK_HOME=${NDK_HOME}"
      echo "ANDROID_NDK_ROOT=${NDK_HOME}"
      echo "NDK_HOME=${NDK_HOME}"
    } >> "${GITHUB_ENV}"

    echo "${NDK_HOME}" >> "${GITHUB_PATH}"
    echo "::notice::NDK environment configured for version ${NDK_VERSION}"
  else
    echo "::warning::NDK directory not found: ${NDK_HOME}"
  fi
fi

if echo "${ANDROID_PACKAGES}" | grep -q "cmake;"; then
  CMAKE_VERSION=$(echo "${ANDROID_PACKAGES}" | grep -o "cmake;[^[:space:]]*" | cut -d';' -f2)
  CMAKE_HOME="${ANDROID_HOME}/cmake/${CMAKE_VERSION}"

  if [ -d "${CMAKE_HOME}" ]; then
    echo "${CMAKE_HOME}/bin" >> "${GITHUB_PATH}"
    echo "::notice::CMake added to PATH: ${CMAKE_HOME}/bin"
  else
    echo "::warning::CMake directory not found: ${CMAKE_HOME}"
  fi
fi

echo "::notice::✓ Android environment configuration completed"
