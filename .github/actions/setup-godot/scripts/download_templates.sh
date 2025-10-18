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

if ! command -v curl > /dev/null 2>&1; then
  echo "::error::curl is not installed or not in PATH"
  exit 1
fi

if ! command -v unzip > /dev/null 2>&1; then
  echo "::error::unzip is not installed or not in PATH"
  exit 1
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

SOURCE_NAME="godot"

if [[ "${GODOT_STAGE}" != "stable" ]]; then
  SOURCE_NAME+="-builds"
fi

FILE_NAME="${GODOT_VERSION}.${GODOT_STAGE}.mono"
URL="https://github.com/godotengine/${SOURCE_NAME}/releases/download/${GODOT_VERSION}-${GODOT_STAGE}/Godot_v${GODOT_VERSION}-${GODOT_STAGE}_mono_export_templates.tpz"
DOWNLOADED_FILE="${TEMPLATES_DIR}/${FILE_NAME}.tpz"

echo "::notice::Downloading templates from ${URL}"
if ! curl -L -o "${DOWNLOADED_FILE}" "${URL}"; then
  echo "::error::Download failed for ${URL}"
  exit 1
fi

if [ ! -f "${DOWNLOADED_FILE}" ]; then
  echo "::error::Downloaded file not found: ${DOWNLOADED_FILE}"
  exit 1
fi

echo "::notice::Extracting templates with patterns: ${PLATFORM_PATTERNS}"
if ! unzip -o "${DOWNLOADED_FILE}" "templates/version.txt" "${PLATFORM_PATTERNS}" -d "${TEMPLATES_DIR}"; then
  echo "::error::Extraction failed for ${DOWNLOADED_FILE}"
  exit 1
fi

rm "${DOWNLOADED_FILE}"
mv "${TEMPLATES_DIR}/templates" "${TEMPLATES_DIR}/${FILE_NAME}"

echo "::notice::✓ Export templates downloaded successfully"
