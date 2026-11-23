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

MODIFIED_FILES="${PACKAGE_JSON_PATH}"

ensure_meta() {
  local asset_path="$1"
  local importer="$2"
  local meta_path="${asset_path}.meta"

  if [ -f "${meta_path}" ]; then
    return
  fi

  local guid
  guid=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')

  {
    echo "fileFormatVersion: 2"
    echo "guid: ${guid}"
    echo "${importer}:"
    echo "  externalObjects: {}"
    echo "  userData: "
    echo "  assetBundleName: "
    echo "  assetBundleVariant: "
  } > "${meta_path}"

  echo "  ✓ Created ${meta_path}"
  MODIFIED_FILES="${MODIFIED_FILES} ${meta_path}"
}

if [ -n "${PACKAGE_README:-}" ] && [ -f "${PACKAGE_README}" ]; then
  echo "::notice::Syncing README to ${PACKAGE_PATH}"
  TARGET_README="${PACKAGE_PATH}/README.md"
  cp "${PACKAGE_README}" "${TARGET_README}"
  MODIFIED_FILES="${MODIFIED_FILES} ${TARGET_README}"
  ensure_meta "${TARGET_README}" "TextScriptImporter"
fi

if [ -n "${PACKAGE_LICENSE:-}" ] && [ -f "${PACKAGE_LICENSE}" ]; then
  echo "::notice::Syncing LICENSE to ${PACKAGE_PATH}"
  TARGET_LICENSE="${PACKAGE_PATH}/LICENSE"
  cp "${PACKAGE_LICENSE}" "${TARGET_LICENSE}"
  MODIFIED_FILES="${MODIFIED_FILES} ${TARGET_LICENSE}"
  ensure_meta "${TARGET_LICENSE}" "DefaultImporter"
fi

if [ -n "${PACKAGE_SKILLS:-}" ]; then
  if [ ! -d "${PACKAGE_SKILLS}" ]; then
    echo "::error::Skills directory '${PACKAGE_SKILLS}' does not exist"
    exit 1
  fi

  echo "::notice::Syncing agent skills to ${PACKAGE_PATH}"

  for skill_dir in "${PACKAGE_SKILLS}"/*; do
    if [ ! -f "${skill_dir}/SKILL.md" ]; then
      continue
    fi

    TARGET_SKILL="${PACKAGE_PATH}/Skills~/$(basename "${skill_dir}")/SKILL.md"
    mkdir -p "$(dirname "${TARGET_SKILL}")"
    cp "${skill_dir}/SKILL.md" "${TARGET_SKILL}"

    if [ -f "${skill_dir}/unity.md" ]; then
      {
        echo ""
        cat "${skill_dir}/unity.md"
      } >> "${TARGET_SKILL}"
    fi

    echo "  ✓ Wrote ${TARGET_SKILL}"
    MODIFIED_FILES="${MODIFIED_FILES} ${TARGET_SKILL}"
  done
fi

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
  echo "modified-files=${MODIFIED_FILES}"
} >> "${GITHUB_OUTPUT}"
