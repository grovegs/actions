#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_VERSION:-}" ]; then
  echo "::error::UNITY_VERSION environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

JAVA_HOME_VAR="${JAVA_HOME:-}"
ANDROID_HOME_VAR="${ANDROID_HOME:-}"
NDK_HOME_VAR="${NDK_HOME:-}"
UNITY_PATH_VAR="${UNITY_PATH:-}"

validate_paths() {
  echo "::notice::Validating environment paths"

  if [ -z "${JAVA_HOME_VAR}" ] || [ ! -d "${JAVA_HOME_VAR}" ]; then
    echo "::error::JAVA_HOME not set or path does not exist: ${JAVA_HOME_VAR}"
    echo "::error::Make sure to run setup-android action before setup-unity"
    exit 1
  fi

  if [ -z "${ANDROID_HOME_VAR}" ] || [ ! -d "${ANDROID_HOME_VAR}" ]; then
    echo "::error::ANDROID_HOME not set or path does not exist: ${ANDROID_HOME_VAR}"
    echo "::error::Make sure to run setup-android action before setup-unity"
    exit 1
  fi

  if [ -z "${NDK_HOME_VAR}" ] || [ ! -d "${NDK_HOME_VAR}" ]; then
    echo "::error::NDK_HOME not set or path does not exist: ${NDK_HOME_VAR}"
    echo "::error::Make sure to run setup-android action before setup-unity"
    exit 1
  fi

  echo "::notice::Environment paths validated successfully"
  echo "::notice::JAVA_HOME: ${JAVA_HOME_VAR}"
  echo "::notice::ANDROID_HOME: ${ANDROID_HOME_VAR}"
  echo "::notice::NDK_HOME: ${NDK_HOME_VAR}"
}

find_unity_android_player_path() {
  local android_player_path=""

  echo "::notice::Locating Unity Android Player path" >&2

  if [ -n "${UNITY_PATH_VAR}" ] && [ -d "${UNITY_PATH_VAR}" ]; then
    echo "::notice::Using UNITY_PATH from environment: ${UNITY_PATH_VAR}" >&2

    case "${RUNNER_OS}" in
      "macOS")
        android_player_path="${UNITY_PATH_VAR}/PlaybackEngines/AndroidPlayer"
        ;;
      "Linux")
        android_player_path="${UNITY_PATH_VAR}/Editor/Data/PlaybackEngines/AndroidPlayer"
        ;;
    esac
  else
    local unity_version="${UNITY_VERSION}"

    case "${RUNNER_OS}" in
      "macOS")
        local unity_path="/Applications/Unity/Editor/${unity_version}"
        if [ -d "${unity_path}" ]; then
          android_player_path="${unity_path}/PlaybackEngines/AndroidPlayer"
        fi
        ;;
      "Linux")
        local unity_dir="${HOME}/Unity/Editor/${unity_version}"
        if [ -d "${unity_dir}" ]; then
          android_player_path="${unity_dir}/Editor/Data/PlaybackEngines/AndroidPlayer"
        fi
        ;;
      *)
        echo "::error::Unsupported platform: ${RUNNER_OS}" >&2
        exit 1
        ;;
    esac
  fi

  if [ -n "${android_player_path}" ] && [ -d "${android_player_path}" ]; then
    echo "::notice::Found Unity Android Player path: ${android_player_path}" >&2
  else
    echo "::error::Unity Android Player path not found or does not exist" >&2
    android_player_path=""
  fi

  echo "${android_player_path}"
}

check_android_tools_configured() {
  local android_player_path="$1"

  local unity_jdk_dir="${android_player_path}/OpenJDK"
  local unity_sdk_dir="${android_player_path}/SDK"
  local unity_ndk_dir="${android_player_path}/NDK"

  if [ -d "${unity_jdk_dir}" ] && [ -d "${unity_sdk_dir}" ] && [ -d "${unity_ndk_dir}" ]; then
    echo "::notice::Android tools already configured for Unity"
    echo "::notice::  OpenJDK: ${unity_jdk_dir}"
    echo "::notice::  SDK: ${unity_sdk_dir}"
    echo "::notice::  NDK: ${unity_ndk_dir}"
    return 0
  fi

  return 1
}

create_directory_references() {
  local android_player_path="$1"

  echo "::notice::Creating Unity Android Player directory structure"
  mkdir -p "${android_player_path}"

  local unity_jdk_dir="${android_player_path}/OpenJDK"
  local unity_sdk_dir="${android_player_path}/SDK"
  local unity_ndk_dir="${android_player_path}/NDK"

  echo "::notice::Creating directory references for Unity Android tools"

  if [ -e "${unity_jdk_dir}" ] || [ -L "${unity_jdk_dir}" ]; then
    echo "::notice::Removing existing OpenJDK reference at ${unity_jdk_dir}"
    sudo rm -rf "${unity_jdk_dir}"
  fi

  if [ -e "${unity_sdk_dir}" ] || [ -L "${unity_sdk_dir}" ]; then
    echo "::notice::Removing existing SDK reference at ${unity_sdk_dir}"
    sudo rm -rf "${unity_sdk_dir}"
  fi

  if [ -e "${unity_ndk_dir}" ] || [ -L "${unity_ndk_dir}" ]; then
    echo "::notice::Removing existing NDK reference at ${unity_ndk_dir}"
    sudo rm -rf "${unity_ndk_dir}"
  fi

  echo "::notice::Linking OpenJDK: ${JAVA_HOME_VAR} -> ${unity_jdk_dir}"
  if ! sudo ln -sf "${JAVA_HOME_VAR}" "${unity_jdk_dir}"; then
    echo "::error::Failed to create OpenJDK reference"
    exit 1
  fi

  echo "::notice::Linking Android SDK: ${ANDROID_HOME_VAR} -> ${unity_sdk_dir}"
  if ! sudo ln -sf "${ANDROID_HOME_VAR}" "${unity_sdk_dir}"; then
    echo "::error::Failed to create SDK reference"
    exit 1
  fi

  echo "::notice::Linking Android NDK: ${NDK_HOME_VAR} -> ${unity_ndk_dir}"
  if ! sudo ln -sf "${NDK_HOME_VAR}" "${unity_ndk_dir}"; then
    echo "::error::Failed to create NDK reference"
    exit 1
  fi

  echo "::notice::Successfully created Android tools references"
}

verify_android_tools() {
  local android_player_path="$1"

  echo "::notice::Verifying Android tools configuration"

  local unity_sdk_dir="${android_player_path}/SDK"
  local unity_ndk_dir="${android_player_path}/NDK"
  local unity_jdk_dir="${android_player_path}/OpenJDK"

  if [ -f "${unity_jdk_dir}/bin/java" ]; then
    local java_version
    java_version=$("${unity_jdk_dir}/bin/java" -version 2>&1 | head -1)
    echo "::notice::✅ Java: ${java_version}"
  else
    echo "::warning::⚠ Java executable not found at ${unity_jdk_dir}/bin/java"
  fi

  if [ -f "${unity_sdk_dir}/platform-tools/adb" ]; then
    local adb_version
    adb_version=$("${unity_sdk_dir}/platform-tools/adb" version 2>&1 | head -1)
    echo "::notice::✅ ADB: ${adb_version}"
  else
    echo "::warning::⚠ ADB not found at ${unity_sdk_dir}/platform-tools/adb"
  fi

  if [ -f "${unity_ndk_dir}/ndk-build" ]; then
    local ndk_version="Unknown"
    if [ -f "${unity_ndk_dir}/source.properties" ]; then
      ndk_version=$(grep "Pkg.Revision" "${unity_ndk_dir}/source.properties" 2> /dev/null | cut -d'=' -f2 | tr -d ' ' || echo "Unknown")
    fi
    echo "::notice::✅ NDK: ${ndk_version}"
  else
    echo "::warning::⚠ NDK build tool not found at ${unity_ndk_dir}/ndk-build"
  fi

  echo "::notice::Android tools verification completed"
}

display_unity_paths() {
  local android_player_path="$1"

  echo "::notice::Unity Android Player Tools Setup Complete"
  echo "::notice::"
  echo "::notice::Unity will automatically detect Android tools at:"
  echo "::notice::  📦 Android Player: ${android_player_path}"
  echo "::notice::  ☕ OpenJDK:        ${android_player_path}/OpenJDK -> $(readlink "${android_player_path}/OpenJDK" 2> /dev/null || echo "Link not found")"
  echo "::notice::  📱 SDK:            ${android_player_path}/SDK -> $(readlink "${android_player_path}/SDK" 2> /dev/null || echo "Link not found")"
  echo "::notice::  🔧 NDK:            ${android_player_path}/NDK -> $(readlink "${android_player_path}/NDK" 2> /dev/null || echo "Link not found")"
  echo "::notice::"
  echo "::notice::Environment variables:"
  echo "::notice::  JAVA_HOME: ${JAVA_HOME:-}"
  echo "::notice::  ANDROID_HOME: ${ANDROID_HOME:-}"
  echo "::notice::  NDK_HOME: ${NDK_HOME:-}"
  echo "::notice::  UNITY_PATH: ${UNITY_PATH:-}"
}

main() {
  echo "::notice::Starting Android tools configuration for Unity ${UNITY_VERSION}"
  echo "::notice::Platform: ${RUNNER_OS}"

  validate_paths

  ANDROID_PLAYER_PATH=$(find_unity_android_player_path)

  if [ -z "${ANDROID_PLAYER_PATH}" ]; then
    echo "::error::Failed to locate Unity Android Player path"
    exit 1
  fi

  if check_android_tools_configured "${ANDROID_PLAYER_PATH}"; then
    echo "::notice::✅ Android tools already configured, skipping"
    display_unity_paths "${ANDROID_PLAYER_PATH}"
    exit 0
  fi

  create_directory_references "${ANDROID_PLAYER_PATH}"

  verify_android_tools "${ANDROID_PLAYER_PATH}"

  display_unity_paths "${ANDROID_PLAYER_PATH}"

  echo "::notice::✅ Android tools configuration completed successfully"
}

main
