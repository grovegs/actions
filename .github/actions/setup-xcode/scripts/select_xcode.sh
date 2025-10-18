#!/usr/bin/env bash
set -euo pipefail

if [ -z "${XCODE_VERSION:-}" ]; then
  echo "::error::XCODE_VERSION environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

if [ "${RUNNER_OS}" != "macOS" ]; then
  echo "::error::This action only supports macOS. Current OS: ${RUNNER_OS}"
  exit 1
fi

if ! command -v xcode-select > /dev/null 2>&1; then
  echo "::error::xcode-select is not installed or not in PATH"
  exit 1
fi

echo "::notice::Selecting Xcode ${XCODE_VERSION}"

XCODE_PATH="/Applications/Xcode_${XCODE_VERSION}.app"

if [ ! -d "${XCODE_PATH}" ]; then
  echo "::error::Xcode ${XCODE_VERSION} not found at ${XCODE_PATH}"
  echo "::error::Available Xcode installations:"

  shopt -s nullglob
  XCODE_APPS=(/Applications/Xcode*.app)
  shopt -u nullglob

  if [ ${#XCODE_APPS[@]} -eq 0 ]; then
    echo "::error::  No Xcode installations found in /Applications"
  else
    for xcode_app in "${XCODE_APPS[@]}"; do
      echo "::error::  - $(basename "${xcode_app}")"
    done
  fi

  exit 1
fi

NEW_DEV_PATH="${XCODE_PATH}/Contents/Developer"

if [ ! -d "${NEW_DEV_PATH}" ]; then
  echo "::error::Developer directory not found: ${NEW_DEV_PATH}"
  exit 1
fi

echo "::notice::Switching to Xcode at ${XCODE_PATH}"

if ! sudo xcode-select -s "${NEW_DEV_PATH}"; then
  echo "::error::Failed to switch Xcode with xcode-select"
  exit 1
fi

CURRENT_DEV_PATH=$(xcode-select -p)
echo "::notice::Current developer directory: ${CURRENT_DEV_PATH}"

if [ "${CURRENT_DEV_PATH}" != "${NEW_DEV_PATH}" ]; then
  echo "::warning::Developer directory mismatch. Expected: ${NEW_DEV_PATH}, Got: ${CURRENT_DEV_PATH}"
fi

echo "::notice::Setting environment variables"
{
  echo "DEVELOPER_DIR=${NEW_DEV_PATH}"
  echo "XCODE_ROOT=${XCODE_PATH}"
} >> "${GITHUB_ENV}"

if command -v xcodebuild > /dev/null 2>&1; then
  XCODE_BUILD_VERSION=$(xcodebuild -version 2>&1 | head -2 || echo "Unknown")
  echo "::notice::Xcode version information:"
  echo "${XCODE_BUILD_VERSION}" | while IFS= read -r line; do
    echo "::notice::  ${line}"
  done
else
  echo "::warning::xcodebuild command not found"
fi

echo "::notice::✓ Xcode selection completed successfully"
