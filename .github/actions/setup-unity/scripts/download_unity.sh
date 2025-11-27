#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_VERSION:-}" ]; then
  echo "::error::UNITY_VERSION environment variable is required"
  exit 1
fi

if [ -z "${UNITY_CHANGESET:-}" ]; then
  echo "::error::UNITY_CHANGESET environment variable is required"
  exit 1
fi

if [ -z "${DOWNLOAD_DIR:-}" ]; then
  echo "::error::DOWNLOAD_DIR environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

if ! command -v curl > /dev/null 2>&1; then
  echo "::error::curl is not installed or not in PATH"
  exit 1
fi

UNITY_MODULES="${UNITY_MODULES:-}"

echo "::notice::Creating download directory: ${DOWNLOAD_DIR}"
if ! mkdir -p "${DOWNLOAD_DIR}"; then
  echo "::error::Failed to create download directory: ${DOWNLOAD_DIR}"
  exit 1
fi

download_file() {
  local url="$1"
  local file_path="$2"
  local filename
  filename=$(basename "${file_path}")

  if [ -f "${file_path}" ]; then
    local file_size
    file_size=$(stat -f%z "${file_path}" 2> /dev/null || stat -c%s "${file_path}" 2> /dev/null || echo "0")

    if [ "${file_size}" -ge 1048576 ]; then
      local size_mb=$((file_size / 1048576))
      echo "::notice::✅ File already exists, skipping download: ${filename} (${size_mb} MB)"
      return 0
    else
      echo "::warning::Existing file appears corrupted (${file_size} bytes), re-downloading: ${filename}"
      rm -f "${file_path}"
    fi
  fi

  echo "::notice::Downloading ${filename}"

  local temp_file
  temp_file="${file_path}.tmp"

  local max_retries=3
  local retry_count=0

  while [ "${retry_count}" -lt "${max_retries}" ]; do
    if curl --fail --location --silent --show-error --output "${temp_file}" "${url}"; then
      echo "::notice::Successfully downloaded ${filename}"
      mv "${temp_file}" "${file_path}"
      return 0
    else
      local curl_exit_code=$?
      retry_count=$((retry_count + 1))

      if [ "${curl_exit_code}" -eq 22 ]; then
        echo "::warning::Module ${filename} is not available for this platform (HTTP 404)"
        rm -f "${temp_file}" 2> /dev/null || true
        return 1
      fi

      echo "::warning::Download attempt ${retry_count} failed for ${filename}"

      if [ "${retry_count}" -lt "${max_retries}" ]; then
        echo "::notice::Retrying in 5 seconds"
        sleep 5
      fi
    fi
  done

  echo "::error::Failed to download ${filename} after ${max_retries} attempts"
  echo "::error::URL: ${url}"
  rm -f "${temp_file}" 2> /dev/null || true
  return 1
}

validate_download() {
  local file_path="$1"
  local filename
  filename=$(basename "${file_path}")

  if [ ! -f "${file_path}" ]; then
    echo "::error::Downloaded file not found: ${file_path}"
    exit 1
  fi

  local file_size
  file_size=$(stat -f%z "${file_path}" 2> /dev/null || stat -c%s "${file_path}" 2> /dev/null || echo "0")

  if [ "${file_size}" -lt 1048576 ]; then
    echo "::error::Downloaded file appears to be corrupted or incomplete: ${filename} (${file_size} bytes)"
    exit 1
  fi

  echo "::notice::Download validated: ${filename} (${file_size} bytes)"
}

get_platform_info() {
  case "${RUNNER_OS}" in
    "macOS")
      echo "macOS"
      ;;
    "Linux")
      echo "Linux"
      ;;
    *)
      echo "::error::Unsupported platform: ${RUNNER_OS}"
      exit 1
      ;;
  esac
}

get_editor_info() {
  local platform="$1"

  case "${platform}" in
    "macOS")
      echo "MacEditorInstallerArm64|Unity-${UNITY_VERSION}.pkg"
      ;;
    "Linux")
      echo "LinuxEditorInstaller|Unity.tar.xz"
      ;;
  esac
}

get_module_info() {
  local platform="$1"
  local module="$2"

  case "${platform}" in
    "macOS")
      case "${module}" in
        "android")
          echo "MacEditorTargetInstaller|UnitySetup-Android-Support-for-Editor-${UNITY_VERSION}.pkg"
          ;;
        "ios")
          echo "MacEditorTargetInstaller|UnitySetup-iOS-Support-for-Editor-${UNITY_VERSION}.pkg"
          ;;
        *)
          echo ""
          ;;
      esac
      ;;
    "Linux")
      case "${module}" in
        "android")
          echo "LinuxEditorTargetInstaller|UnitySetup-Android-Support-for-Editor-${UNITY_VERSION}.tar.xz"
          ;;
        *)
          echo ""
          ;;
      esac
      ;;
  esac
}

echo "::notice::Starting Unity ${UNITY_VERSION} download for ${RUNNER_OS}"
echo "::notice::Changeset: ${UNITY_CHANGESET}"
echo "::notice::Modules: ${UNITY_MODULES}"

PLATFORM=$(get_platform_info)
BASE_URL="https://download.unity3d.com/download_unity/${UNITY_CHANGESET}"

EDITOR_INFO=$(get_editor_info "${PLATFORM}")
EDITOR_PATH_SEGMENT=$(echo "${EDITOR_INFO}" | cut -d'|' -f1)
EDITOR_FILENAME=$(echo "${EDITOR_INFO}" | cut -d'|' -f2)
EDITOR_URL="${BASE_URL}/${EDITOR_PATH_SEGMENT}/${EDITOR_FILENAME}"
EDITOR_FILE_PATH="${DOWNLOAD_DIR}/${EDITOR_FILENAME}"

download_file "${EDITOR_URL}" "${EDITOR_FILE_PATH}"
validate_download "${EDITOR_FILE_PATH}"

if [ -n "${UNITY_MODULES}" ]; then
  echo "::notice::Processing modules: ${UNITY_MODULES}"

  IFS=',' read -ra MODULE_ARRAY <<< "${UNITY_MODULES}"

  for module in "${MODULE_ARRAY[@]}"; do
    MODULE_TRIMMED=$(echo "${module}" | xargs)

    if [ -z "${MODULE_TRIMMED}" ]; then
      continue
    fi

    echo "::notice::Processing module: ${MODULE_TRIMMED}"

    MODULE_INFO=$(get_module_info "${PLATFORM}" "${MODULE_TRIMMED}")

    if [ -z "${MODULE_INFO}" ]; then
      echo "::warning::Module '${MODULE_TRIMMED}' is not supported on ${PLATFORM}, skipping"
      continue
    fi

    MODULE_PATH_SEGMENT=$(echo "${MODULE_INFO}" | cut -d'|' -f1)
    MODULE_FILENAME=$(echo "${MODULE_INFO}" | cut -d'|' -f2)
    MODULE_URL="${BASE_URL}/${MODULE_PATH_SEGMENT}/${MODULE_FILENAME}"
    MODULE_FILE_PATH="${DOWNLOAD_DIR}/${MODULE_FILENAME}"

    if download_file "${MODULE_URL}" "${MODULE_FILE_PATH}"; then
      validate_download "${MODULE_FILE_PATH}"
    else
      echo "::warning::Skipping module '${MODULE_TRIMMED}' as it is not available for ${PLATFORM}"
    fi
  done
else
  echo "::notice::No modules specified for download"
fi

echo "::notice::✓ Unity download completed successfully"
