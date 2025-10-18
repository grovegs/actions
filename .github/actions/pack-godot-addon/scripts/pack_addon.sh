#!/usr/bin/env bash
set -euo pipefail

if [ -z "${ADDON_PATH:-}" ]; then
  echo "::error::ADDON_PATH environment variable is required"
  exit 1
fi

if [ -z "${ADDON_VERSION:-}" ]; then
  echo "::error::ADDON_VERSION environment variable is required"
  exit 1
fi

if [ -z "${ADDON_FILENAME:-}" ]; then
  echo "::error::ADDON_FILENAME environment variable is required"
  exit 1
fi

if ! command -v zip > /dev/null 2>&1; then
  echo "::error::zip is not installed or not in PATH"
  exit 1
fi

echo "::notice::Processing addon '${ADDON_PATH}' with version '${ADDON_VERSION}'"

if [ ! -d "${ADDON_PATH}" ]; then
  echo "::error::Addon directory '${ADDON_PATH}' does not exist"
  exit 1
fi

PLUGIN_CFG_PATH="${ADDON_PATH}/plugin.cfg"

if [ ! -f "${PLUGIN_CFG_PATH}" ]; then
  echo "::error::plugin.cfg file not found in '${ADDON_PATH}'"
  exit 1
fi

echo "::notice::Updating version in ${PLUGIN_CFG_PATH}"
sed -i.bak "s/version=\"[^\"]*\"/version=\"${ADDON_VERSION}\"/" "${PLUGIN_CFG_PATH}"
rm -f "${PLUGIN_CFG_PATH}.bak"
echo "  ✓ Updated version to ${ADDON_VERSION}"

ADDONS_DIR="${HOME}/.godot/addons"
TEMP_DIR="${ADDONS_DIR}/${ADDON_FILENAME}"

if ! mkdir -p "${TEMP_DIR}"; then
  echo "::error::Failed to create addons directory '${TEMP_DIR}'"
  exit 1
fi

echo "::notice::Copying addon files to temporary directory"
if ! cp -r "${ADDON_PATH}" "${TEMP_DIR}"; then
  echo "::error::Failed to copy addon '${ADDON_PATH}' to '${TEMP_DIR}'"
  exit 1
fi

ADDON_DIR="${TEMP_DIR}/$(basename "${ADDON_PATH}")"

if [ -f "README.md" ]; then
  echo "::notice::Including README.md"
  if ! cp README.md "${ADDON_DIR}"; then
    echo "::warning::Failed to copy README.md to '${ADDON_DIR}'"
  fi
fi

if [ -f "LICENSE" ]; then
  echo "::notice::Including LICENSE"
  if ! cp LICENSE "${ADDON_DIR}"; then
    echo "::warning::Failed to copy LICENSE to '${ADDON_DIR}'"
  fi
fi

cd "${ADDONS_DIR}" || {
  echo "::error::Failed to change directory to '${ADDONS_DIR}'"
  exit 1
}

ZIP_NAME="${ADDON_FILENAME}.zip"
PACKAGE_FILE="${ADDONS_DIR}/${ZIP_NAME}"

echo "::notice::Creating zip archive"
echo "  Output: ${PACKAGE_FILE}"

if ! zip --recurse-paths --quiet "${ZIP_NAME}" "${ADDON_FILENAME}"; then
  echo "::error::Failed to create zip archive '${ZIP_NAME}'"
  exit 1
fi

rm -rf "${TEMP_DIR}"

echo "::notice::✓ Successfully created addon package: ${PACKAGE_FILE}"

{
  echo "package=${PACKAGE_FILE}"
  echo "modified-files=${PLUGIN_CFG_PATH}"
} >> "${GITHUB_OUTPUT}"
