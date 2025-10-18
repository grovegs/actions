#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PACKAGE_FILE:-}" ]; then
  echo "::error::PACKAGE_FILE environment variable is required"
  exit 1
fi

if [ -z "${NUGET_API_KEY:-}" ]; then
  echo "::error::NUGET_API_KEY environment variable is required"
  exit 1
fi

if ! command -v dotnet > /dev/null 2>&1; then
  echo "::error::dotnet is not installed or not in PATH"
  exit 1
fi

if [ ! -f "${PACKAGE_FILE}" ]; then
  echo "::error::Package file '${PACKAGE_FILE}' does not exist"
  exit 1
fi

NUGET_SOURCE="${NUGET_SOURCE:-https://api.nuget.org/v3/index.json}"
SKIP_DUPLICATE="${SKIP_DUPLICATE:-true}"

echo "::notice::Publishing NuGet package: ${PACKAGE_FILE}"
echo "  Source: ${NUGET_SOURCE}"
echo "  Skip duplicate: ${SKIP_DUPLICATE}"

declare -a DOTNET_ARGS
DOTNET_ARGS=(
  "nuget"
  "push"
  "${PACKAGE_FILE}"
  "--api-key"
  "${NUGET_API_KEY}"
  "--source"
  "${NUGET_SOURCE}"
)

if [ "${SKIP_DUPLICATE}" = "true" ]; then
  DOTNET_ARGS+=("--skip-duplicate")
fi

echo "::notice::Executing NuGet push command"

if ! dotnet "${DOTNET_ARGS[@]}"; then
  echo "::error::Failed to publish NuGet package '${PACKAGE_FILE}'"
  exit 1
fi

echo "::notice::✓ Successfully published NuGet package: ${PACKAGE_FILE}"
