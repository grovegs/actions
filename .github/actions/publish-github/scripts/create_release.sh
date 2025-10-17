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
echo "  Title: ${RELEASE_TITLE}"

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

    echo "  + ${asset}"
    GH_ARGS+=("${asset}")
  done
else
  echo "::notice::No assets to upload"
fi

echo "::notice::Executing GitHub release creation"
if ! gh "${GH_ARGS[@]}"; then
  rm -f "${NOTES_FILE}"
  echo "::error::Failed to create GitHub release"
  exit 1
fi

rm -f "${NOTES_FILE}"

echo "::notice::✓ Successfully created GitHub release: ${RELEASE_VERSION}"
