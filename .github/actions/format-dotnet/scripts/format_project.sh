#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "::error::Project directory '${PROJECT_DIR}' does not exist"
  exit 1
fi

PROJECT_NAME=$(basename "${PROJECT_DIR}")
SOLUTION_FILE="${PROJECT_DIR}/${PROJECT_NAME}.sln"
PROJECT_FILE="${PROJECT_DIR}/${PROJECT_NAME}.csproj"

if [ -f "${SOLUTION_FILE}" ]; then
  TARGET_FILE="${SOLUTION_FILE}"
  FILE_TYPE="solution"
elif [ -f "${PROJECT_FILE}" ]; then
  TARGET_FILE="${PROJECT_FILE}"
  FILE_TYPE="project"
else
  echo "::error::Neither solution file '${SOLUTION_FILE}' nor project file '${PROJECT_FILE}' exists"
  exit 1
fi

echo "::notice::Formatting ${FILE_TYPE}: ${TARGET_FILE}"

if ! dotnet format --verify-no-changes "${TARGET_FILE}"; then
  echo "::warning::Code formatting issues found in ${TARGET_FILE}"
  exit 1
fi

echo "::notice::${FILE_TYPE^} formatting verified successfully"
