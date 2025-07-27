#!/bin/bash
set -e
if [ "$#" -ne 3 ]; then echo "::error::Usage: $0 <version> <modules> <download_dir>"; exit 1; fi
version="$1"
modules="$2"
download_dir="$3"
run_installer() {
    local installer_path="$1"; echo "::notice::Running installer: ${installer_path}"
    if [[ "$RUNNER_OS" == "macOS" ]]; then sudo installer -pkg "${installer_path}" -target /; else cmd //c "start /wait \"\" \"${installer_path}\" /S"; fi
    local exit_code=$?; if [ "$exit_code" -ne 0 ]; then echo "::error::Installer exited with code: ${exit_code}"; exit 1; fi
}
if [[ "$RUNNER_OS" == "macOS" ]]; then editor_installer="${download_dir}/Unity-${version}.pkg"; else editor_installer="${download_dir}/UnitySetup64-${version}.exe"; fi
run_installer "${editor_installer}"
if [ -n "${modules}" ]; then
    IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
    for module in "${MODULE_ARRAY[@]}"; do
        module_trimmed=$(echo "${module}" | xargs); installer_name=""
        case "${module_trimmed}" in
            "android") installer_name="UnitySetup-Android-Support-for-Editor-${version}";;
            "ios") if [[ "$RUNNER_OS" == "macOS" ]]; then installer_name="UnitySetup-iOS-Support-for-Editor-${version}"; fi;;
            "webgl") installer_name="UnitySetup-WebGL-Support-for-Editor-${version}";;
        esac
        if [ -n "$installer_name" ]; then
            if [[ "$RUNNER_OS" == "macOS" ]]; then module_installer="${download_dir}/${installer_name}.pkg"; else module_installer="${download_dir}/${installer_name}.exe"; fi
            if [ -f "$module_installer" ]; then run_installer "$module_installer"; else echo "::warning::Could not find installer for module ${module_trimmed}"; fi
        fi
    done
fi