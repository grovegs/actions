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

if [ -z "${TEMPLATES_DIR:-}" ]; then
  echo "::error::TEMPLATES_DIR environment variable is required"
  exit 1
fi

if [ -z "${TARGET_PLATFORMS:-}" ]; then
  echo "::error::TARGET_PLATFORMS environment variable is required"
  exit 1
fi

if [ -z "${DOWNLOAD_DIR:-}" ]; then
  echo "::error::DOWNLOAD_DIR environment variable is required"
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

FILE_NAME="${GODOT_VERSION}.${GODOT_STAGE}.mono"
TEMPLATES_VERSION_DIR="${TEMPLATES_DIR}/${FILE_NAME}"

if [ -d "${TEMPLATES_VERSION_DIR}" ] && [ -f "${TEMPLATES_VERSION_DIR}/version.txt" ]; then
  echo "::notice::Export templates for ${GODOT_VERSION}-${GODOT_STAGE} already exist at ${TEMPLATES_VERSION_DIR}"
  echo "::notice::Skipping download"
  exit 0
fi

echo "::notice::Processing platforms: ${TARGET_PLATFORMS}"

PLATFORM_PATTERNS=$(echo "${TARGET_PLATFORMS}" \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*\(.*\)[[:space:]]*$/\1/' \
  | awk '{print "templates/" tolower($0) "*"}' \
  | paste -sd ' ' -)

if ! mkdir -p "${TEMPLATES_DIR}"; then
  echo "::error::Failed to create directory at ${TEMPLATES_DIR}"
  exit 1
fi

if ! mkdir -p "${DOWNLOAD_DIR}"; then
  echo "::error::Failed to create directory at ${DOWNLOAD_DIR}"
  exit 1
fi

SOURCE_NAME="godot"

if [[ "${GODOT_STAGE}" != "stable" ]]; then
  SOURCE_NAME+="-builds"
fi

URL="https://github.com/godotengine/${SOURCE_NAME}/releases/download/${GODOT_VERSION}-${GODOT_STAGE}/Godot_v${GODOT_VERSION}-${GODOT_STAGE}_mono_export_templates.tpz"
DOWNLOADED_FILE="${DOWNLOAD_DIR}/${FILE_NAME}.tpz"

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
  echo "::notice::Downloading templates from ${URL}"
  if ! curl -L -o "${DOWNLOADED_FILE}" "${URL}"; then
    echo "::error::Download failed for ${URL}"
    exit 1
  fi
fi

if [ ! -f "${DOWNLOADED_FILE}" ]; then
  echo "::error::Downloaded file not found: ${DOWNLOADED_FILE}"
  exit 1
fi

echo "::notice::Extracting templates with patterns: ${PLATFORM_PATTERNS}"
if ! unzip -o "${DOWNLOADED_FILE}" "templates/version.txt" ${PLATFORM_PATTERNS} -d "${TEMPLATES_DIR}"; then
  echo "::error::Extraction failed for ${DOWNLOADED_FILE}"
  exit 1
fi

mv "${TEMPLATES_DIR}/templates" "${TEMPLATES_VERSION_DIR}"

echo "::notice::✅ Export templates downloaded successfully"
