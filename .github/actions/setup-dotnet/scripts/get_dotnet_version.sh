#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GLOBAL_JSON_FILE:-}" ]; then
  echo "::error::GLOBAL_JSON_FILE environment variable is required"
  exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "::error::jq is not installed or not in PATH"
  exit 1
fi

if [ ! -f "${GLOBAL_JSON_FILE}" ]; then
  echo "::error::File not found: ${GLOBAL_JSON_FILE}"
  exit 1
fi

if [ ! -r "${GLOBAL_JSON_FILE}" ]; then
  echo "::error::Cannot read file: ${GLOBAL_JSON_FILE}"
  exit 1
fi

echo "::notice::Reading .NET SDK version from ${GLOBAL_JSON_FILE}"

DOTNET_VERSION=$(jq -r '.sdk.version // empty' "${GLOBAL_JSON_FILE}")

if [ -z "${DOTNET_VERSION}" ]; then
  echo "::error::Failed to find .NET SDK version in ${GLOBAL_JSON_FILE}"
  echo "::error::Expected format: { \"sdk\": { \"version\": \"8.0.100\" } }"
  exit 1
fi

if ! echo "${DOTNET_VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$'; then
  echo "::error::Invalid .NET SDK version format: ${DOTNET_VERSION}"
  echo "::error::Expected format: X.Y.Z or X.Y.Z-preview.N"
  exit 1
fi

echo "::notice::Found .NET SDK version: ${DOTNET_VERSION}"

{
  echo "dotnet-version=${DOTNET_VERSION}"
} >> "${GITHUB_OUTPUT}"
