#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if ! command -v dotnet > /dev/null 2>&1; then
  echo "::error::dotnet is not installed or not in PATH"
  exit 1
fi

if ! command -v godot > /dev/null 2>&1; then
  echo "::error::godot is not installed or not in PATH"
  exit 1
fi

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "::error::Project directory does not exist: ${PROJECT_DIR}"
  exit 1
fi

if [ "${PROJECT_DIR}" = "." ]; then
  PROJECT_NAME="$(basename "$(pwd)")"
else
  PROJECT_NAME="$(basename "${PROJECT_DIR}")"
fi

CSPROJ_FILE="${PROJECT_DIR}/${PROJECT_NAME}.csproj"

if [ ! -f "${CSPROJ_FILE}" ]; then
  echo "::error::C# project file not found: ${CSPROJ_FILE}"
  exit 1
fi

PROJECT_GODOT_FILE="${PROJECT_DIR}/project.godot"

if [ ! -f "${PROJECT_GODOT_FILE}" ]; then
  echo "::error::Godot project file not found: ${PROJECT_GODOT_FILE}"
  exit 1
fi

echo "::notice::Testing Godot project: ${PROJECT_DIR}"

echo "::notice::Building C# project: ${CSPROJ_FILE}"

set +e
DOTNET_OUTPUT=$(dotnet build "${CSPROJ_FILE}" 2>&1)
DOTNET_EXIT_CODE=$?
set -e

DOTNET_ERROR_COUNT=$(echo "${DOTNET_OUTPUT}" | grep -c "error " || true)
DOTNET_WARNING_COUNT=$(echo "${DOTNET_OUTPUT}" | grep -c "warning " || true)

if [ "${DOTNET_ERROR_COUNT}" -gt 0 ]; then
  echo "::error::C# build failed with ${DOTNET_ERROR_COUNT} error(s)"
  echo "${DOTNET_OUTPUT}" | grep "error " | sort -u | while IFS= read -r line; do
    echo "::error::${line}"
  done
fi

if [ "${DOTNET_WARNING_COUNT}" -gt 0 ]; then
  echo "::warning::C# build completed with ${DOTNET_WARNING_COUNT} warning(s)"
  echo "${DOTNET_OUTPUT}" | grep "warning " | sort -u | while IFS= read -r line; do
    echo "::warning::${line}"
  done
fi

if [ "${DOTNET_EXIT_CODE}" -eq 0 ]; then
  echo "::notice::✓ C# build completed successfully"
fi

echo "::notice::Importing Godot project assets"

set +e
GODOT_OUTPUT=$(godot --path "${PROJECT_DIR}" --headless --quiet --import 2>&1)
GODOT_EXIT_CODE=$?
set -e

GODOT_ERROR_COUNT=$(echo "${GODOT_OUTPUT}" | grep -c "ERROR:" || true)
GODOT_WARNING_COUNT=$(echo "${GODOT_OUTPUT}" | grep -c "WARNING:" || true)

if [ "${GODOT_ERROR_COUNT}" -gt 0 ]; then
  echo "::error::Godot import failed with ${GODOT_ERROR_COUNT} error(s)"
  echo "${GODOT_OUTPUT}" | grep "ERROR:" | sort -u | while IFS= read -r line; do
    echo "::error::${line}"
  done
fi

if [ "${GODOT_WARNING_COUNT}" -gt 0 ]; then
  echo "::warning::Godot import completed with ${GODOT_WARNING_COUNT} warning(s)"
  echo "${GODOT_OUTPUT}" | grep "WARNING:" | sort -u | while IFS= read -r line; do
    echo "::warning::${line}"
  done
fi

if [ "${GODOT_EXIT_CODE}" -eq 0 ]; then
  echo "::notice::✓ Godot import completed successfully"
fi

TOTAL_ERRORS=$((DOTNET_ERROR_COUNT + GODOT_ERROR_COUNT))
TOTAL_WARNINGS=$((DOTNET_WARNING_COUNT + GODOT_WARNING_COUNT))

echo ""
echo "::notice::=========================================="
echo "::notice::Test Summary"
echo "::notice::=========================================="
echo "::notice::C# Build:     ${DOTNET_ERROR_COUNT} error(s), ${DOTNET_WARNING_COUNT} warning(s)"
echo "::notice::Godot Import: ${GODOT_ERROR_COUNT} error(s), ${GODOT_WARNING_COUNT} warning(s)"
echo "::notice::------------------------------------------"
echo "::notice::Total:        ${TOTAL_ERRORS} error(s), ${TOTAL_WARNINGS} warning(s)"
echo "::notice::=========================================="

if [ "${TOTAL_ERRORS}" -gt 0 ]; then
  echo "::error::Tests failed with ${TOTAL_ERRORS} total error(s)"
  exit 1
fi

echo "::notice::✓ All tests passed"
