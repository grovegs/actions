#!/bin/bash

if [[ -z "${PACKAGE_PATH}" ]] || [[ -z "${PACKAGE_VERSION}" ]] || [[ -z "${PACKAGE_FILENAME}" ]]; then
  echo "::error::Missing required environment variables: PACKAGE_PATH, PACKAGE_VERSION, PACKAGE_FILENAME"
  exit 1
fi

echo "::notice::Processing package '${PACKAGE_PATH}' with version '${PACKAGE_VERSION}'"

if [[ ! -d "${PACKAGE_PATH}" ]]; then
  echo "::error::Package directory '${PACKAGE_PATH}' does not exist."
  exit 1
fi

if [[ ! -f "${PACKAGE_PATH}/package.json" ]]; then
  echo "::error::package.json file not found in '${PACKAGE_PATH}'."
  exit 1
fi

sed -i.bak 's/"version"[[:space:]]*:[[:space:]]*"[^"]*"/"version": "'"${PACKAGE_VERSION}"'"/' "${PACKAGE_PATH}/package.json" && rm -f "${PACKAGE_PATH}/package.json.bak"

packages_dir=~/.unity/packages
temp="${packages_dir}/${PACKAGE_FILENAME}"
trap '[[ -d "${temp}" ]] && rm -rf "${temp}"' EXIT

if ! mkdir -p "${temp}"; then
  echo "::error::Failed to create packages directory '${temp}'."
  exit 1
fi

if ! cp -r "${PACKAGE_PATH}" "${temp}"; then
  echo "::error::Failed to copy package '${PACKAGE_PATH}' to '${temp}'."
  exit 1
fi

package_dir="${temp}/$(basename "${PACKAGE_PATH}")"

if [[ -f "README.md" ]] && ! cp "README.md" "${package_dir}"; then
  echo "::warning::Failed to copy README.md to '${package_dir}'."
fi

if [[ -f "LICENSE" ]] && ! cp "LICENSE" "${package_dir}"; then
  echo "::warning::Failed to copy LICENSE to '${package_dir}'."
fi

cd "${packages_dir}" || exit 1
tgz_name="${PACKAGE_FILENAME}.tgz"
file="${packages_dir}/${tgz_name}"

if ! tar --create --gzip --file "${tgz_name}" "${PACKAGE_FILENAME}"; then
  echo "::error::Failed to create tarball archive '${tgz_name}'."
  exit 1
fi

echo "::notice::Successfully created package tarball: ${tgz_name}"
echo "file=${file}" >> "${GITHUB_OUTPUT}"
