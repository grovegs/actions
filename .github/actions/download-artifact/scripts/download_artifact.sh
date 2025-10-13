#!/bin/bash
set -euo pipefail

TEMP_DIR="${GITHUB_WORKSPACE}/.artifact-temp-${ARTIFACT_NAME}"
METADATA_FILE="${TEMP_DIR}/.metadata/paths.txt"

if [ ! -f "$METADATA_FILE" ]; then
  echo "::warning::No metadata found, skipping path restoration"

  if [ -n "$DOWNLOAD_PATH" ]; then
    if [[ "$DOWNLOAD_PATH" = /* ]]; then
      TARGET_PATH="$DOWNLOAD_PATH"
    else
      TARGET_PATH="${GITHUB_WORKSPACE}/${DOWNLOAD_PATH}"
    fi

    mkdir -p "$TARGET_PATH"

    shopt -s nullglob dotglob
    for item in "${TEMP_DIR}"/*; do
      [ "$(basename "$item")" = ".metadata" ] && continue
      cp -r "$item" "$TARGET_PATH/"
    done
    shopt -u dotglob nullglob
  fi

  rm -rf "$TEMP_DIR"
  exit 0
fi

if [ -n "$DOWNLOAD_PATH" ]; then
  if [[ "$DOWNLOAD_PATH" = /* ]]; then
    TARGET_PATH="$DOWNLOAD_PATH"
  else
    TARGET_PATH="${GITHUB_WORKSPACE}/${DOWNLOAD_PATH}"
  fi

  echo "Extracting to: $TARGET_PATH"
  mkdir -p "$TARGET_PATH"

  shopt -s nullglob dotglob
  for item in "${TEMP_DIR}"/*; do
    [ "$(basename "$item")" = ".metadata" ] && continue
    cp -r "$item" "$TARGET_PATH/"
  done
  shopt -u dotglob nullglob
else
  echo "Restoring files to original paths"

  FILE_INDEX=0
  while IFS= read -r original_path; do
    [ -z "$original_path" ] && continue

    source_item="${TEMP_DIR}/file-${FILE_INDEX}"

    if [ -e "$source_item" ]; then
      target_dir=$(dirname "$original_path")
      mkdir -p "$target_dir"

      if [ -d "$source_item" ]; then
        rm -rf "$original_path"
      fi

      cp -r "$source_item" "$original_path"
      echo "Restored: $original_path"
    fi

    FILE_INDEX=$((FILE_INDEX + 1))
  done < "$METADATA_FILE"
fi

rm -rf "$TEMP_DIR"
