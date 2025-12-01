#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RELEASE_VERSION:-}" ]; then
  echo "::error::RELEASE_VERSION environment variable is required"
  exit 1
fi

if [ -z "${RELEASE_TITLE:-}" ]; then
  echo "::error::RELEASE_TITLE environment variable is required"
  exit 1
fi

if [ -z "${RELEASE_NOTES:-}" ]; then
  echo "::error::RELEASE_NOTES environment variable is required"
  exit 1
fi

if [ -z "${GH_TOKEN:-}" ]; then
  echo "::error::GH_TOKEN environment variable is required"
  exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
  echo "::error::gh (GitHub CLI) is not installed or not in PATH"
  exit 1
fi

echo "::notice::Creating GitHub release '${RELEASE_VERSION}'"
echo "::notice::Title: ${RELEASE_TITLE}"

NOTES_FILE=$(mktemp)
printf '%s' "${RELEASE_NOTES}" > "${NOTES_FILE}"

declare -a GH_ARGS
GH_ARGS=(
  "release"
  "create"
  "${RELEASE_VERSION}"
  "--title"
  "${RELEASE_TITLE}"
  "--notes-file"
  "${NOTES_FILE}"
)

if [ -n "${RELEASE_ASSETS:-}" ]; then
  echo "::notice::Processing release assets"

  declare -a ASSET_PATHS
  IFS=' ' read -ra ASSET_PATHS <<< "${RELEASE_ASSETS}"

  for asset in "${ASSET_PATHS[@]}"; do
    asset=$(echo "${asset}" | xargs)

    if [ -z "${asset}" ]; then
      continue
    fi

    if [ ! -e "${asset}" ]; then
      rm -f "${NOTES_FILE}"
      echo "::error::Asset '${asset}' does not exist"
      exit 1
    fi

    echo "::notice::  + ${asset}"
    GH_ARGS+=("${asset}")
  done
else
  echo "::notice::No assets to upload"
fi

MAX_RETRIES=3
RETRY_DELAY=60
ATTEMPT=0
SUCCESS=false

while [ ${ATTEMPT} -le ${MAX_RETRIES} ]; do
  if [ ${ATTEMPT} -gt 0 ]; then
    echo "::notice::Retrying release creation (attempt ${ATTEMPT}/${MAX_RETRIES})..."
    echo "::notice::Waiting ${RETRY_DELAY} seconds..."
    sleep ${RETRY_DELAY}
  fi

  OUTPUT=$(mktemp)
  if gh "${GH_ARGS[@]}" > "${OUTPUT}" 2>&1; then
    cat "${OUTPUT}"
    echo "::notice::✓ GitHub release created successfully"
    SUCCESS=true
    rm -f "${OUTPUT}"
    break
  fi

  cat "${OUTPUT}"

  if grep -q "already_exists" "${OUTPUT}" 2>/dev/null || \
     grep -q "Release.*already exists" "${OUTPUT}" 2>/dev/null; then
    echo "::warning::Release already exists"
    SUCCESS=true
    rm -f "${OUTPUT}"
    break
  fi

  if grep -q "Bad credentials" "${OUTPUT}" 2>/dev/null || \
     grep -q "401" "${OUTPUT}" 2>/dev/null; then
    echo "::error::Authentication failed - invalid GH_TOKEN"
    rm -f "${OUTPUT}"
    break
  fi

  if grep -q "500" "${OUTPUT}" 2>/dev/null || \
     grep -q "503" "${OUTPUT}" 2>/dev/null || \
     grep -q "timeout" "${OUTPUT}" 2>/dev/null; then
    if [ ${ATTEMPT} -lt ${MAX_RETRIES} ]; then
      echo "::warning::Server error, will retry"
      ATTEMPT=$((ATTEMPT + 1))
      rm -f "${OUTPUT}"
      continue
    fi
  fi

  ATTEMPT=$((ATTEMPT + 1))
  rm -f "${OUTPUT}"
done

rm -f "${NOTES_FILE}"

if [ "${SUCCESS}" = false ]; then
  echo "::error::Failed to create GitHub release after $((MAX_RETRIES + 1)) attempts"
  exit 1
fi

echo "::notice::✓ GitHub release created: ${RELEASE_VERSION}"
