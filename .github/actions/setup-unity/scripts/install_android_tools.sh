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

find_unity_android_player_path() {
  local android_player_path=""

  echo "::notice::Locating Unity Android Player path"

  if [ -n "${UNITY_PATH_VAR}" ] && [ -d "${UNITY_PATH_VAR}" ]; then
    echo "::notice::Using UNITY_PATH from environment: ${UNITY_PATH_VAR}"

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
        echo "::error::Unsupported platform: ${RUNNER_OS}"
        exit 1
        ;;
    esac
  fi

  if [ -n "${android_player_path}" ] && [ -d "${android_player_path}" ]; then
    echo "::notice::Found Unity Android Player path: ${android_player_path}"
    echo "${android_player_path}"
  else
    echo "::notice::Unity Android Player not found"
    echo "::notice::This is expected if Unity Android module is not installed"
    echo ""
  fi
}

verify_bundled_tools() {
  local android_player_path="$1"

  echo "::notice::Verifying Unity's bundled Android tools"

  local bundled_jdk="${android_player_path}/OpenJDK"
  local bundled_sdk="${android_player_path}/SDK"
  local bundled_ndk="${android_player_path}/NDK"

  local all_found=true

  if [ -d "${bundled_jdk}" ]; then
    if [ -f "${bundled_jdk}/bin/java" ]; then
      local java_version
      java_version=$("${bundled_jdk}/bin/java" -version 2>&1 | head -1 || echo "Unknown")
      echo "::notice::✅ Bundled JDK: ${java_version}"
    else
      echo "::notice::✅ Bundled JDK directory found: ${bundled_jdk}"
    fi
  else
    echo "::warning::⚠️  Bundled JDK not found at: ${bundled_jdk}"
    all_found=false
  fi

  if [ -d "${bundled_sdk}" ]; then
    if [ -f "${bundled_sdk}/platform-tools/adb" ]; then
      local adb_version
      adb_version=$("${bundled_sdk}/platform-tools/adb" version 2>&1 | head -1 || echo "Unknown")
      echo "::notice::✅ Bundled SDK: ${adb_version}"
    else
      echo "::notice::✅ Bundled SDK directory found: ${bundled_sdk}"
    fi
  else
    echo "::warning::⚠️  Bundled SDK not found at: ${bundled_sdk}"
    all_found=false
  fi

  if [ -d "${bundled_ndk}" ]; then
    local ndk_version="Unknown"
    if [ -f "${bundled_ndk}/source.properties" ]; then
      ndk_version=$(grep "Pkg.Revision" "${bundled_ndk}/source.properties" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "Unknown")
    fi
    echo "::notice::✅ Bundled NDK: ${ndk_version}"
  else
    echo "::warning::⚠️  Bundled NDK not found at: ${bundled_ndk}"
    all_found=false
  fi

  if [ "${all_found}" = true ]; then
    return 0
  else
    return 1
  fi
}

display_android_info() {
  local android_player_path="$1"

  echo "::notice::"
  echo "::notice::════════════════════════════════════════════════════"
  echo "::notice::  Unity Android Tools Configuration"
  echo "::notice::════════════════════════════════════════════════════"
  echo "::notice::  Unity will use its bundled Android tools:"
  echo "::notice::"
  echo "::notice::  📦 Android Player: ${android_player_path}"
  echo "::notice::  ☕ OpenJDK:        ${android_player_path}/OpenJDK"
  echo "::notice::  📱 SDK:            ${android_player_path}/SDK"
  echo "::notice::  🔧 NDK:            ${android_player_path}/NDK"
  echo "::notice::"
  echo "::notice::  Unity's bundled tools are version-matched and"
  echo "::notice::  optimized for this Unity version."
  echo "::notice::════════════════════════════════════════════════════"
  echo "::notice::"
}

main() {
  echo "::notice::Starting Android tools verification for Unity ${UNITY_VERSION}"
  echo "::notice::Platform: ${RUNNER_OS}"

  ANDROID_PLAYER_PATH=$(find_unity_android_player_path)

  if [ -z "${ANDROID_PLAYER_PATH}" ]; then
    echo "::notice::✓ Android tools verification skipped (module not installed)"
    exit 0
  fi

  if verify_bundled_tools "${ANDROID_PLAYER_PATH}"; then
    echo "::notice::✅ All bundled Android tools are present"
  else
    echo "::warning::Some bundled tools are missing, but this may be normal"
  fi

  display_android_info "${ANDROID_PLAYER_PATH}"

  echo "::notice::✓ Android tools verification completed"
}

main
