#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RELEASE_VERSION:-}" ]; then
  echo "::error::RELEASE_VERSION environment variable is required"
  exit 1
fi

if [[ ! "${RELEASE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Invalid version: ${RELEASE_VERSION}. Expected format: X.Y.Z"
  exit 1
fi

TAG_NAME="v${RELEASE_VERSION}"

if git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null || git ls-remote --exit-code --tags origin "refs/tags/${TAG_NAME}" >/dev/null 2>&1; then
  echo "::error::Tag ${TAG_NAME} already exists"
  exit 1
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

COMMIT=$(git rev-parse HEAD)
echo "::notice::Creating tag ${TAG_NAME} on ${COMMIT}"

if ! git tag -a "${TAG_NAME}" -m "Release ${RELEASE_VERSION}" "${COMMIT}"; then
  echo "::error::Failed to create tag ${TAG_NAME}"
  exit 1
fi

if ! git push origin "refs/tags/${TAG_NAME}"; then
  echo "::error::Failed to push tag ${TAG_NAME}"
  exit 1
fi

echo "tag=${TAG_NAME}" >> "${GITHUB_OUTPUT}"
echo "::notice::✅ Tag ${TAG_NAME} created and pushed successfully"
