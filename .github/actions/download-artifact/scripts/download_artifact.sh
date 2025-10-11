#!/bin/bash

set -e

if [[ -z "${ARTIFACT_NAME}" ]]; then
  echo "::error::Artifact name is required."
  exit 1
fi

TEMP_DIR=".artifact-temp-${ARTIFACT_NAME}"

if [[ ! -d "${TEMP_DIR}" ]]; then
  echo "::error::Artifact temp directory not found."
  exit 1
fi

if [[ -z "${DOWNLOAD_PATH}" ]]; then
  RESTORE_PATHS="true"
  DOWNLOAD_PATH="."
else
  RESTORE_PATHS="false"
fi

DOWNLOAD_PATH=$(realpath "${DOWNLOAD_PATH}")
METADATA_FILE="${TEMP_DIR}/.artifact_metadata.json"

declare -a downloaded_files=()

if [[ "${RESTORE_PATHS}" == "true" && -f "$METADATA_FILE" ]]; then
  echo "::notice::Restoring files to original paths"

  metadata=$(cat "$METADATA_FILE")
  include_hidden=$(echo "$metadata" | jq -r '.include_hidden // false')

  [[ "$include_hidden" == "true" ]] && shopt -s dotglob

  path_count=$(echo "$metadata" | jq '.paths | length')

  for ((i=0; i<path_count; i++)); do
    original_path=$(echo "$metadata" | jq -r ".paths[$i].original")

    [[ -z "$original_path" || "$original_path" == "null" ]] && continue

    source_file="${TEMP_DIR}/${original_path}"
    target_file="${DOWNLOAD_PATH}/${original_path}"

    [[ ! -e "$source_file" ]] && continue

    mkdir -p "$(dirname "$target_file")"

    if [[ -d "$source_file" ]]; then
      cp -r "$source_file" "$target_file"
    else
      cp "$source_file" "$target_file"
    fi

    downloaded_files+=("$original_path")
  done

  shopt -u dotglob

  echo "::notice::Restored ${#downloaded_files[@]} file(s)"

else
  [[ "${RESTORE_PATHS}" == "true" ]] && echo "::warning::Metadata not found. Copying without restoration."

  mkdir -p "${DOWNLOAD_PATH}"

  while read -r file; do
    rel_path=$(realpath --relative-to="${TEMP_DIR}" "$file")
    target_file="${DOWNLOAD_PATH}/${rel_path}"

    mkdir -p "$(dirname "$target_file")"
    cp "$file" "$target_file"

    downloaded_files+=("$rel_path")
  done < <(find "${TEMP_DIR}" -type f ! -name '.artifact_metadata.json')

  echo "::notice::Copied ${#downloaded_files[@]} file(s)"
fi

rm -rf "${TEMP_DIR}"

total_size=$(du -sb "${DOWNLOAD_PATH}" 2>/dev/null | cut -f1 || echo "0")
size_mb=$((total_size / 1024 / 1024))

echo "::notice::Downloaded ${size_mb}MB"
