#!/usr/bin/env bash
set -euo pipefail

STAGING_DIR="${GITHUB_WORKSPACE}/.artifact-staging-${ARTIFACT_NAME}"
METADATA_DIR="${STAGING_DIR}/.metadata"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$METADATA_DIR"

cd "$GITHUB_WORKSPACE"

echo "Preparing artifact: ${ARTIFACT_NAME}"

mapfile -t PATHS <<< "$ARTIFACT_PATH"

FILES_FOUND=0
FILE_INDEX=0

shopt -s nullglob dotglob globstar

for path in "${PATHS[@]}"; do
  path=$(echo "$path" | xargs)
  [ -z "$path" ] && continue
  [[ "$path" == !* ]] && continue

  for item in $path; do
    [ ! -e "$item" ] && continue

    FILES_FOUND=$((FILES_FOUND + 1))

    if [ -f "$item" ]; then
      abs_path=$(cd "$(dirname "$item")" && pwd)/$(basename "$item")
    else
      abs_path=$(cd "$item" && pwd)
    fi

    echo "$abs_path" >> "${METADATA_DIR}/paths.txt"

    cp -r "$item" "${STAGING_DIR}/file-${FILE_INDEX}"

    FILE_INDEX=$((FILE_INDEX + 1))
  done
done

shopt -u globstar dotglob nullglob

echo "Found $FILES_FOUND file(s)"

if [ "$FILES_FOUND" -eq 0 ]; then
  echo "::error::No files found matching the specified paths"
  exit 1
fi

echo "staging-dir=$STAGING_DIR" >> "$GITHUB_OUTPUT"
