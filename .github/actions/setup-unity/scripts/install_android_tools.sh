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

JDK_PATH="${JAVA_HOME:-}"
SDK_PATH="${ANDROID_HOME:-}"
NDK_PATH="${NDK_HOME:-}"

validate_paths() {
  echo "::notice::Validating environment paths"

  if [ -z "${JDK_PATH}" ] || [ ! -d "${JDK_PATH}" ]; then
    echo "::error::JAVA_HOME not set or path does not exist: ${JDK_PATH}"
    echo "::error::Make sure to run setup-android action before setup-unity"
    exit 1
  fi

  if [ -z "${SDK_PATH}" ] || [ ! -d "${SDK_PATH}" ]; then
    echo "::error::ANDROID_HOME not set or path does not exist: ${SDK_PATH}"
    echo "::error::Make sure to run setup-android action before setup-unity"
    exit 1
  fi

  if [ -z "${NDK_PATH}" ] || [ ! -d "${NDK_PATH}" ]; then
    echo "::error::NDK_HOME not set or path does not exist: ${NDK_PATH}"
    echo "::error::Make sure to run setup-android action before setup-unity"
    exit 1
  fi

  echo "::notice::Environment paths validated successfully"
  echo "::notice::JDK: ${JDK_PATH}"
  echo "::notice::SDK: ${SDK_PATH}"
  echo "::notice::NDK: ${NDK_PATH}"
}

find_unity_android_path() {
  local unity_version="$1"
  local android_player_path=""

  echo "::notice::Locating Unity Android Player path for version ${unity_version}" >&2

  case "${RUNNER_OS}" in
    "macOS")
      local unity_path="/Applications/Unity/Unity-${unity_version}"

      if [ -d "${unity_path}" ]; then
        android_player_path="${unity_path}/PlaybackEngines/AndroidPlayer"
        echo "::notice::Found Unity Android Player path: ${android_player_path}" >&2
      else
        echo "::error::Unity installation not found at: ${unity_path}" >&2
      fi
      ;;
    "Linux")
      local unity_dir="${HOME}/Unity-${unity_version}"
      if [ -d "${unity_dir}" ]; then
        android_player_path="${unity_dir}/Editor/Data/PlaybackEngines/AndroidPlayer"
        echo "::notice::Found Unity Android Player path: ${android_player_path}" >&2
      else
        echo "::error::Unity installation not found at: ${unity_dir}" >&2
      fi
      ;;
    *)
      echo "::error::Unsupported platform: ${RUNNER_OS}" >&2
      exit 1
      ;;
  esac

  echo "${android_player_path}"
}

link_directory() {
  local source_path="$1"
  local target_path="$2"
  local description="$3"

  echo "::notice::Linking ${description}"
  echo "::notice::Source: ${source_path}"
  echo "::notice::Target: ${target_path}"

  if [ -e "${target_path}" ] || [ -L "${target_path}" ]; then
    echo "::notice::Removing existing ${description} at ${target_path}"
    sudo rm -rf "${target_path}"
  fi

  local parent_dir
  parent_dir=$(dirname "${target_path}")
  sudo mkdir -p "${parent_dir}"

  if sudo ln -sf "${source_path}" "${target_path}"; then
    echo "::notice::Successfully linked ${description}"
  else
    echo "::error::Failed to create symbolic link for ${description}"
    exit 1
  fi
}

verify_android_tools() {
  local android_player_path="$1"

  echo "::notice::Verifying Android tools installation"

  local unity_sdk_dir="${android_player_path}/SDK"
  local unity_ndk_dir="${android_player_path}/NDK"
  local unity_jdk_dir="${android_player_path}/OpenJDK"

  if [ -f "${unity_jdk_dir}/bin/java" ]; then
    local java_version
    java_version=$("${unity_jdk_dir}/bin/java" -version 2>&1 | head -1)
    echo "::notice::✅ Java: ${java_version}"
  else
    echo "::warning::❌ Java executable not found at ${unity_jdk_dir}/bin/java"
  fi

  if [ -f "${unity_sdk_dir}/platform-tools/adb" ]; then
    local adb_version
    adb_version=$("${unity_sdk_dir}/platform-tools/adb" version 2>&1 | head -1)
    echo "::notice::✅ ADB: ${adb_version}"
  else
    echo "::warning::❌ ADB not found at ${unity_sdk_dir}/platform-tools/adb"
  fi

  if [ -f "${unity_ndk_dir}/ndk-build" ]; then
    local ndk_version="Unknown"
    if [ -f "${unity_ndk_dir}/source.properties" ]; then
      ndk_version=$(grep "Pkg.Revision" "${unity_ndk_dir}/source.properties" 2> /dev/null | cut -d'=' -f2 | tr -d ' ' || echo "Unknown")
    fi
    echo "::notice::✅ NDK: ${ndk_version}"
  else
    echo "::warning::❌ NDK build tool not found at ${unity_ndk_dir}/ndk-build"
  fi

  echo "::notice::Android tools verification completed"
}

display_unity_paths() {
  local android_player_path="$1"

  echo "::notice::Unity Android Player Tools Setup Complete"
  echo "::notice::"
  echo "::notice::Unity will automatically detect Android tools via symlinks at:"
  echo "::notice::  📁 Android Player: ${android_player_path}"
  echo "::notice::  ☕ JDK:           ${android_player_path}/OpenJDK -> $(readlink "${android_player_path}/OpenJDK" 2> /dev/null || echo "Link not found")"
  echo "::notice::  📱 SDK:           ${android_player_path}/SDK -> $(readlink "${android_player_path}/SDK" 2> /dev/null || echo "Link not found")"
  echo "::notice::  🔧 NDK:           ${android_player_path}/NDK -> $(readlink "${android_player_path}/NDK" 2> /dev/null || echo "Link not found")"
}

main() {
  echo "::notice::Starting Android tools symlink setup for Unity ${UNITY_VERSION}"
  echo "::notice::Platform: ${RUNNER_OS}"

  validate_paths

  ANDROID_PLAYER_PATH=$(find_unity_android_path "${UNITY_VERSION}")

  if [ -z "${ANDROID_PLAYER_PATH}" ]; then
    echo "::error::Failed to locate Unity Android Player path"
    exit 1
  fi

  echo "::notice::Creating Android Player directory structure"
  mkdir -p "${ANDROID_PLAYER_PATH}"

  UNITY_SDK_DIR="${ANDROID_PLAYER_PATH}/SDK"
  UNITY_NDK_DIR="${ANDROID_PLAYER_PATH}/NDK"
  UNITY_JDK_DIR="${ANDROID_PLAYER_PATH}/OpenJDK"

  link_directory "${JDK_PATH}" "${UNITY_JDK_DIR}" "OpenJDK"
  link_directory "${SDK_PATH}" "${UNITY_SDK_DIR}" "Android SDK"
  link_directory "${NDK_PATH}" "${UNITY_NDK_DIR}" "Android NDK"

  verify_android_tools "${ANDROID_PLAYER_PATH}"

  display_unity_paths "${ANDROID_PLAYER_PATH}"

  echo "::notice::✓ Android tools symlink setup completed successfully"
}

main
