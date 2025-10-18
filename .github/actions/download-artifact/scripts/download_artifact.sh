#!/usr/bin/env bash
set -euo pipefail

if [ -z "${ARTIFACT_NAME:-}" ]; then
  echo "::error::ARTIFACT_NAME environment variable is required"
  exit 1
fi

if [ -z "${GITHUB_WORKSPACE:-}" ]; then
  echo "::error::GITHUB_WORKSPACE environment variable is required"
  exit 1
fi

WORKSPACE="${GITHUB_WORKSPACE}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-}"
DESTINATION_PATH="${DESTINATION_PATH:-}"

echo "::notice::Restoring artifact: ${ARTIFACT_NAME}"

if [ -z "${DOWNLOAD_PATH}" ]; then
  echo "::error::Download path not available from download step"
  exit 1
fi

DOWNLOAD_DIR="${DOWNLOAD_PATH}"

if [ ! -d "${DOWNLOAD_DIR}" ]; then
  echo "::error::Download directory not found: ${DOWNLOAD_DIR}"
  exit 1
fi

if [ -n "${DESTINATION_PATH}" ]; then
  echo "::notice::Custom destination path specified, skipping metadata restoration"

  METADATA_FILES=$(find "${DOWNLOAD_DIR}" -name "*.meta" -type f 2>/dev/null || true)

  if [ -n "${METADATA_FILES}" ]; then
    while IFS= read -r meta_file; do
      rm -f "${meta_file}"
    done <<< "${METADATA_FILES}"
  fi

  {
    echo "download-path=${DOWNLOAD_DIR}"
  } >> "${GITHUB_OUTPUT}"

  echo "::notice::✓ Files available at: ${DOWNLOAD_DIR}"
else
  METADATA_FILE="${DOWNLOAD_DIR}/${ARTIFACT_NAME}.meta"

  if [ ! -f "${METADATA_FILE}" ]; then
    echo "::warning::No metadata file found. Files will remain in download directory."

    {
      echo "download-path=${DOWNLOAD_DIR}"
    } >> "${GITHUB_OUTPUT}"

    echo "::notice::✓ Files available at: ${DOWNLOAD_DIR}"
  else
    echo "::notice::Restoring files to original paths using metadata"

    declare -a FILE_PATHS
    while IFS= read -r line; do
      if [[ "${line}" =~ \"([^\"]+)\" ]]; then
        FILE_PATHS+=("${BASH_REMATCH[1]}")
      fi
    done < <(grep -o '"[^"]*"' "${METADATA_FILE}" | grep -v '"version"' | grep -v '"artifact_name"' | grep -v '"workspace"' | grep -v '"created_at"' | grep -v '"files_count"' | grep -v '"files"')

    for rel_path in "${FILE_PATHS[@]}"; do
      SOURCE="${DOWNLOAD_DIR}/${rel_path}"
      TARGET="${WORKSPACE}/${rel_path}"

      if [ ! -e "${SOURCE}" ]; then
        continue
      fi

      TARGET_DIR=$(dirname "${TARGET}")
      mkdir -p "${TARGET_DIR}"

      mv "${SOURCE}" "${TARGET}"
      echo "Restored: ${rel_path}"
    done

    rm -f "${METADATA_FILE}"

    if [ -d "${DOWNLOAD_DIR}" ] && [ -z "$(ls -A "${DOWNLOAD_DIR}")" ]; then
      rm -rf "${DOWNLOAD_DIR}"
    fi

    {
      echo "download-path=${WORKSPACE}"
    } >> "${GITHUB_OUTPUT}"

    echo "::notice::✓ Files restored to original paths"
  fi
fi
