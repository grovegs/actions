#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${PRESET:-}" ]; then
  echo "::error::PRESET environment variable is required"
  exit 1
fi

if [ -z "${CONFIGURATION:-}" ]; then
  echo "::error::CONFIGURATION environment variable is required"
  exit 1
fi

if [ -z "${FILENAME:-}" ]; then
  echo "::error::FILENAME environment variable is required"
  exit 1
fi

if [ -z "${ANDROID_KEYSTORE:-}" ]; then
  echo "::error::ANDROID_KEYSTORE is required for Android builds"
  exit 1
fi

if [ -z "${ANDROID_KEYSTORE_USER:-}" ]; then
  echo "::error::ANDROID_KEYSTORE_USER is required for Android builds"
  exit 1
fi

if [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
  echo "::error::ANDROID_KEYSTORE_PASSWORD is required for Android builds"
  exit 1
fi

ANDROID_FORMAT="${ANDROID_FORMAT:-apk}"
if [[ ! "${ANDROID_FORMAT}" =~ ^(apk|aab)$ ]]; then
  echo "::error::Invalid Android format: ${ANDROID_FORMAT}. Expected apk or aab"
  exit 1
fi

ANDROID_DIR="${HOME}/.android"
KEYSTORE_FILE="${RUNNER_TEMP}/android.keystore"
BUILDS_DIR="${HOME}/.builds/android"
OUTPUT_FILE="${BUILDS_DIR}/${FILENAME}.${ANDROID_FORMAT}"

export DefineSymbols="${DEFINE_SYMBOLS:-}"

cleanup() {
  echo "::notice::Cleaning up sensitive files..."
  rm -f "${KEYSTORE_FILE}" || true
}
trap cleanup EXIT

echo "::notice::Creating required directories..."
mkdir -p "${ANDROID_DIR}" || {
  echo "::error::Failed to create directory: ${ANDROID_DIR}"
  exit 1
}
mkdir -p "${BUILDS_DIR}" || {
  echo "::error::Failed to create directory: ${BUILDS_DIR}"
  exit 1
}

echo "::notice::Decoding Android keystore..."
echo -n "${ANDROID_KEYSTORE}" | base64 -d > "${KEYSTORE_FILE}" || {
  echo "::error::Failed to decode and save the Android keystore"
  exit 1
}

case "${CONFIGURATION}" in
  Debug)
    echo "::notice::Exporting debug build for Android..."
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${KEYSTORE_FILE}"
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${ANDROID_KEYSTORE_USER}"
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${ANDROID_KEYSTORE_PASSWORD}"
    if ! godot --nologo --path "${PROJECT_DIR}" --rendering-driver vulkan --export-debug "${PRESET}" "${OUTPUT_FILE}"; then
      echo "::error::Godot export debug failed"
      exit 1
    fi
    ;;
  Release)
    echo "::notice::Exporting release build for Android..."
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${KEYSTORE_FILE}"
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${ANDROID_KEYSTORE_USER}"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD}"
    if ! godot --nologo --path "${PROJECT_DIR}" --rendering-driver vulkan --export-release "${PRESET}" "${OUTPUT_FILE}"; then
      echo "::error::Godot export release failed"
      exit 1
    fi
    ;;
  *)
    echo "::error::Unsupported configuration: ${CONFIGURATION}"
    exit 1
    ;;
esac

if [ ! -f "${OUTPUT_FILE}" ]; then
  echo "::error::Build output not found: ${OUTPUT_FILE}"
  exit 1
fi

FILE_SIZE=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}" 2>/dev/null || echo "unknown")
echo "::notice::Build completed successfully: ${OUTPUT_FILE} (${FILE_SIZE} bytes)"
echo "file=${OUTPUT_FILE}" >> "${GITHUB_OUTPUT}"
