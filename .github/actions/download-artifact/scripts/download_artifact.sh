#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${GITHUB_WORKSPACE}"

echo "Processing downloaded artifact(s)..."

if [ -n "$DOWNLOAD_PATH" ]; then
  echo "Files downloaded to: ${DOWNLOADED_TO}"

  find "${DOWNLOADED_TO}" -name "*.meta" -type f -delete 2>/dev/null || true

  echo "download-path=${DOWNLOADED_TO}" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "Attempting path restoration from metadata..."

if [ -n "$ARTIFACT_NAME" ]; then
  TEMP_DIR="${DOWNLOADED_TO}"
  METADATA_FILE="${TEMP_DIR}/${ARTIFACT_NAME}.meta"

  if [ ! -f "$METADATA_FILE" ]; then
    echo "::warning::No metadata found for artifact '${ARTIFACT_NAME}'. Files remain in: ${TEMP_DIR}"
    echo "download-path=${TEMP_DIR}" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  FILES_COUNT=$(jq -r '.files_count' "$METADATA_FILE")
  echo "Restoring ${FILES_COUNT} file(s) to original paths..."

  declare -a FILES
  while IFS= read -r line; do
    FILES+=("$line")
  done < <(jq -r '.files[]' "$METADATA_FILE")

  for file_path in "${FILES[@]}"; do
    [ -z "$file_path" ] && continue

    SOURCE="${TEMP_DIR}/${file_path}"
    TARGET="${WORKSPACE}/${file_path}"

    if [ ! -e "$SOURCE" ]; then
      echo "::warning::Source not found: ${file_path}"
      continue
    fi

    TARGET_DIR=$(dirname "$TARGET")
    mkdir -p "$TARGET_DIR"

    if [ -e "$TARGET" ]; then
      echo "::warning::Overwriting existing: ${file_path}"
      rm -rf "$TARGET"
    fi

    mv "$SOURCE" "$TARGET"
  done

  rm -rf "$TEMP_DIR"

  echo "✓ Restored to original paths"
  echo "download-path=${WORKSPACE}" >> "$GITHUB_OUTPUT"

else
  if [ "$MERGE_MULTIPLE" = "true" ]; then
    METADATA_FILES=("${DOWNLOADED_TO}"/*.meta)

    if [ ! -f "${METADATA_FILES[0]}" ]; then
      echo "::warning::No metadata found. Files remain in: ${DOWNLOADED_TO}"
      echo "download-path=${DOWNLOADED_TO}" >> "$GITHUB_OUTPUT"
      exit 0
    fi

    for METADATA_FILE in "${METADATA_FILES[@]}"; do
      [ ! -f "$METADATA_FILE" ] && continue

      FILES_COUNT=$(jq -r '.files_count' "$METADATA_FILE")
      echo "Restoring ${FILES_COUNT} file(s) to original paths..."

      declare -a FILES
      while IFS= read -r line; do
        FILES+=("$line")
      done < <(jq -r '.files[]' "$METADATA_FILE")

      for file_path in "${FILES[@]}"; do
        [ -z "$file_path" ] && continue

        SOURCE="${DOWNLOADED_TO}/${file_path}"
        TARGET="${WORKSPACE}/${file_path}"

        if [ ! -e "$SOURCE" ]; then
          echo "::warning::Source not found: ${file_path}"
          continue
        fi

        TARGET_DIR=$(dirname "$TARGET")
        mkdir -p "$TARGET_DIR"

        if [ -e "$TARGET" ]; then
          echo "::warning::Overwriting existing: ${file_path}"
          rm -rf "$TARGET"
        fi

        mv "$SOURCE" "$TARGET"
      done
    done

    rm -rf "$DOWNLOADED_TO"
    echo "✓ Restored to original paths"
    echo "download-path=${WORKSPACE}" >> "$GITHUB_OUTPUT"

  else
    TOTAL_RESTORED=0

    for artifact_dir in "${DOWNLOADED_TO}"/*; do
      [ ! -d "$artifact_dir" ] && continue

      ARTIFACT_NAME_FROM_DIR=$(basename "$artifact_dir")
      METADATA_FILE="${artifact_dir}/${ARTIFACT_NAME_FROM_DIR}.meta"

      if [ ! -f "$METADATA_FILE" ]; then
        echo "::warning::No metadata for '${ARTIFACT_NAME_FROM_DIR}'. Skipping restoration."
        continue
      fi

      echo "Restoring artifact: ${ARTIFACT_NAME_FROM_DIR}"

      declare -a FILES
      while IFS= read -r line; do
        FILES+=("$line")
      done < <(jq -r '.files[]' "$METADATA_FILE")

      for file_path in "${FILES[@]}"; do
        [ -z "$file_path" ] && continue

        SOURCE="${artifact_dir}/${file_path}"
        TARGET="${WORKSPACE}/${file_path}"

        if [ ! -e "$SOURCE" ]; then
          echo "::warning::Source not found: ${file_path}"
          continue
        fi

        TARGET_DIR=$(dirname "$TARGET")
        mkdir -p "$TARGET_DIR"

        if [ -e "$TARGET" ]; then
          echo "::warning::Overwriting existing: ${file_path}"
          rm -rf "$TARGET"
        fi

        mv "$SOURCE" "$TARGET"
        TOTAL_RESTORED=$((TOTAL_RESTORED + 1))
      done
    done

    rm -rf "$DOWNLOADED_TO"
    echo "✓ Restored ${TOTAL_RESTORED} file(s) to original paths"
    echo "download-path=${WORKSPACE}" >> "$GITHUB_OUTPUT"
  fi
fi
