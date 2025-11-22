#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${VERSION:-}" ]; then
  echo "::error::VERSION environment variable is required"
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

if [ -z "${UNITY_EMAIL:-}" ]; then
  echo "::error::UNITY_EMAIL environment variable is required"
  exit 1
fi

if [ -z "${UNITY_PASSWORD:-}" ]; then
  echo "::error::UNITY_PASSWORD environment variable is required"
  exit 1
fi

if [ -z "${UNITY_LICENSE_KEY:-}" ]; then
  echo "::error::UNITY_LICENSE_KEY environment variable is required"
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

UNITY_CMD="${UNITY_EXECUTABLE:-unity}"

if [[ "${PROJECT_DIR}" != /* ]]; then
  PROJECT_DIR="$(cd "${PROJECT_DIR}" 2>/dev/null && pwd)" || {
    echo "::error::Project directory not found or inaccessible: ${PROJECT_DIR}"
    exit 1
  }
fi

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "::error::Project directory not found: ${PROJECT_DIR}"
  exit 1
fi

if [ ! -d "${PROJECT_DIR}/Assets" ]; then
  echo "::error::Not a valid Unity project (missing Assets folder): ${PROJECT_DIR}"
  exit 1
fi

if [ ! -d "${PROJECT_DIR}/ProjectSettings" ]; then
  echo "::error::Not a valid Unity project (missing ProjectSettings folder): ${PROJECT_DIR}"
  exit 1
fi

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Invalid version format: ${VERSION}. Expected x.y.z"
  exit 1
fi

ANDROID_FORMAT="${ANDROID_FORMAT:-apk}"
if [[ ! "${ANDROID_FORMAT}" =~ ^(apk|aab)$ ]]; then
  echo "::error::Invalid Android format: ${ANDROID_FORMAT}. Expected apk or aab"
  exit 1
fi

PLATFORM_BUILDS_DIR="${HOME}/.builds/android"
KEYSTORE_FILE="${RUNNER_TEMP}/android.keystore"
OUTPUT_FILE="${PLATFORM_BUILDS_DIR}/${FILENAME}.${ANDROID_FORMAT}"

cleanup() {
  echo "::notice::Cleaning up sensitive files..."
  rm -f "${KEYSTORE_FILE}" || true
}
trap cleanup EXIT

echo "::notice::Creating build directory..."
mkdir -p "${PLATFORM_BUILDS_DIR}" || {
  echo "::error::Failed to create directory: ${PLATFORM_BUILDS_DIR}"
  exit 1
}

echo "::notice::Decoding Android keystore..."
echo -n "${ANDROID_KEYSTORE}" | base64 -d > "${KEYSTORE_FILE}" || {
  echo "::error::Failed to decode Android keystore"
  exit 1
}
chmod 600 "${KEYSTORE_FILE}"

echo "::notice::Checking Android build requirements..."
if [ ! -f "${PROJECT_DIR}/ProjectSettings/ProjectSettings.asset" ]; then
  echo "::warning::ProjectSettings.asset not found - this might not be a valid Unity project"
fi

if [ -d "${PROJECT_DIR}/ProjectSettings" ]; then
  echo "::debug::ProjectSettings directory contents:"
  ls -la "${PROJECT_DIR}/ProjectSettings/" || true
fi

{
  echo "::notice::Build configuration:"
  echo "::notice::  Project: ${PROJECT_DIR}"
  echo "::notice::  Version: ${VERSION}"
  echo "::notice::  Configuration: ${CONFIGURATION}"
  echo "::notice::  Format: ${ANDROID_FORMAT}"
  echo "::notice::  Output: ${OUTPUT_FILE}"
  echo "::notice::  Profile: ${PROFILE_NAME:-default}"
  echo "::notice::  Unity: ${UNITY_CMD}"
} >&2

if [ -n "${BUILD_METHOD:-}" ]; then
  BUILD_METHOD_ARGS=("-executeMethod" "${BUILD_METHOD}")
  echo "::notice::Using custom build method: ${BUILD_METHOD}"
else
  BUILD_SCRIPT_DEST="${PROJECT_DIR}/Assets/Editor/BuildAndroid.cs"
  mkdir -p "${PROJECT_DIR}/Assets/Editor"

  if [ -f "${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs" ]; then
    cp "${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs" "${BUILD_SCRIPT_DEST}" || {
      echo "::error::Failed to copy build script"
      exit 1
    }
    echo "::notice::Copied BuildAndroid.cs to ${BUILD_SCRIPT_DEST}"
  else
    echo "::error::Build script not found: ${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs"
    exit 1
  fi

  BUILD_METHOD_ARGS=("-executeMethod" "BuildAndroid.Build")
  echo "::notice::Using default build method: BuildAndroid.Build"
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")" || {
  echo "::error::Failed to create output directory: $(dirname "${OUTPUT_FILE}")"
  exit 1
}

declare -a BUILD_ARGS
BUILD_ARGS=(
  -batchmode
  -nographics
  -quit
  -username "${UNITY_EMAIL}"
  -password "${UNITY_PASSWORD}"
  -serial "${UNITY_LICENSE_KEY}"
  -projectPath "${PROJECT_DIR}"
  -logFile -
  -buildTarget Android
)

BUILD_ARGS+=("${BUILD_METHOD_ARGS[@]}")
BUILD_ARGS+=(
  -outputPath "${OUTPUT_FILE}"
  -versionName "${VERSION}"
  -buildConfig "${CONFIGURATION}"
  -buildFormat "${ANDROID_FORMAT}"
  -profileName "${PROFILE_NAME:-Android}"
  -keystorePath "${KEYSTORE_FILE}"
  -keystorePass "${ANDROID_KEYSTORE_PASSWORD}"
  -keyaliasName "${ANDROID_KEYSTORE_USER}"
  -keyaliasPass "${ANDROID_KEYSTORE_PASSWORD}"
)

echo "::notice::Unity command line:"
printf '%s ' "${BUILD_ARGS[@]}"
echo ""

echo "::notice::Starting Unity build..."
if ! "${UNITY_CMD}" "${BUILD_ARGS[@]}" 2>&1; then
  echo "::error::Unity build failed for Android"
  echo "::error::Check the Unity log output above for specific error details"

  echo "::debug::Project directory contents:"
  ls -la "${PROJECT_DIR}" || echo "::debug::Cannot list project directory"

  echo "::debug::Build directory contents:"
  ls -la "${PLATFORM_BUILDS_DIR}" || echo "::debug::Cannot list build directory"

  echo "::debug::Unity version:"
  "${UNITY_CMD}" -version 2>/dev/null || echo "::debug::Cannot get Unity version"

  exit 1
fi

if [ ! -f "${OUTPUT_FILE}" ]; then
  echo "::error::Build output not found: ${OUTPUT_FILE}"
  echo "::debug::Contents of build directory:"
  ls -la "${PLATFORM_BUILDS_DIR}" || echo "::debug::Cannot list build directory"
  exit 1
fi

FILE_SIZE=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}" 2>/dev/null || echo "unknown")
echo "::notice::Build completed successfully: ${OUTPUT_FILE} (${FILE_SIZE} bytes)"
echo "file=${OUTPUT_FILE}" >> "${GITHUB_OUTPUT}"
