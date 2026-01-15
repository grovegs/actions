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

  find "${DOWNLOAD_DIR}" -name "*.meta" -type f -delete 2>/dev/null || true

  {
    echo "download-path=${DOWNLOAD_DIR}"
  } >> "${GITHUB_OUTPUT}"

  echo "::notice::Files available at: ${DOWNLOAD_DIR}"
  exit 0
fi

METADATA_FILES=$(find "${DOWNLOAD_DIR}" -name "*.meta" -type f 2>/dev/null || true)

if [ -z "${METADATA_FILES}" ]; then
  echo "::warning::No metadata files found. Files will remain in download directory."

  {
    echo "download-path=${DOWNLOAD_DIR}"
  } >> "${GITHUB_OUTPUT}"

  echo "::notice::Files available at: ${DOWNLOAD_DIR}"
  exit 0
fi

echo "::notice::Restoring files to original paths using metadata"

parse_artifact_name() {
  local meta_file="$1"

  if command -v jq &>/dev/null; then
    jq -r '.artifact_name // empty' "${meta_file}" 2>/dev/null
  else
    grep -o '"artifact_name"[[:space:]]*:[[:space:]]*"[^"]*"' "${meta_file}" | sed 's/.*: *"\([^"]*\)".*/\1/'
  fi
}

parse_file_paths() {
  local meta_file="$1"

  if command -v jq &>/dev/null; then
    jq -r '.files[]? // empty' "${meta_file}" 2>/dev/null
  else
    sed -n '/"files":/,/]/p' "${meta_file}" | grep -o '"[^"]*"' | grep -v '"files"' | sed 's/"//g'
  fi
}

RESTORED_COUNT=0
METADATA_COUNT=0

while IFS= read -r METADATA_FILE; do
  if [ ! -f "${METADATA_FILE}" ]; then
    continue
  fi

  METADATA_COUNT=$((METADATA_COUNT + 1))
  ARTIFACT_DIR=$(dirname "${METADATA_FILE}")
  ARTIFACT_NAME_FROM_META=$(parse_artifact_name "${METADATA_FILE}")

  echo "Processing artifact: ${ARTIFACT_NAME_FROM_META:-unknown} from ${ARTIFACT_DIR}"

  FILE_PATHS=$(parse_file_paths "${METADATA_FILE}")

  if [ -z "${FILE_PATHS}" ]; then
    echo "::warning::No file paths found in metadata: ${METADATA_FILE}"
    continue
  fi

  while IFS= read -r rel_path; do
    if [ -z "${rel_path}" ]; then
      continue
    fi

    SOURCE="${ARTIFACT_DIR}/${rel_path}"
    TARGET="${WORKSPACE}/${rel_path}"

    if [ ! -e "${SOURCE}" ]; then
      echo "::warning::Source not found: ${SOURCE}"
      continue
    fi

    TARGET_DIR=$(dirname "${TARGET}")
    mkdir -p "${TARGET_DIR}"

    if [ -e "${TARGET}" ]; then
      echo "::warning::Target already exists, overwriting: ${TARGET}"
      rm -rf "${TARGET}"
    fi

    mv "${SOURCE}" "${TARGET}"
    echo "  Restored: ${rel_path}"
    RESTORED_COUNT=$((RESTORED_COUNT + 1))
  done <<< "${FILE_PATHS}"

  rm -f "${METADATA_FILE}"

  if [ -d "${ARTIFACT_DIR}" ]; then
    find "${ARTIFACT_DIR}" -type d -empty -delete 2>/dev/null || true

    if [ -z "$(ls -A "${ARTIFACT_DIR}" 2>/dev/null)" ]; then
      rm -rf "${ARTIFACT_DIR}"
      echo "  Cleaned up artifact directory: ${ARTIFACT_DIR}"
    else
      echo "::warning::Artifact directory not empty after restoration: ${ARTIFACT_DIR}"
      echo "Remaining contents:"
      ls -la "${ARTIFACT_DIR}"
    fi
  fi
done <<< "${METADATA_FILES}"

if [ -d "${DOWNLOAD_DIR}" ]; then
  if [ -z "$(ls -A "${DOWNLOAD_DIR}" 2>/dev/null)" ]; then
    rm -rf "${DOWNLOAD_DIR}"
    echo "::notice::Cleaned up download directory: ${DOWNLOAD_DIR}"
  else
    echo "::warning::Download directory not empty after restoration: ${DOWNLOAD_DIR}"
    echo "Remaining contents:"
    ls -la "${DOWNLOAD_DIR}"
  fi
fi

{
  echo "download-path=${WORKSPACE}"
} >> "${GITHUB_OUTPUT}"

echo "::notice::Successfully restored ${RESTORED_COUNT} files from ${METADATA_COUNT} artifacts to original paths"
