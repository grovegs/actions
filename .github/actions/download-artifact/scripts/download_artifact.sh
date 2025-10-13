#!/usr/bin/env bash
set -euo pipefail

TEMP_DIR=".artifact-temp-${ARTIFACT_NAME}"
METADATA_FILE="${TEMP_DIR}/.artifact-meta/paths.txt"

if [ ! -f "$METADATA_FILE" ]; then
  echo "::warning::No metadata found, skipping path restoration"

  if [ -n "$DOWNLOAD_PATH" ]; then
    mkdir -p "$DOWNLOAD_PATH"
    shopt -s nullglob
    shopt -s dotglob
    for item in "${TEMP_DIR}"/*; do
      [ "$(basename "$item")" = ".artifact-meta" ] && continue
      cp -r "$item" "$DOWNLOAD_PATH/"
    done
    shopt -u dotglob
    shopt -u nullglob
  fi

  rm -rf "$TEMP_DIR"
  exit 0
fi

if [ -n "$DOWNLOAD_PATH" ]; then
  echo "Extracting to custom path: $DOWNLOAD_PATH"
  mkdir -p "$DOWNLOAD_PATH"

  shopt -s nullglob
  shopt -s dotglob
  for item in "${TEMP_DIR}"/*; do
    [ "$(basename "$item")" = ".artifact-meta" ] && continue
    cp -r "$item" "$DOWNLOAD_PATH/"
  done
  shopt -u dotglob
  shopt -u nullglob
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
        cp -r "$source_item" "$original_path"
      else
        cp "$source_item" "$original_path"
      fi

      echo "Restored: $original_path"
    fi

    FILE_INDEX=$((FILE_INDEX + 1))
  done < "$METADATA_FILE"
fi

rm -rf "$TEMP_DIR"
