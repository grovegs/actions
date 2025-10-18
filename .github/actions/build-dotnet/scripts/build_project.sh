#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${CONFIGURATION:-}" ]; then
  echo "::error::CONFIGURATION environment variable is required"
  exit 1
fi

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "::error::Project directory '${PROJECT_DIR}' does not exist"
  exit 1
fi

if [[ "${PROJECT_DIR}" == "." ]]; then
  FILE_NAME="$(basename "$(pwd)")"
else
  FILE_NAME="$(basename "${PROJECT_DIR}")"
fi

PROJECT_FILE="${PROJECT_DIR}/${FILE_NAME}.csproj"

if [ ! -f "${PROJECT_FILE}" ]; then
  echo "::error::Project file '${PROJECT_FILE}' does not exist"
  exit 1
fi

BUILD_ARGS=(
  --nologo
  --configuration "${CONFIGURATION}"
  "${PROJECT_FILE}"
)

if [ -n "${VERSION:-}" ]; then
  BUILD_ARGS+=("-p:Version=${VERSION}")
fi

if [ -n "${DEFINE_SYMBOLS:-}" ]; then
  BUILD_ARGS+=("-p:DefineSymbols=${DEFINE_SYMBOLS}")
fi

{
  echo "::group::Building ${PROJECT_FILE}"
  echo "::notice::Configuration: ${CONFIGURATION}"
  if [ -n "${VERSION:-}" ]; then
    echo "::notice::Version: ${VERSION}"
  fi
  if [ -n "${DEFINE_SYMBOLS:-}" ]; then
    echo "::notice::Define Symbols: ${DEFINE_SYMBOLS}"
  fi
} >&2

if ! dotnet build "${BUILD_ARGS[@]}"; then
  echo "::endgroup::"
  echo "::error::Build failed"
  exit 1
fi

echo "::endgroup::"
echo "::notice::Build completed successfully"
