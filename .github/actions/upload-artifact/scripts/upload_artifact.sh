#!/usr/bin/env bash
set -euo pipefail

STAGING_DIR=".artifact-staging-${ARTIFACT_NAME}"
METADATA_DIR="${STAGING_DIR}/.artifact-meta"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$METADATA_DIR"

echo "Preparing artifact: ${ARTIFACT_NAME}"

mapfile -t PATHS <<< "$ARTIFACT_PATH"

FILES_FOUND=0
FILE_INDEX=0

for path in "${PATHS[@]}"; do
  path=$(echo "$path" | xargs)

  [ -z "$path" ] && continue

  if [[ "$path" == !* ]]; then
    continue
  fi

  shopt -s nullglob
  shopt -s dotglob

  for item in $path; do
    if [ -e "$item" ]; then
      FILES_FOUND=$((FILES_FOUND + 1))

      abs_path=$(cd "$(dirname "$item")" && pwd)/$(basename "$item")

      echo "$abs_path" >> "${METADATA_DIR}/paths.txt"

      if [ -d "$item" ]; then
        cp -r "$item" "${STAGING_DIR}/file-${FILE_INDEX}"
      else
        cp "$item" "${STAGING_DIR}/file-${FILE_INDEX}"
      fi

      FILE_INDEX=$((FILE_INDEX + 1))
    fi
  done

  shopt -u dotglob
  shopt -u nullglob
done

echo "Found $FILES_FOUND file(s)"

if [ "$FILES_FOUND" -eq 0 ]; then
  echo "::error::No files found matching the specified paths"
  exit 1
fi

echo "staging-dir=$STAGING_DIR" >> "$GITHUB_OUTPUT"
