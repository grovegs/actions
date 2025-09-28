#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "::error::Usage: $0 <addon> <version> <filename>"
  exit 1
fi

addon="$1"
version="$2"
filename="$3"

echo "::notice::Processing addon '${addon}' with version '${version}'"

if [[ ! -d "${addon}" ]]; then
  echo "::error::Addon directory '${addon}' does not exist."
  exit 1
fi

addons_dir=~/.godot/addons
temp=${addons_dir}/${filename}
trap '[[ -d "${temp}" ]] && rm -rf "${temp}"' EXIT

if ! mkdir -p "${temp}"; then
  echo "::error::Failed to create addons directory '${temp}'."
  exit 1
fi

if ! cp -r "${addon}" "${temp}"; then
  echo "::error::Failed to copy addon '${addon}' to '${temp}'."
  exit 1
fi

addon_dir="${temp}/$(basename "${addon}")"

if [[ -f "README.md" ]] && ! cp README.md "${addon_dir}"; then
  echo "::warning::Failed to copy README.md to '${addon_dir}'."
fi

if [[ -f "LICENSE" ]] && ! cp LICENSE "${addon_dir}"; then
  echo "::warning::Failed to copy LICENSE to '${addon_dir}'."
fi

if [[ ! -f "$addon_dir/plugin.cfg" ]]; then
  echo "::error::plugin.cfg file not found in '${addon_dir}'."
  exit 1
fi

sed -i.bak 's/version="[^"]*"/version="'${version}'"/' "$addon_dir/plugin.cfg" && rm -f "$addon_dir/plugin.cfg.bak"

cd "${addons_dir}" || exit 1
zip_name="${filename}.zip"
file="${addons_dir}/${zip_name}"

if ! zip --recurse-paths --quiet "${zip_name}" "${filename}"; then
  echo "::error::Failed to create zip archive '${zip_name}'."
  exit 1
fi

echo "::notice::Successfully created addon package: ${zip_name}"
echo file="$file" >> "$GITHUB_OUTPUT"
