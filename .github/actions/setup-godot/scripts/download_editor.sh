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

if [ -z "${DOWNLOAD_DIR:-}" ]; then
  echo "::error::DOWNLOAD_DIR environment variable is required"
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

GODOT_PATH_INPUT="${GODOT_PATH:-}"

if [ -n "${GODOT_PATH_INPUT}" ]; then
  EDITOR_DIR="${GODOT_PATH_INPUT}"
else
  EDITOR_DIR="${HOME}/.godot"
fi

case "${RUNNER_OS}" in
  "Linux")
    GODOT_EXECUTABLE="${EDITOR_DIR}/Godot_v${GODOT_VERSION}/Godot_v${GODOT_VERSION}-${GODOT_STAGE}_mono_linux.x86_64"
    ;;
  "macOS")
    GODOT_EXECUTABLE="${EDITOR_DIR}/Godot_v${GODOT_VERSION}.app/Contents/MacOS/Godot"
    ;;
  *)
    echo "::error::Unsupported platform: ${RUNNER_OS}"
    exit 1
    ;;
esac

if [ -f "${GODOT_EXECUTABLE}" ] && [ -x "${GODOT_EXECUTABLE}" ]; then
  echo "::notice::Godot ${GODOT_VERSION}-${GODOT_STAGE} is already installed at ${EDITOR_DIR}"
  echo "::notice::Skipping download"
  exit 0
fi

echo "::notice::Creating download directory at ${DOWNLOAD_DIR}"
if ! mkdir -p "${DOWNLOAD_DIR}"; then
  echo "::error::Failed to create directory at ${DOWNLOAD_DIR}"
  exit 1
fi

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
DOWNLOADED_FILE="${DOWNLOAD_DIR}/${FILE_NAME}.zip"

if [ -f "${DOWNLOADED_FILE}" ]; then
  local file_size
  file_size=$(stat -f%z "${DOWNLOADED_FILE}" 2> /dev/null || stat -c%s "${DOWNLOADED_FILE}" 2> /dev/null || echo "0")

  if [ "${file_size}" -lt 1048576 ]; then
    echo "::warning::Existing file appears corrupted (${file_size} bytes), re-downloading"
    rm -f "${DOWNLOADED_FILE}"
  else
    echo "::notice::Using existing download (${file_size} bytes)"
  fi
fi

if [ ! -f "${DOWNLOADED_FILE}" ]; then
  echo "::notice::Downloading Godot from ${URL}"
  if ! curl -L -o "${DOWNLOADED_FILE}" "${URL}"; then
    echo "::error::Download failed for ${URL}"
    exit 1
  fi
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

echo "::notice::✅ Godot editor downloaded successfully"
