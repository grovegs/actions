#!/usr/bin/env bash
set -euo pipefail

if [ -z "${ARTIFACT_NAME:-}" ]; then
  echo "::error::ARTIFACT_NAME environment variable is required"
  exit 1
fi

if [ -z "${ARTIFACT_PATH:-}" ]; then
  echo "::error::ARTIFACT_PATH environment variable is required"
  exit 1
fi

if [ -z "${GITHUB_WORKSPACE:-}" ]; then
  echo "::error::GITHUB_WORKSPACE environment variable is required"
  exit 1
fi

WORKSPACE="${GITHUB_WORKSPACE}"
STAGING_DIR_NAME=".artifact-staging-${ARTIFACT_NAME}"
STAGING_DIR="${WORKSPACE}/${STAGING_DIR_NAME}"
METADATA_FILE="${STAGING_DIR}/${ARTIFACT_NAME}.meta"

INCLUDE_HIDDEN="${INCLUDE_HIDDEN:-false}"

echo "::notice::Preparing artifact: ${ARTIFACT_NAME}"

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

mapfile -t PATHS <<< "${ARTIFACT_PATH}"

FILES_FOUND=0
declare -a FILE_ENTRIES

if [ "${INCLUDE_HIDDEN}" = "true" ]; then
  shopt -s dotglob
fi
shopt -s nullglob

for path_pattern in "${PATHS[@]}"; do
  path_pattern=$(echo "${path_pattern}" | xargs)

  if [ -z "${path_pattern}" ]; then
    continue
  fi

  if [[ "${path_pattern}" == !* ]]; then
    continue
  fi

  cd "${WORKSPACE}"

  for item in ${path_pattern}; do
    if [ ! -e "${item}" ]; then
      continue
    fi

    if [ -f "${item}" ]; then
      ITEM_DIR=$(cd "$(dirname "${item}")" && pwd)
      ITEM_NAME=$(basename "${item}")
      ABS_PATH="${ITEM_DIR}/${ITEM_NAME}"
    elif [ -d "${item}" ]; then
      ABS_PATH=$(cd "${item}" && pwd)
    else
      continue
    fi

    REL_PATH="${ABS_PATH#"${WORKSPACE}"/}"

    if [ "${REL_PATH}" = "${ABS_PATH}" ]; then
      echo "::warning::Skipping item outside workspace: ${item}"
      continue
    fi

    TARGET_DIR="${STAGING_DIR}/$(dirname "${REL_PATH}")"
    mkdir -p "${TARGET_DIR}"

    if [ -f "${item}" ]; then
      cp -p "${item}" "${STAGING_DIR}/${REL_PATH}"
    elif [ -d "${item}" ]; then
      cp -rp "${item}" "${STAGING_DIR}/${REL_PATH}"
    fi

    FILE_ENTRIES+=("${REL_PATH}")
    FILES_FOUND=$((FILES_FOUND + 1))
  done
done

shopt -u nullglob
if [ "${INCLUDE_HIDDEN}" = "true" ]; then
  shopt -u dotglob
fi

if [ "${FILES_FOUND}" -eq 0 ]; then
  echo "::error::No files found. All items were outside workspace or did not match patterns"
  exit 1
fi

{
  cat << EOF
{
  "version": "1.0",
  "artifact_name": "${ARTIFACT_NAME}",
  "workspace": "${WORKSPACE}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "files_count": ${FILES_FOUND},
  "files": [
EOF

  FIRST=true
  for entry in "${FILE_ENTRIES[@]}"; do
    if [ "${FIRST}" = "true" ]; then
      FIRST=false
    else
      echo ","
    fi
    echo -n "    \"${entry}\""
  done

  cat << EOF

  ]
}
EOF
} > "${METADATA_FILE}"

echo "::notice::✓ Files prepared: ${FILES_FOUND}"

{
  echo "staging-dir=${STAGING_DIR}"
} >> "${GITHUB_OUTPUT}"
