#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PACKAGE_PATH:-}" ]; then
  echo "::error::PACKAGE_PATH environment variable is required"
  exit 1
fi

if [ -z "${PACKAGE_VERSION:-}" ]; then
  echo "::error::PACKAGE_VERSION environment variable is required"
  exit 1
fi

if [ -z "${PACKAGE_FILENAME:-}" ]; then
  echo "::error::PACKAGE_FILENAME environment variable is required"
  exit 1
fi

if ! command -v tar > /dev/null 2>&1; then
  echo "::error::tar is not installed or not in PATH"
  exit 1
fi

echo "::notice::Processing package '${PACKAGE_PATH}' with version '${PACKAGE_VERSION}'"

if [ ! -d "${PACKAGE_PATH}" ]; then
  echo "::error::Package directory '${PACKAGE_PATH}' does not exist"
  exit 1
fi

PACKAGE_JSON_PATH="${PACKAGE_PATH}/package.json"

if [ ! -f "${PACKAGE_JSON_PATH}" ]; then
  echo "::error::package.json file not found in '${PACKAGE_PATH}'"
  exit 1
fi

echo "::notice::Updating version in ${PACKAGE_JSON_PATH}"
sed -i.bak "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${PACKAGE_VERSION}\"/" "${PACKAGE_JSON_PATH}"
rm -f "${PACKAGE_JSON_PATH}.bak"
echo "  ✓ Updated version to ${PACKAGE_VERSION}"

PACKAGES_DIR="${HOME}/.unity/packages"
TEMP_DIR="${PACKAGES_DIR}/${PACKAGE_FILENAME}"

if ! mkdir -p "${TEMP_DIR}"; then
  echo "::error::Failed to create packages directory '${TEMP_DIR}'"
  exit 1
fi

echo "::notice::Copying package files to temporary directory"
if ! cp -r "${PACKAGE_PATH}" "${TEMP_DIR}"; then
  echo "::error::Failed to copy package '${PACKAGE_PATH}' to '${TEMP_DIR}'"
  exit 1
fi

PACKAGE_DIR="${TEMP_DIR}/$(basename "${PACKAGE_PATH}")"

if [ -f "README.md" ]; then
  echo "::notice::Including README.md"
  rm -f "${PACKAGE_DIR}/README.md"
  if ! cp "README.md" "${PACKAGE_DIR}"; then
    echo "::warning::Failed to copy README.md to '${PACKAGE_DIR}'"
  fi
fi

if [ -f "LICENSE" ]; then
  echo "::notice::Including LICENSE"
  rm -f "${PACKAGE_DIR}/LICENSE"
  if ! cp "LICENSE" "${PACKAGE_DIR}"; then
    echo "::warning::Failed to copy LICENSE to '${PACKAGE_DIR}'"
  fi
fi

cd "${PACKAGES_DIR}" || {
  echo "::error::Failed to change directory to '${PACKAGES_DIR}'"
  exit 1
}

TGZ_NAME="${PACKAGE_FILENAME}.tgz"
PACKAGE_FILE="${PACKAGES_DIR}/${TGZ_NAME}"

echo "::notice::Creating tarball archive"
echo "  Output: ${PACKAGE_FILE}"

if ! tar --create --gzip --file "${TGZ_NAME}" "${PACKAGE_FILENAME}"; then
  echo "::error::Failed to create tarball archive '${TGZ_NAME}'"
  exit 1
fi

rm -rf "${TEMP_DIR}"

echo "::notice::✓ Successfully created package tarball: ${PACKAGE_FILE}"

{
  echo "package=${PACKAGE_FILE}"
  echo "modified-files=${PACKAGE_JSON_PATH}"
} >> "${GITHUB_OUTPUT}"
