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

UNITY_PATH_VAR="${UNITY_PATH:-}"
JAVA_HOME_VAR="${JAVA_HOME:-}"
ANDROID_HOME_VAR="${ANDROID_HOME:-}"
NDK_HOME_VAR="${NDK_HOME:-}"

find_unity_android_player_path() {
  echo "::notice::Locating Unity Android Player path" >&2

  if [ -z "${UNITY_PATH_VAR}" ]; then
    echo "::error::UNITY_PATH environment variable is not set" >&2
    return 1
  fi

  if [ ! -d "${UNITY_PATH_VAR}" ]; then
    echo "::error::UNITY_PATH directory does not exist: ${UNITY_PATH_VAR}" >&2
    return 1
  fi

  local android_player_path="${UNITY_PATH_VAR}/PlaybackEngines/AndroidPlayer"

  if [ ! -d "${android_player_path}" ]; then
    echo "::error::Unity Android Player not found at: ${android_player_path}" >&2
    echo "::error::Make sure Unity Android module is installed" >&2
    return 1
  fi

  echo "::notice::Found Unity Android Player path: ${android_player_path}" >&2
  echo "${android_player_path}"
  return 0
}

configure_android_tools() {
  local android_player_path="$1"

  echo "::notice::Configuring Android tools for Unity"

  local unity_jdk="${android_player_path}/OpenJDK"
  local unity_sdk="${android_player_path}/SDK"
  local unity_ndk="${android_player_path}/NDK"

  local jdk_path=""
  local sdk_path=""
  local ndk_path=""

  if [ -d "${unity_jdk}" ] && [ -f "${unity_jdk}/bin/java" ]; then
    jdk_path="${unity_jdk}"
    echo "::notice::✅ Using Unity's bundled JDK: ${jdk_path}"
    if [ -x "${jdk_path}/bin/java" ]; then
      local java_version
      java_version=$("${jdk_path}/bin/java" -version 2>&1 | head -1 || echo "Unknown")
      echo "::notice::   Version: ${java_version}"
    fi
  elif [ -n "${JAVA_HOME_VAR}" ] && [ -d "${JAVA_HOME_VAR}" ] && [ -f "${JAVA_HOME_VAR}/bin/java" ]; then
    jdk_path="${JAVA_HOME_VAR}"
    echo "::notice::✅ Using external JDK: ${jdk_path}"
    echo "::notice::   Creating symlink for Unity"
    mkdir -p "${android_player_path}"
    ln -sf "${JAVA_HOME_VAR}" "${unity_jdk}"
  else
    echo "::error::❌ JDK not found"
    echo "::error::   Unity's bundled JDK not found at: ${unity_jdk}"
    echo "::error::   Checked for: ${unity_jdk}/bin/java"
    echo "::error::   External JAVA_HOME not set or invalid: ${JAVA_HOME_VAR}"
    echo "::error::   Either install Unity with JDK or run setup-android action first"
    exit 1
  fi

  if [ -d "${unity_sdk}" ] && [ -f "${unity_sdk}/platform-tools/adb" ]; then
    sdk_path="${unity_sdk}"
    echo "::notice::✅ Using Unity's bundled SDK: ${sdk_path}"
    if [ -x "${sdk_path}/platform-tools/adb" ]; then
      local adb_version
      adb_version=$("${sdk_path}/platform-tools/adb" version 2>&1 | head -1 || echo "Unknown")
      echo "::notice::   Version: ${adb_version}"
    fi
  elif [ -n "${ANDROID_HOME_VAR}" ] && [ -d "${ANDROID_HOME_VAR}" ] && [ -f "${ANDROID_HOME_VAR}/platform-tools/adb" ]; then
    sdk_path="${ANDROID_HOME_VAR}"
    echo "::notice::✅ Using external SDK: ${sdk_path}"
    echo "::notice::   Creating symlink for Unity"
    mkdir -p "${android_player_path}"
    ln -sf "${ANDROID_HOME_VAR}" "${unity_sdk}"
  else
    echo "::error::❌ Android SDK not found"
    echo "::error::   Unity's bundled SDK not found at: ${unity_sdk}"
    echo "::error::   Checked for: ${unity_sdk}/platform-tools/adb"
    echo "::error::   External ANDROID_HOME not set or invalid: ${ANDROID_HOME_VAR}"
    echo "::error::   Either install Unity with SDK or run setup-android action first"
    exit 1
  fi

  if [ -d "${unity_ndk}" ]; then
    ndk_path="${unity_ndk}"
    echo "::notice::✅ Using Unity's bundled NDK: ${ndk_path}"
    if [ -f "${ndk_path}/source.properties" ]; then
      local ndk_version
      ndk_version=$(grep "Pkg.Revision" "${ndk_path}/source.properties" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "Unknown")
      echo "::notice::   Version: ${ndk_version}"
    fi
  elif [ -n "${NDK_HOME_VAR}" ] && [ -d "${NDK_HOME_VAR}" ]; then
    ndk_path="${NDK_HOME_VAR}"
    echo "::notice::✅ Using external NDK: ${ndk_path}"
    echo "::notice::   Creating symlink for Unity"
    mkdir -p "${android_player_path}"
    ln -sf "${NDK_HOME_VAR}" "${unity_ndk}"
  else
    echo "::error::❌ Android NDK not found"
    echo "::error::   Unity's bundled NDK not found at: ${unity_ndk}"
    echo "::error::   External NDK_HOME not set or invalid: ${NDK_HOME_VAR}"
    echo "::error::   Either install Unity with NDK or run setup-android action first"
    exit 1
  fi

  echo "::notice::"
  echo "::notice::════════════════════════════════════════════════════"
  echo "::notice::  Android Tools Configuration Complete"
  echo "::notice::════════════════════════════════════════════════════"
  echo "::notice::  ☕ JDK: ${jdk_path}"
  echo "::notice::  📱 SDK: ${sdk_path}"
  echo "::notice::  🔧 NDK: ${ndk_path}"
  echo "::notice::════════════════════════════════════════════════════"
  echo "::notice::"
}

main() {
  echo "::notice::Starting Android tools configuration for Unity ${UNITY_VERSION}"
  echo "::notice::Platform: ${RUNNER_OS}"

  ANDROID_PLAYER_PATH=$(find_unity_android_player_path)

  if [ -z "${ANDROID_PLAYER_PATH}" ]; then
    echo "::error::Failed to locate Unity Android Player path"
    exit 1
  fi

  configure_android_tools "${ANDROID_PLAYER_PATH}"

  echo "::notice::✓ Android tools configuration completed successfully"
}

main
