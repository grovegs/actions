#!/usr/bin/env bash
set -euo pipefail

if [ -z "${VERSION_TYPE:-}" ]; then
  echo "::error::VERSION_TYPE environment variable is required"
  exit 1
fi

case "${VERSION_TYPE}" in
  major|minor|patch)
    echo "::notice::Version bump type: ${VERSION_TYPE}"
    ;;
  *)
    echo "::error::Invalid version-type: ${VERSION_TYPE}. Valid options: major, minor, patch"
    exit 1
    ;;
esac

echo "::notice::Fetching Git tags..."
if ! git fetch --tags --quiet 2>/dev/null; then
  echo "::warning::Could not fetch tags from remote"
fi

ALL_TAGS=$(git tag -l 2>/dev/null || echo "")

if [ -z "${ALL_TAGS}" ]; then
  LATEST_VERSION="0.0.0"
  echo "::notice::No tags found, using default version: ${LATEST_VERSION}"
else
  LATEST_VERSION=$(echo "${ALL_TAGS}" | \
    grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+$" | \
    sed 's/^v//' | \
    sort -V | \
    tail -n 1) || true

  if [ -z "${LATEST_VERSION}" ]; then
    LATEST_VERSION="0.0.0"
    echo "::notice::No valid semantic version tags found, using default: ${LATEST_VERSION}"
  else
    echo "::notice::Latest version found: ${LATEST_VERSION}"
  fi
fi

if [[ "${LATEST_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
else
  echo "::error::Invalid version format: ${LATEST_VERSION}. Expected format: X.Y.Z"
  exit 1
fi

case "${VERSION_TYPE}" in
  major)
    NEXT_VERSION="$((MAJOR + 1)).0.0"
    ;;
  minor)
    NEXT_VERSION="${MAJOR}.$((MINOR + 1)).0"
    ;;
  patch)
    NEXT_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
    ;;
esac

echo "::notice::Next version: ${NEXT_VERSION}"

{
  echo "latest-version=${LATEST_VERSION}"
  echo "next-version=${NEXT_VERSION}"
} >> "${GITHUB_OUTPUT}"
