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

find_unity_installation() {
  local unity_version="$1"
  local unity_exe_path=""

  echo "::notice::Searching for Unity ${unity_version} installation" >&2

  case "${RUNNER_OS}" in
    "macOS")
      local unity_app_path="/Applications/Unity/Unity-${unity_version}/Unity.app"
      unity_exe_path="${unity_app_path}/Contents/MacOS/Unity"

      if [ -d "${unity_app_path}" ] && [ -f "${unity_exe_path}" ] && [ -x "${unity_exe_path}" ]; then
        echo "::notice::Found Unity installation: ${unity_app_path}" >&2
      else
        echo "::error::Unity installation not found at expected path: ${unity_app_path}" >&2
        unity_exe_path=""
      fi
      ;;

    "Linux")
      unity_exe_path="${HOME}/Unity-${unity_version}/Editor/Unity"

      if [ -f "${unity_exe_path}" ] && [ -x "${unity_exe_path}" ]; then
        echo "::notice::Found Unity installation: ${unity_exe_path}" >&2
      else
        echo "::error::Unity installation not found at expected path: ${unity_exe_path}" >&2
        unity_exe_path=""
      fi
      ;;

    *)
      echo "::error::Unsupported platform: ${RUNNER_OS}" >&2
      exit 1
      ;;
  esac

  echo "${unity_exe_path}"
}

verify_unity_installation() {
  local unity_path="$1"

  if [ ! -f "${unity_path}" ]; then
    echo "::error::Unity executable not found: ${unity_path}"
    return 1
  fi

  if [ ! -x "${unity_path}" ]; then
    echo "::error::Unity executable is not executable: ${unity_path}"
    return 1
  fi

  echo "::notice::Verifying Unity installation"

  set +e
  local version_output
  version_output=$("${unity_path}" -version 2>&1 | head -5)
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

create_unity_wrapper() {
  local unity_path="$1"

  echo "::notice::Creating Unity wrapper script"

  if [ -L "/usr/local/bin/unity" ] || [ -f "/usr/local/bin/unity" ]; then
    echo "::notice::Removing existing unity command: /usr/local/bin/unity"
    if ! sudo rm -f "/usr/local/bin/unity"; then
      echo "::warning::Failed to remove existing unity command: /usr/local/bin/unity"
    fi
  fi

  if [ -L "/usr/local/bin/Unity" ] || [ -f "/usr/local/bin/Unity" ]; then
    echo "::notice::Removing legacy Unity command: /usr/local/bin/Unity"
    if ! sudo rm -f "/usr/local/bin/Unity"; then
      echo "::warning::Failed to remove legacy Unity command: /usr/local/bin/Unity"
    fi
  fi

  echo "::notice::Creating wrapper script: /usr/local/bin/unity -> ${unity_path}"

  local wrapper_script="#!/usr/bin/env bash
set -euo pipefail

UNITY_REAL_PATH=\"${unity_path}\"

if [ ! -f \"\${UNITY_REAL_PATH}\" ]; then
    echo \"Error: Unity executable not found: \${UNITY_REAL_PATH}\" >&2
    exit 1
fi"

  if [ "${RUNNER_OS}" = "macOS" ]; then
    wrapper_script+="

UNITY_APP_DIR=\$(dirname \$(dirname \$(dirname \"\${UNITY_REAL_PATH}\")))

cd \"\${UNITY_APP_DIR}\""
  fi

  wrapper_script+="

exec \"\${UNITY_REAL_PATH}\" \"\$@\"
"

  if echo "${wrapper_script}" | sudo tee /usr/local/bin/unity > /dev/null; then
    if sudo chmod +x /usr/local/bin/unity; then
      echo "::notice::Successfully created Unity wrapper script"
    else
      echo "::error::Failed to make Unity wrapper script executable"
      exit 1
    fi
  else
    echo "::error::Failed to create Unity wrapper script"
    exit 1
  fi

  if command -v unity > /dev/null 2>&1; then
    echo "::notice::Unity command is now available in PATH"

    echo "::notice::Testing Unity wrapper script"
    set +e
    unity -version > /dev/null 2>&1
    set -e
    echo "::notice::Unity wrapper script test completed"
  else
    echo "::warning::Unity command may not be available in PATH"
  fi
}

configure_unity_environment() {
  local unity_version="$1"

  echo "::notice::Configuring Unity environment for version ${unity_version}"

  UNITY_EXE_PATH=$(find_unity_installation "${unity_version}")

  if [ -z "${UNITY_EXE_PATH}" ]; then
    echo "::error::Failed to locate Unity ${unity_version} installation"
    echo "::error::Please ensure Unity is properly installed"
    exit 1
  fi

  if ! verify_unity_installation "${UNITY_EXE_PATH}"; then
    exit 1
  fi

  create_unity_wrapper "${UNITY_EXE_PATH}"

  echo "::notice::✓ Unity environment configuration completed"
  echo "::notice::Unity executable: ${UNITY_EXE_PATH}"
}

install_macos() {
  echo "::notice::Installing Unity for macOS"

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

  configure_unity_environment "${UNITY_VERSION}"
}

install_linux() {
  echo "::notice::Installing Unity for Linux"

  local install_location="${HOME}/Unity-${UNITY_VERSION}"

  local editor_archive="${DOWNLOAD_DIR}/Unity.tar.xz"
  extract_linux_archive "${editor_archive}" "${install_location}"

  local unity_executable="${install_location}/Editor/Unity"
  if [ ! -f "${unity_executable}" ]; then
    echo "::error::Unity executable not found after extraction: ${unity_executable}"
    exit 1
  fi

  if ! chmod +x "${unity_executable}"; then
    echo "::error::Failed to make Unity executable"
    exit 1
  fi

  echo "::notice::Unity installed at: ${unity_executable}"

  if [ -n "${UNITY_MODULES}" ]; then
    echo "::notice::Installing Linux modules: ${UNITY_MODULES}"

    IFS=',' read -ra MODULE_ARRAY <<< "${UNITY_MODULES}"
    for module in "${MODULE_ARRAY[@]}"; do
      MODULE_TRIMMED=$(echo "${module}" | xargs)

      if [ -z "${MODULE_TRIMMED}" ]; then
        continue
      fi

      echo "::notice::Manually installing module: ${MODULE_TRIMMED}"

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
        extract_linux_archive "${MODULE_ARCHIVE}" "${install_location}"
      else
        echo "::warning::Module archive not found: ${archive_name}"
      fi
    done
  fi

  configure_unity_environment "${UNITY_VERSION}"
}

echo "::notice::Starting Unity installation for ${RUNNER_OS}"
echo "::notice::Version: ${UNITY_VERSION}"
echo "::notice::Modules: ${UNITY_MODULES}"

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

echo "::notice::✓ Unity installation completed successfully"
