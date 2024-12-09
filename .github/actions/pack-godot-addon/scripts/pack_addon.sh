#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <addon> <version> <filename>"
    exit 1
fi

addon="$1"
version="$2"
filename="$3"

if [[ ! -d "${addon}" ]]; then
    echo "Error: Addon directory '${addon}' does not exist."
    exit 1
fi

addons_dir=~/.godot/addons
temp=${addons_dir}/${filename}
trap '[[ -d "${temp}" ]] && rm -rf "${temp}"' EXIT

if ! mkdir -p "${temp}"; then
    echo "Error: Failed to create addons directory '${temp}'."
    exit 1
fi

if ! cp -r "${addon}" "${temp}"; then
    echo "Error: Failed to copy addon '${addon}' to '${temp}'."
    exit 1
fi

addon_dir="${temp}/$(basename "${addon}")"

if [[ -f "README.md" ]] && ! cp README.md "${addon_dir}"; then
    echo "Error: Failed to copy README.md to '${addon_dir}'."
    exit 1
fi

if [[ -f "LICENSE" ]] && ! cp LICENSE "${addon_dir}"; then
    echo "Error: Failed to copy LICENSE to '${addon_dir}'."
    exit 1
fi

if ! sed -i '' 's/version="[^"]*"/version="'${version}'"/' "$addon_dir/plugin.cfg"; then
    echo "Error: Failed to update version in 'plugin.cfg'."
    exit 1
fi

cd "${addons_dir}" || exit 1
zip_name="${filename}.zip"
file="${addons_dir}/${zip_name}"

if ! zip --recurse-paths --quiet "${zip_name}" "${filename}"; then
    echo "Error: Failed to create zip archive '${zip_name}'."
    exit 1
fi

echo "${file}"
