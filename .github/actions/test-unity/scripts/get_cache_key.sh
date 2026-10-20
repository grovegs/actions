#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if ! command -v unity > /dev/null 2>&1; then
  echo "::error::Unity CLI is not installed. Run setup-unity before test-unity"
  exit 1
fi

PROJECT_KEY=$(unity cache key "${PROJECT_DIR}" --quiet --no-banner)
EDITOR_KEY=$(unity cache key "${PROJECT_DIR}" --component editor --quiet --no-banner)

EDITOR_PREFIX="unity-library-${RUNNER_OS}-Test-${EDITOR_KEY:0:16}"
PREFIX="${EDITOR_PREFIX}-${PROJECT_KEY:0:16}"

{
  echo "prefix=${PREFIX}"
  echo "editor-prefix=${EDITOR_PREFIX}"
} >> "${GITHUB_OUTPUT}"

echo "::notice::Library cache key prefix: ${PREFIX}"
