#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${TEMPLATES_DIR:-}" ]; then
  echo "::error::TEMPLATES_DIR environment variable is required"
  exit 1
fi

if [ -z "${GODOT_VERSION:-}" ]; then
  echo "::error::GODOT_VERSION environment variable is required"
  exit 1
fi

if [ -z "${GODOT_STAGE:-}" ]; then
  echo "::error::GODOT_STAGE environment variable is required"
  exit 1
fi

echo "::notice::Installing Android template for Godot ${GODOT_VERSION}-${GODOT_STAGE}..."

TEMPLATE_DIR="${TEMPLATES_DIR}/${GODOT_VERSION}.${GODOT_STAGE}.mono"
ANDROID_SOURCE="${TEMPLATE_DIR}/android_source.zip"
ANDROID_DIR="${PROJECT_DIR}/android"
BUILD_DIR="${ANDROID_DIR}/build"

if [ ! -f "${ANDROID_SOURCE}" ]; then
  echo "::error::Android source not found: ${ANDROID_SOURCE}"
  exit 1
fi

if ! mkdir -p "${BUILD_DIR}"; then
  echo "::error::Failed to create directory at ${BUILD_DIR}"
  exit 1
fi

if ! unzip -o "${ANDROID_SOURCE}" -d "${BUILD_DIR}"; then
  echo "::error::Extraction failed for ${ANDROID_SOURCE}"
  exit 1
fi

if ! cp "${TEMPLATE_DIR}/version.txt" "${ANDROID_DIR}/.build_version"; then
  echo "::error::Failed to copy version file to ${ANDROID_DIR}/.build_version"
  exit 1
fi

if ! touch "${BUILD_DIR}/.gdignore"; then
  echo "::error::Failed to create .gdignore file in ${BUILD_DIR}"
  exit 1
fi

echo "::notice::Android template installation completed successfully"
