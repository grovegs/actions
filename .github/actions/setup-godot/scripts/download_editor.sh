#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GODOT_VERSION:-}" ]; then
  echo "::error::GODOT_VERSION environment variable is required"
  exit 1
fi

if [ -z "${GODOT_STAGE:-}" ]; then
  echo "::error::GODOT_STAGE environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

if ! command -v curl > /dev/null 2>&1; then
  echo "::error::curl is not installed or not in PATH"
  exit 1
fi

if ! command -v unzip > /dev/null 2>&1; then
  echo "::error::unzip is not installed or not in PATH"
  exit 1
fi

EDITOR_DIR="${HOME}/.godot"

echo "::notice::Creating Godot directory at ${EDITOR_DIR}"
if ! mkdir -p "${EDITOR_DIR}"; then
  echo "::error::Failed to create directory at ${EDITOR_DIR}"
  exit 1
fi

case "${RUNNER_OS}" in
  "Linux")
    PLATFORM="linux_x86_64"
    ;;
  "macOS")
    PLATFORM="macos.universal"
    ;;
  *)
    echo "::error::Unsupported platform: ${RUNNER_OS}"
    exit 1
    ;;
esac

SOURCE_NAME="godot"

if [[ "${GODOT_STAGE}" != "stable" ]]; then
  SOURCE_NAME+="-builds"
fi

FILE_NAME="Godot_v${GODOT_VERSION}-${GODOT_STAGE}_mono_${PLATFORM}"
URL="https://github.com/godotengine/${SOURCE_NAME}/releases/download/${GODOT_VERSION}-${GODOT_STAGE}/${FILE_NAME}.zip"
DOWNLOADED_FILE="${EDITOR_DIR}/${FILE_NAME}.zip"

echo "::notice::Downloading Godot from ${URL}"
if ! curl -L -o "${DOWNLOADED_FILE}" "${URL}"; then
  echo "::error::Download failed for ${URL}"
  exit 1
fi

if [ ! -f "${DOWNLOADED_FILE}" ]; then
  echo "::error::Downloaded file not found: ${DOWNLOADED_FILE}"
  exit 1
fi

echo "::notice::Extracting ${DOWNLOADED_FILE}"
if ! unzip -o "${DOWNLOADED_FILE}" -d "${EDITOR_DIR}"; then
  echo "::error::Extraction failed for ${DOWNLOADED_FILE}"
  exit 1
fi

rm "${DOWNLOADED_FILE}"

echo "::notice::Moving Godot to final location"
case "${RUNNER_OS}" in
  "Linux")
    mv "${EDITOR_DIR}/Godot_v${GODOT_VERSION}-${GODOT_STAGE}_mono_linux_x86_64" "${EDITOR_DIR}/Godot_v${GODOT_VERSION}"
    ;;
  "macOS")
    mv "${EDITOR_DIR}/Godot_mono.app" "${EDITOR_DIR}/Godot_v${GODOT_VERSION}.app"
    ;;
  *)
    echo "::error::Unsupported platform: ${RUNNER_OS}"
    exit 1
    ;;
esac

echo "::notice::✓ Godot editor downloaded successfully"
