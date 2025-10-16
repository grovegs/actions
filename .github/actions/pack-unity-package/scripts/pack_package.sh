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

echo "::notice::Processing package '${PACKAGE_PATH}' with version '${PACKAGE_VERSION}'"

if [ ! -d "${PACKAGE_PATH}" ]; then
  echo "::error::Package directory '${PACKAGE_PATH}' does not exist"
  exit 1
fi

if [ ! -f "${PACKAGE_PATH}/package.json" ]; then
  echo "::error::package.json file not found in '${PACKAGE_PATH}'"
  exit 1
fi

sed -i.bak "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${PACKAGE_VERSION}\"/" "${PACKAGE_PATH}/package.json"
rm -f "${PACKAGE_PATH}/package.json.bak"

PACKAGE_JSON_PATH="${PACKAGE_PATH}/package.json"

PACKAGES_DIR="${HOME}/.unity/packages"
TEMP_DIR="${PACKAGES_DIR}/${PACKAGE_FILENAME}"

if ! mkdir -p "${TEMP_DIR}"; then
  echo "::error::Failed to create packages directory '${TEMP_DIR}'"
  exit 1
fi

if ! cp -r "${PACKAGE_PATH}" "${TEMP_DIR}"; then
  echo "::error::Failed to copy package '${PACKAGE_PATH}' to '${TEMP_DIR}'"
  exit 1
fi

PACKAGE_DIR="${TEMP_DIR}/$(basename "${PACKAGE_PATH}")"

if [ -f "README.md" ]; then
  if ! cp "README.md" "${PACKAGE_DIR}"; then
    echo "::warning::Failed to copy README.md to '${PACKAGE_DIR}'"
  fi
fi

if [ -f "LICENSE" ]; then
  if ! cp "LICENSE" "${PACKAGE_DIR}"; then
    echo "::warning::Failed to copy LICENSE to '${PACKAGE_DIR}'"
  fi
fi

cd "${PACKAGES_DIR}" || exit 1

TGZ_NAME="${PACKAGE_FILENAME}.tgz"
PACKAGE_FILE="${PACKAGES_DIR}/${TGZ_NAME}"

if ! tar --create --gzip --file "${TGZ_NAME}" "${PACKAGE_FILENAME}"; then
  echo "::error::Failed to create tarball archive '${TGZ_NAME}'"
  exit 1
fi

rm -rf "${TEMP_DIR}"

echo "::notice::✓ Successfully created package tarball: ${PACKAGE_FILE}"

{
  echo "package=${PACKAGE_FILE}"
  echo "modified-files=${PACKAGE_JSON_PATH}"
} >> "$GITHUB_OUTPUT"
