#!/bin/bash

if [[ -z "${ADDON_PATH}" ]] || [[ -z "${ADDON_VERSION}" ]] || [[ -z "${ADDON_FILENAME}" ]]; then
  echo "::error::Missing required environment variables: ADDON_PATH, ADDON_VERSION, ADDON_FILENAME"
  exit 1
fi

echo "::notice::Processing addon '${ADDON_PATH}' with version '${ADDON_VERSION}'"

if [[ ! -d "${ADDON_PATH}" ]]; then
  echo "::error::Addon directory '${ADDON_PATH}' does not exist."
  exit 1
fi

if [[ ! -f "${ADDON_PATH}/plugin.cfg" ]]; then
  echo "::error::plugin.cfg file not found in '${ADDON_PATH}'."
  exit 1
fi

sed -i.bak 's/version="[^"]*"/version="'"${ADDON_VERSION}"'"/' "${ADDON_PATH}/plugin.cfg" && rm -f "${ADDON_PATH}/plugin.cfg.bak"

addons_dir=~/.godot/addons
temp=${addons_dir}/${ADDON_FILENAME}
trap '[[ -d "${temp}" ]] && rm -rf "${temp}"' EXIT

if ! mkdir -p "${temp}"; then
  echo "::error::Failed to create addons directory '${temp}'."
  exit 1
fi

if ! cp -r "${ADDON_PATH}" "${temp}"; then
  echo "::error::Failed to copy addon '${ADDON_PATH}' to '${temp}'."
  exit 1
fi

addon_dir="${temp}/$(basename "${ADDON_PATH}")"

if [[ -f "README.md" ]] && ! cp README.md "${addon_dir}"; then
  echo "::warning::Failed to copy README.md to '${addon_dir}'."
fi

if [[ -f "LICENSE" ]] && ! cp LICENSE "${addon_dir}"; then
  echo "::warning::Failed to copy LICENSE to '${addon_dir}'."
fi

cd "${addons_dir}" || exit 1
zip_name="${ADDON_FILENAME}.zip"
file="${addons_dir}/${zip_name}"

if ! zip --recurse-paths --quiet "${zip_name}" "${ADDON_FILENAME}"; then
  echo "::error::Failed to create zip archive '${zip_name}'."
  exit 1
fi

echo "::notice::Successfully created addon package: ${zip_name}"
echo file="$file" >> "$GITHUB_OUTPUT"
