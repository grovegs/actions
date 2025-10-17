#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GLOBAL_JSON_FILE:-}" ]; then
  echo "::error::GLOBAL_JSON_FILE environment variable is required"
  exit 1
fi

if [ ! -f "${GLOBAL_JSON_FILE}" ]; then
  echo "::error::File not found: ${GLOBAL_JSON_FILE}"
  exit 1
fi

FULL_VERSION=$(sed -n 's/.*"Godot\.NET\.Sdk": "\([^"]*\)".*/\1/p' "${GLOBAL_JSON_FILE}")

if [ -z "${FULL_VERSION}" ]; then
  echo "::error::Version not found in ${GLOBAL_JSON_FILE}"
  exit 1
fi

if [[ "${FULL_VERSION}" == *"-"* ]]; then
  VERSION="${FULL_VERSION%%-*}"
  STAGE="${FULL_VERSION#*-}"
  STAGE="${STAGE//./}"
else
  VERSION="${FULL_VERSION}"
  STAGE="stable"
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "${VERSION}"

if [ "${PATCH}" = "0" ]; then
  VERSION="${MAJOR}.${MINOR}"
fi

{
  echo "::notice::Godot version is ${VERSION}"
  echo "::notice::Godot stage is ${STAGE}"
  echo "version=${VERSION}"
  echo "stage=${STAGE}"
} >> "${GITHUB_OUTPUT}"
