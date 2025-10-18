#!/usr/bin/env bash
set -euo pipefail

if [ -z "${TARGET_PLATFORMS:-}" ]; then
  echo "::error::TARGET_PLATFORMS environment variable is required"
  exit 1
fi

echo "::notice::Processing platform templates"

TEMPLATES_ID=$(echo "${TARGET_PLATFORMS}" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -d ' ' \
  | tr ',' '\n' \
  | sort \
  | awk '{ printf "%s", substr($0, 1, 1) }')

if [ -z "${TEMPLATES_ID}" ]; then
  echo "::warning::No templates ID generated"
else
  echo "::notice::Templates ID: ${TEMPLATES_ID}"
fi

{
  echo "templates-id=${TEMPLATES_ID}"
} >> "${GITHUB_OUTPUT}"
