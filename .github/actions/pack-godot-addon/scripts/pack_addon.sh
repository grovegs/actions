#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <addon> <version> <filename>"
    exit 1
fi

addon="$1"
version="$2"
filename="$3"

addons_dir=~/.godot/addons

if [[ ! -d "${addon}" ]]; then
    echo "Error: Addon directory '${addon}' does not exist."
    exit 1
fi

addon_name=$(basename "${addon}")
addon_path="${addons_dir}/${addon_name}"

if ! mkdir -p "${addon_path}"; then
    echo "Error: Failed to create addon directory '${addon_path}'."
    exit 1
fi

if ! cp -r "${addon}" "${addon_path}"; then
    echo "Error: Failed to copy addon '${addon}' to '${addon_path}'."
    exit 1
fi

addon_dir="${addon_path}/$(basename "${addon}")"

if [[ -f "README.md" ]] && ! cp README.md "${addon_dir}"; then
    echo "Error: Failed to copy README.md to '${addon_dir}'."
    exit 1
fi

if [[ -f "LICENSE" ]] && ! cp LICENSE "${addon_dir}"; then
    echo "Error: Failed to copy LICENSE to '${addon_dir}'."
    exit 1
fi

if ! sed -i "s/version=\"[^\"]*\"/version=\"${version}\"/" "${addon_dir}/plugin.cfg"; then
    echo "Error: Failed to update version in 'plugin.cfg'."
    exit 1
fi

cd "${addons_dir}" || exit 1
zip_file="${filename}.zip"
file="${addons_dir}/${zip_file}"

if ! zip --recurse-paths --quiet "${zip_file}" "${addon_name}"; then
    echo "Error: Failed to create zip archive '${zip_file}'."
    exit 1
fi

echo "${file}"
