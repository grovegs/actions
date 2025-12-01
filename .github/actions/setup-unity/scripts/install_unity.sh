#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_VERSION:-}" ]; then
  echo "::error::UNITY_VERSION environment variable is required"
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

UNITY_MODULES="${UNITY_MODULES:-}"
UNITY_PATH_INPUT="${UNITY_PATH:-}"

get_default_install_paths() {
  local unity_version="$1"

  case "${RUNNER_OS}" in
    "macOS")
      if [ -n "${UNITY_PATH_INPUT}" ]; then
        echo "${UNITY_PATH_INPUT}/${unity_version}|${UNITY_PATH_INPUT}/${unity_version}/Unity.app/Contents/MacOS/Unity"
      else
        echo "/Applications/Unity/Editor/${unity_version}|/Applications/Unity/Editor/${unity_version}/Unity.app/Contents/MacOS/Unity"
      fi
      ;;
    "Linux")
      if [ -n "${UNITY_PATH_INPUT}" ]; then
        echo "${UNITY_PATH_INPUT}/${unity_version}|${UNITY_PATH_INPUT}/${unity_version}/Editor/Unity"
      else
        echo "${HOME}/Unity/Editor/${unity_version}|${HOME}/Unity/Editor/${unity_version}/Editor/Unity"
      fi
      ;;
    *)
      echo "::error::Unsupported platform: ${RUNNER_OS}"
      exit 1
      ;;
  esac
}

check_existing_installation() {
  local unity_version="$1"
  local install_paths

  install_paths=$(get_default_install_paths "${unity_version}")
  local unity_path
  unity_path=$(echo "${install_paths}" | cut -d'|' -f1)
  local unity_exe_path
  unity_exe_path=$(echo "${install_paths}" | cut -d'|' -f2)

  if [ -f "${unity_exe_path}" ] && [ -x "${unity_exe_path}" ]; then
    echo "::notice::Unity ${unity_version} is already installed"
    echo "::notice::Unity executable: ${unity_exe_path}"

    set +e
    local version_output
    version_output=$("${unity_exe_path}" -version 2>&1 | head -3)
    local version_check=$?
    set -e

    if [ "${version_check}" -eq 0 ] && [ -n "${version_output}" ]; then
      echo "::notice::Existing Unity installation verified:"
      echo "${version_output}" | while IFS= read -r line; do
        echo "::notice::  ${line}"
      done

      echo "${unity_path}"
      return 0
    else
      echo "::warning::Unity executable exists but version check failed, will reinstall"
      return 1
    fi
  fi

  return 1
}

validate_download_dir() {
  if [ ! -d "${DOWNLOAD_DIR}" ]; then
    echo "::error::Download directory does not exist: ${DOWNLOAD_DIR}"
    exit 1
  fi

  echo "::notice::Using download directory: ${DOWNLOAD_DIR}"
}

run_mac_installer() {
  local installer_path="$1"
  local installer_name
  installer_name=$(basename "${installer_path}")

  if [ ! -f "${installer_path}" ]; then
    echo "::error::Installer not found: ${installer_path}"
    exit 1
  fi

  echo "::notice::Installing ${installer_name}"

  if ! pkgutil --check-signature "${installer_path}" > /dev/null 2>&1; then
    echo "::warning::Installer signature could not be verified: ${installer_name}"
  fi

  set +e
  sudo installer -pkg "${installer_path}" -target / -verbose
  local exit_code=$?
  set -e

  if [ "${exit_code}" -eq 0 ]; then
    echo "::notice::Successfully installed ${installer_name}"
  else
    echo "::error::Failed to install ${installer_name} (exit code: ${exit_code})"
    exit 1
  fi
}

extract_linux_archive() {
  local archive_path="$1"
  local extract_dir="$2"
  local archive_name
  archive_name=$(basename "${archive_path}")

  if [ ! -f "${archive_path}" ]; then
    echo "::error::Archive not found: ${archive_path}"
    exit 1
  fi

  echo "::notice::Extracting ${archive_name} to ${extract_dir}"

  if ! mkdir -p "${extract_dir}"; then
    echo "::error::Failed to create extraction directory: ${extract_dir}"
    exit 1
  fi

  if ! command -v tar > /dev/null 2>&1; then
    echo "::error::tar is not installed or not in PATH"
    exit 1
  fi

  set +e
  tar -xf "${archive_path}" -C "${extract_dir}" --verbose
  local exit_code=$?
  set -e

  if [ "${exit_code}" -eq 0 ]; then
    echo "::notice::Successfully extracted ${archive_name}"
  else
    echo "::error::Failed to extract ${archive_name} (exit code: ${exit_code})"
    exit 1
  fi
}

verify_unity_installation() {
  local unity_exe_path="$1"

  if [ ! -f "${unity_exe_path}" ]; then
    echo "::error::Unity executable not found: ${unity_exe_path}"
    return 1
  fi

  if [ ! -x "${unity_exe_path}" ]; then
    echo "::error::Unity executable is not executable: ${unity_exe_path}"
    return 1
  fi

  echo "::notice::Verifying Unity installation"

  set +e
  local version_output
  version_output=$("${unity_exe_path}" -version 2>&1 | head -5)
  set -e

  if [ -n "${version_output}" ]; then
    echo "::notice::Unity version verification successful:"
    echo "${version_output}" | while IFS= read -r line; do
      echo "::notice::  ${line}"
    done
  else
    echo "::warning::Could not verify Unity version (this may be normal)"
  fi

  return 0
}

export_unity_environment() {
  local unity_path="$1"

  echo "::notice::Exporting Unity environment variables"

  echo "UNITY_PATH=${unity_path}" >> "${GITHUB_ENV}"
  echo "unity-path=${unity_path}" >> "${GITHUB_OUTPUT}"

  echo "::notice::Environment variables exported:"
  echo "::notice::  UNITY_PATH=${unity_path}"
}

normalize_unity_installation() {
  local expected_path="$1"
  local actual_install_path="$2"

  if [ "${expected_path}" = "${actual_install_path}" ]; then
    return 0
  fi

  if [ -d "${actual_install_path}" ] && [ ! -d "${expected_path}" ]; then
    echo "::notice::Normalizing Unity installation path"
    echo "::notice::  From: ${actual_install_path}"
    echo "::notice::  To: ${expected_path}"

    local parent_dir
    parent_dir=$(dirname "${expected_path}")

    if ! mkdir -p "${parent_dir}"; then
      echo "::error::Failed to create parent directory: ${parent_dir}"
      return 1
    fi

    if ! sudo mv "${actual_install_path}" "${expected_path}"; then
      echo "::error::Failed to move Unity installation"
      return 1
    fi

    echo "::notice::Unity installation normalized successfully"
  fi

  return 0
}

install_macos() {
  local install_paths
  install_paths=$(get_default_install_paths "${UNITY_VERSION}")
  local unity_path
  unity_path=$(echo "${install_paths}" | cut -d'|' -f1)
  local unity_exe_path
  unity_exe_path=$(echo "${install_paths}" | cut -d'|' -f2)

  echo "::notice::Installing Unity for macOS"
  echo "::notice::Target installation: ${unity_path}"

  local editor_installer="${DOWNLOAD_DIR}/Unity-${UNITY_VERSION}.pkg"
  run_mac_installer "${editor_installer}"

  if [ -n "${UNITY_MODULES}" ]; then
    echo "::notice::Installing macOS modules: ${UNITY_MODULES}"

    IFS=',' read -ra MODULE_ARRAY <<< "${UNITY_MODULES}"
    for module in "${MODULE_ARRAY[@]}"; do
      MODULE_TRIMMED=$(echo "${module}" | xargs)

      if [ -z "${MODULE_TRIMMED}" ]; then
        continue
      fi

      echo "::notice::Installing module: ${MODULE_TRIMMED}"

      local installer_name=""
      case "${MODULE_TRIMMED}" in
        "android") installer_name="UnitySetup-Android-Support-for-Editor-${UNITY_VERSION}.pkg" ;;
        "ios") installer_name="UnitySetup-iOS-Support-for-Editor-${UNITY_VERSION}.pkg" ;;
        *)
          echo "::warning::Unknown module for macOS: ${MODULE_TRIMMED}"
          continue
          ;;
      esac

      MODULE_INSTALLER="${DOWNLOAD_DIR}/${installer_name}"
      if [ -f "${MODULE_INSTALLER}" ]; then
        run_mac_installer "${MODULE_INSTALLER}"
      else
        echo "::warning::Module installer not found: ${installer_name}"
      fi
    done
  fi

  local actual_install="/Applications/Unity/Unity-${UNITY_VERSION}"
  if [ -d "${actual_install}" ]; then
    normalize_unity_installation "${unity_path}" "${actual_install}"
  fi

  if ! verify_unity_installation "${unity_exe_path}"; then
    exit 1
  fi

  export_unity_environment "${unity_path}"
}

install_linux() {
  local install_paths
  install_paths=$(get_default_install_paths "${UNITY_VERSION}")
  local unity_path
  unity_path=$(echo "${install_paths}" | cut -d'|' -f1)
  local unity_exe_path
  unity_exe_path=$(echo "${install_paths}" | cut -d'|' -f2)

  echo "::notice::Installing Unity for Linux"
  echo "::notice::Target installation: ${unity_path}"

  local editor_archive="${DOWNLOAD_DIR}/Unity.tar.xz"
  extract_linux_archive "${editor_archive}" "${unity_path}"

  if [ ! -f "${unity_exe_path}" ]; then
    echo "::error::Unity executable not found after extraction: ${unity_exe_path}"
    exit 1
  fi

  if ! chmod +x "${unity_exe_path}"; then
    echo "::error::Failed to make Unity executable"
    exit 1
  fi

  echo "::notice::Unity installed at: ${unity_exe_path}"

  if [ -n "${UNITY_MODULES}" ]; then
    echo "::notice::Installing Linux modules: ${UNITY_MODULES}"

    IFS=',' read -ra MODULE_ARRAY <<< "${UNITY_MODULES}"
    for module in "${MODULE_ARRAY[@]}"; do
      MODULE_TRIMMED=$(echo "${module}" | xargs)

      if [ -z "${MODULE_TRIMMED}" ]; then
        continue
      fi

      echo "::notice::Installing module: ${MODULE_TRIMMED}"

      local archive_name=""
      case "${MODULE_TRIMMED}" in
        "android") archive_name="UnitySetup-Android-Support-for-Editor-${UNITY_VERSION}.tar.xz" ;;
        *)
          echo "::warning::Unknown module for Linux: ${MODULE_TRIMMED}"
          continue
          ;;
      esac

      MODULE_ARCHIVE="${DOWNLOAD_DIR}/${archive_name}"
      if [ -f "${MODULE_ARCHIVE}" ]; then
        extract_linux_archive "${MODULE_ARCHIVE}" "${unity_path}"
      else
        echo "::warning::Module archive not found: ${archive_name}"
      fi
    done
  fi

  if ! verify_unity_installation "${unity_exe_path}"; then
    exit 1
  fi

  export_unity_environment "${unity_path}"
}

echo "::notice::Starting Unity installation for ${RUNNER_OS}"
echo "::notice::Version: ${UNITY_VERSION}"
echo "::notice::Modules: ${UNITY_MODULES}"

if [ -n "${UNITY_PATH_INPUT}" ]; then
  echo "::notice::Using custom installation directory: ${UNITY_PATH_INPUT}"
fi

EXISTING_UNITY_PATH=$(check_existing_installation "${UNITY_VERSION}" || echo "")

if [ -n "${EXISTING_UNITY_PATH}" ]; then
  export_unity_environment "${EXISTING_UNITY_PATH}"

  echo "::notice::✅ Using existing Unity installation"
  exit 0
fi

validate_download_dir

case "${RUNNER_OS}" in
  "macOS")
    install_macos
    ;;
  "Linux")
    install_linux
    ;;
  *)
    echo "::error::Unsupported platform: ${RUNNER_OS}"
    exit 1
    ;;
esac

echo "::notice::✅ Unity installation completed successfully"
