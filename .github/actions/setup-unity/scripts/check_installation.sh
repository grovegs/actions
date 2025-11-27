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

UNITY_PATH_INPUT="${UNITY_PATH:-}"

get_default_install_paths() {
  local unity_version="$1"

  case "${RUNNER_OS}" in
    "macOS")
      if [ -n "${UNITY_PATH_INPUT}" ]; then
        echo "${UNITY_PATH_INPUT}/Unity-${unity_version}|${UNITY_PATH_INPUT}/Unity-${unity_version}/Unity.app/Contents/MacOS/Unity"
      else
        echo "/Applications/Unity/Unity-${unity_version}|/Applications/Unity/Unity-${unity_version}/Unity.app/Contents/MacOS/Unity"
      fi
      ;;
    "Linux")
      if [ -n "${UNITY_PATH_INPUT}" ]; then
        echo "${UNITY_PATH_INPUT}/Unity-${unity_version}|${UNITY_PATH_INPUT}/Unity-${unity_version}/Editor/Unity"
      else
        echo "${HOME}/Unity-${unity_version}|${HOME}/Unity-${unity_version}/Editor/Unity"
      fi
      ;;
    *)
      echo "::error::Unsupported platform: ${RUNNER_OS}"
      exit 1
      ;;
  esac
}

verify_unity_executable() {
  local unity_exe_path="$1"

  if [ ! -f "${unity_exe_path}" ]; then
    echo "::debug::Unity executable not found: ${unity_exe_path}"
    return 1
  fi

  if [ ! -x "${unity_exe_path}" ]; then
    echo "::debug::Unity executable is not executable: ${unity_exe_path}"
    return 1
  fi

  echo "::notice::Unity executable found: ${unity_exe_path}"
  return 0
}

verify_unity_version() {
  local unity_exe_path="$1"
  local expected_version="$2"

  echo "::notice::Verifying Unity version"

  set +e
  local version_output
  version_output=$("${unity_exe_path}" -version 2>&1 | head -5)
  local version_check=$?
  set -e

  if [ "${version_check}" -eq 0 ] && [ -n "${version_output}" ]; then
    echo "::notice::Unity installation verified:"
    echo "${version_output}" | while IFS= read -r line; do
      echo "::notice::  ${line}"
    done

    local installed_version
    installed_version=$(echo "${version_output}" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+' || echo "")

    if [ -n "${installed_version}" ] && [ "${installed_version}" = "${expected_version}" ]; then
      echo "::notice::✅ Version match confirmed: ${installed_version}"
      return 0
    elif [ -n "${installed_version}" ]; then
      echo "::warning::Version mismatch: expected ${expected_version}, found ${installed_version}"
      return 2
    else
      echo "::warning::Could not extract version from Unity output"
      return 0
    fi
  else
    echo "::warning::Unity version check failed (exit code: ${version_check})"
    echo "::notice::This may be normal for some Unity versions or platforms"
    return 0
  fi
}

check_unity_modules() {
  local unity_path="$1"
  local unity_modules="$2"

  if [ -z "${unity_modules}" ]; then
    echo "::notice::No modules specified to check"
    return 0
  fi

  echo "::notice::Checking for installed Unity modules"

  local playback_engines_dir=""
  case "${RUNNER_OS}" in
    "macOS")
      playback_engines_dir="${unity_path}/PlaybackEngines"
      ;;
    "Linux")
      playback_engines_dir="${unity_path}/Editor/Data/PlaybackEngines"
      ;;
  esac

  if [ ! -d "${playback_engines_dir}" ]; then
    echo "::warning::PlaybackEngines directory not found: ${playback_engines_dir}"
    return 1
  fi

  local all_modules_found=true
  IFS=',' read -ra MODULE_ARRAY <<< "${unity_modules}"

  for module in "${MODULE_ARRAY[@]}"; do
    local module_trimmed
    module_trimmed=$(echo "${module}" | xargs)

    if [ -z "${module_trimmed}" ]; then
      continue
    fi

    local module_dir=""
    case "${module_trimmed}" in
      "android")
        module_dir="${playback_engines_dir}/AndroidPlayer"
        ;;
      "ios")
        module_dir="${playback_engines_dir}/iOSSupport"
        ;;
      *)
        echo "::warning::Unknown module: ${module_trimmed}"
        continue
        ;;
    esac

    if [ -d "${module_dir}" ]; then
      echo "::notice::✅ Module found: ${module_trimmed} (${module_dir})"
    else
      echo "::notice::❌ Module missing: ${module_trimmed} (expected at ${module_dir})"
      all_modules_found=false
    fi
  done

  if [ "${all_modules_found}" = true ]; then
    echo "::notice::✅ All required modules are installed"
    return 0
  else
    echo "::notice::⚠️  Some required modules are missing"
    return 1
  fi
}

display_installation_info() {
  local unity_path="$1"
  local unity_exe_path="$2"
  local unity_version="$3"

  echo "::notice::"
  echo "::notice::═══════════════════════════════════════════════════════"
  echo "::notice::  Unity Installation Found"
  echo "::notice::═══════════════════════════════════════════════════════"
  echo "::notice::  Version:     ${unity_version}"
  echo "::notice::  Path:        ${unity_path}"
  echo "::notice::  Executable:  ${unity_exe_path}"
  echo "::notice::  Platform:    ${RUNNER_OS}"

  local install_size="Unknown"
  if command -v du > /dev/null 2>&1; then
    set +e
    install_size=$(du -sh "${unity_path}" 2> /dev/null | cut -f1 || echo "Unknown")
    set -e
  fi
  echo "::notice::  Size:        ${install_size}"
  echo "::notice::═══════════════════════════════════════════════════════"
  echo "::notice::"
}

main() {
  echo "::notice::Checking for existing Unity ${UNITY_VERSION} installation"
  echo "::notice::Platform: ${RUNNER_OS}"

  if [ -n "${UNITY_PATH_INPUT}" ]; then
    echo "::notice::Using custom installation directory: ${UNITY_PATH_INPUT}"
  fi

  local install_paths
  install_paths=$(get_default_install_paths "${UNITY_VERSION}")
  local unity_path
  unity_path=$(echo "${install_paths}" | cut -d'|' -f1)
  local unity_exe_path
  unity_exe_path=$(echo "${install_paths}" | cut -d'|' -f2)

  echo "::notice::Expected installation path: ${unity_path}"
  echo "::notice::Expected executable path: ${unity_exe_path}"

  if ! verify_unity_executable "${unity_exe_path}"; then
    echo "::notice::Unity ${UNITY_VERSION} is not installed"
    echo "installed=false" >> "${GITHUB_OUTPUT}"
    exit 0
  fi

  set +e
  verify_unity_version "${unity_exe_path}" "${UNITY_VERSION}"
  local version_check_result=$?
  set -e

  if [ "${version_check_result}" -eq 2 ]; then
    echo "::warning::Version mismatch detected, will reinstall"
    echo "installed=false" >> "${GITHUB_OUTPUT}"
    exit 0
  fi

  local unity_modules="${UNITY_MODULES:-}"
  if [ -n "${unity_modules}" ]; then
    set +e
    check_unity_modules "${unity_path}" "${unity_modules}"
    local modules_check_result=$?
    set -e

    if [ "${modules_check_result}" -ne 0 ]; then
      echo "::warning::Required modules are missing, will proceed with installation"
      echo "installed=false" >> "${GITHUB_OUTPUT}"
      echo "modules-missing=true" >> "${GITHUB_OUTPUT}"
      exit 0
    fi
  fi

  display_installation_info "${unity_path}" "${unity_exe_path}" "${UNITY_VERSION}"

  echo "installed=true" >> "${GITHUB_OUTPUT}"
  echo "unity-path=${unity_path}" >> "${GITHUB_OUTPUT}"
  echo "unity-exe-path=${unity_exe_path}" >> "${GITHUB_OUTPUT}"

  echo "::notice::✅ Unity ${UNITY_VERSION} is already installed and ready to use"
}

main
