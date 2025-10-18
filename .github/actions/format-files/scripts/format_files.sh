#!/usr/bin/env bash
set -euo pipefail

if [ -z "${FILES_PATTERN:-}" ]; then
  echo "::error::FILES_PATTERN environment variable is required"
  exit 1
fi

echo "Formatting files with pattern: ${FILES_PATTERN}"

if ! command -v npx &> /dev/null; then
  echo "::error::npx is not available"
  exit 1
fi

PRETTIER_ARGS=(
  --write
  "${FILES_PATTERN}"
  --plugin prettier-plugin-sh
)

if [ -n "${IGNORE_PATH}" ] && [ -f "${IGNORE_PATH}" ]; then
  echo "Using ignore file: ${IGNORE_PATH}"
  PRETTIER_ARGS+=(--ignore-path "${IGNORE_PATH}")
fi

npx prettier "${PRETTIER_ARGS[@]}"

echo "File formatting completed successfully"
