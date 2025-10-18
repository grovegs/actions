#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DOWNLOADED_TO:-}" ]; then
  echo "::error::DOWNLOADED_TO environment variable is required"
  exit 1
fi

WORKSPACE="${GITHUB_WORKSPACE}"

echo "::notice::Processing downloaded artifact(s)..."

if [ -n "${DOWNLOAD_PATH:-}" ]; then
  echo "::notice::Files downloaded to: ${DOWNLOADED_TO}"

  find "${DOWNLOADED_TO}" -name "*.meta" -type f -delete 2>/dev/null || true

  echo "download-path=${DOWNLOADED_TO}" >> "${GITHUB_OUTPUT}"
  exit 0
fi

echo "::notice::Attempting path restoration from metadata..."

restore_from_metadata() {
  local metadata_file="$1"
  local source_base="$2"

  if [ ! -f "${metadata_file}" ]; then
    return 1
  fi

  local files_count
  files_count=$(jq -r '.files_count' "${metadata_file}")
  echo "::notice::Restoring ${files_count} file(s) to original paths..."

  local -a files
  while IFS= read -r line; do
    files+=("${line}")
  done < <(jq -r '.files[]' "${metadata_file}")

  for file_path in "${files[@]}"; do
    [ -z "${file_path}" ] && continue

    local source="${source_base}/${file_path}"
    local target="${WORKSPACE}/${file_path}"

    if [ ! -e "${source}" ]; then
      echo "::warning::Source not found: ${file_path}"
      continue
    fi

    local target_dir
    target_dir=$(dirname "${target}")
    mkdir -p "${target_dir}"

    if [ -e "${target}" ]; then
      echo "::warning::Overwriting existing: ${file_path}"
      rm -rf "${target}"
    fi

    mv "${source}" "${target}"
  done

  return 0
}

if [ -n "${ARTIFACT_NAME:-}" ]; then
  TEMP_DIR="${DOWNLOADED_TO}"
  METADATA_FILE="${TEMP_DIR}/${ARTIFACT_NAME}.meta"

  if [ ! -f "${METADATA_FILE}" ]; then
    echo "::warning::No metadata found for artifact '${ARTIFACT_NAME}'. Files remain in: ${TEMP_DIR}"
    echo "download-path=${TEMP_DIR}" >> "${GITHUB_OUTPUT}"
    exit 0
  fi

  restore_from_metadata "${METADATA_FILE}" "${TEMP_DIR}"
  rm -rf "${TEMP_DIR}"

  echo "::notice::✓ Restored to original paths"
  echo "download-path=${WORKSPACE}" >> "${GITHUB_OUTPUT}"

else
  if [ "${MERGE_MULTIPLE:-false}" = "true" ]; then
    shopt -s nullglob
    METADATA_FILES=("${DOWNLOADED_TO}"/*.meta)
    shopt -u nullglob

    if [ ${#METADATA_FILES[@]} -eq 0 ]; then
      echo "::warning::No metadata found. Files remain in: ${DOWNLOADED_TO}"
      echo "download-path=${DOWNLOADED_TO}" >> "${GITHUB_OUTPUT}"
      exit 0
    fi

    for metadata_file in "${METADATA_FILES[@]}"; do
      [ ! -f "${metadata_file}" ] && continue
      restore_from_metadata "${metadata_file}" "${DOWNLOADED_TO}"
    done

    rm -rf "${DOWNLOADED_TO}"
    echo "::notice::✓ Restored to original paths"
    echo "download-path=${WORKSPACE}" >> "${GITHUB_OUTPUT}"

  else
    TOTAL_RESTORED=0

    shopt -s nullglob
    for artifact_dir in "${DOWNLOADED_TO}"/*; do
      [ ! -d "${artifact_dir}" ] && continue

      ARTIFACT_NAME_FROM_DIR=$(basename "${artifact_dir}")
      METADATA_FILE="${artifact_dir}/${ARTIFACT_NAME_FROM_DIR}.meta"

      if [ ! -f "${METADATA_FILE}" ]; then
        echo "::warning::No metadata for '${ARTIFACT_NAME_FROM_DIR}'. Skipping restoration."
        continue
      fi

      echo "::notice::Restoring artifact: ${ARTIFACT_NAME_FROM_DIR}"

      declare -a FILES_TO_RESTORE
      while IFS= read -r line; do
        FILES_TO_RESTORE+=("${line}")
      done < <(jq -r '.files[]' "${METADATA_FILE}")

      for file_path in "${FILES_TO_RESTORE[@]}"; do
        [ -z "${file_path}" ] && continue

        SOURCE="${artifact_dir}/${file_path}"
        TARGET="${WORKSPACE}/${file_path}"

        if [ ! -e "${SOURCE}" ]; then
          echo "::warning::Source not found: ${file_path}"
          continue
        fi

        TARGET_DIR=$(dirname "${TARGET}")
        mkdir -p "${TARGET_DIR}"

        if [ -e "${TARGET}" ]; then
          echo "::warning::Overwriting existing: ${file_path}"
          rm -rf "${TARGET}"
        fi

        mv "${SOURCE}" "${TARGET}"
        TOTAL_RESTORED=$((TOTAL_RESTORED + 1))
      done

      unset FILES_TO_RESTORE
    done
    shopt -u nullglob

    rm -rf "${DOWNLOADED_TO}"
    echo "::notice::✓ Restored ${TOTAL_RESTORED} file(s) to original paths"
    echo "download-path=${WORKSPACE}" >> "${GITHUB_OUTPUT}"
  fi
fi
