#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "::error::Usage: $0 <package> <version> <filename>"
  exit 1
fi

package="$1"
version="$2"
filename="$3"

echo "::notice::Processing package '${package}' with version '${version}'"

if [[ ! -d "${package}" ]]; then
  echo "::error::Package directory '${package}' does not exist."
  exit 1
fi

packages_dir=~/.unity/packages
temp="${packages_dir}/${filename}"
trap '[[ -d "${temp}" ]] && rm -rf "${temp}"' EXIT

if ! mkdir -p "${temp}"; then
  echo "::error::Failed to create packages directory '${temp}'."
  exit 1
fi

if ! cp -r "${package}" "${temp}"; then
  echo "::error::Failed to copy package '${package}' to '${temp}'."
  exit 1
fi

package_dir="${temp}/$(basename "${package}")"

if [[ -f "README.md" ]] && ! cp "README.md" "${package_dir}"; then
  echo "::warning::Failed to copy README.md to '${package_dir}'."
fi

if [[ -f "LICENSE" ]] && ! cp "LICENSE" "${package_dir}"; then
  echo "::warning::Failed to copy LICENSE to '${package_dir}'."
fi

if [[ ! -f "${package_dir}/package.json" ]]; then
  echo "::error::package.json file not found in '${package_dir}'."
  exit 1
fi

sed -i.bak 's/"version"[[:space:]]*:[[:space:]]*"[^"]*"/"version": "'"${version}"'"/' "${package_dir}/package.json" && rm -f "${package_dir}/package.json.bak"

cd "${packages_dir}" || exit 1
tgz_name="${filename}.tgz"
file="${packages_dir}/${tgz_name}"

if ! tar --create --gzip --file "${tgz_name}" "${filename}"; then
  echo "::error::Failed to create tarball archive '${tgz_name}'."
  exit 1
fi

echo "::notice::Successfully created package tarball: ${tgz_name}"
echo "file=${file}" >> "${GITHUB_OUTPUT}"
