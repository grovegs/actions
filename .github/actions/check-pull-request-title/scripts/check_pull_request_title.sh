#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PULL_REQUEST_TITLE:-}" ]; then
  echo "::error::PULL_REQUEST_TITLE environment variable is required"
  exit 1
fi

TYPES="feat|fix|hotfix|perf|refactor|style|docs|test|build|ci|chore|revert"
TITLE_PATTERN="^(${TYPES})(\([^()]+\))?!?: [^[:space:]].*$"

if printf "%s" "${PULL_REQUEST_TITLE}" | grep -qE "${TITLE_PATTERN}"; then
  echo "::notice::✓ Pull request title follows Conventional Commits"
  exit 0
fi

echo "::error::Pull request title must look like 'type: description' or 'type(scope): description'. Add ! before the colon for a breaking change, such as 'feat!: remove the old API'. Types: ${TYPES//|/, }"
exit 1
