#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_PATH:-}" ]; then
  echo "::error::PROJECT_PATH environment variable is required"
  exit 1
fi

if [ -z "${BUILD_CONFIGURATION:-}" ]; then
  echo "::error::BUILD_CONFIGURATION environment variable is required"
  exit 1
fi

if ! command -v dotnet > /dev/null 2>&1; then
  echo "::error::dotnet is not installed or not in PATH"
  exit 1
fi

if [ ! -d "${PROJECT_PATH}" ]; then
  echo "::error::Project directory does not exist: ${PROJECT_PATH}"
  exit 1
fi

if [ "${PROJECT_PATH}" = "." ]; then
  PROJECT_NAME="$(basename "$(pwd)")"
else
  PROJECT_NAME="$(basename "${PROJECT_PATH}")"
fi

PROJECT_FILE="${PROJECT_PATH}/${PROJECT_NAME}.csproj"

if [ ! -f "${PROJECT_FILE}" ]; then
  echo "::error::Project file does not exist: ${PROJECT_FILE}"
  exit 1
fi

echo "::notice::Running tests for project: ${PROJECT_FILE}"
echo "  Configuration: ${BUILD_CONFIGURATION}"

if ! dotnet test \
  --nologo \
  --configuration "${BUILD_CONFIGURATION}" \
  "${PROJECT_FILE}"; then
  echo "::error::Tests failed for project: ${PROJECT_FILE}"
  exit 1
fi

echo "::notice::✓ All tests passed for project: ${PROJECT_FILE}"
