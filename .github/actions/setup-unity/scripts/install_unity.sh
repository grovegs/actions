#!/bin/bash
set -e
if [ "$#" -ne 3 ]; then
    echo "::error::Usage: $0 <version> <modules> <download_dir>"
    exit 1
fi
version="$1"
modules="$2"
download_dir="$3"
run_installer() {
    local installer_path="$1"; echo "::notice::Running installer/extractor: ${installer_path}"
    if [[ "$RUNNER_OS" == "macOS" ]]; then
        sudo installer -pkg "${installer_path}" -target /
    elif [[ "$RUNNER_OS" == "Linux" ]]; then
        install_location="$HOME/Unity-${version}"
        mkdir -p "${install_location}"
        tar -xf "${installer_path}" -C "${install_location}"
    fi
    local exit_code=$?; if [ "$exit_code" -ne 0 ]; then echo "::error::Process exited with code: ${exit_code}"; exit 1; fi
}
if [[ "$RUNNER_OS" == "macOS" ]]; then editor_installer="${download_dir}/Unity-${version}.pkg";
elif [[ "$RUNNER_OS" == "Linux" ]]; then editor_installer="${download_dir}/Unity.tar.xz";
fi
run_installer "${editor_installer}"
if [ -n "${modules}" ]; then
    IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
    for module in "${MODULE_ARRAY[@]}"; do
        module_trimmed=$(echo "${module}" | xargs)
        installer_filename=""
        case "${module_trimmed}" in
            "android")
                if [[ "$RUNNER_OS" == "Linux" ]]; then installer_filename="Android.tar.xz";
                else installer_filename="UnitySetup-Android-Support-for-Editor-${version}.pkg"; fi;;
            "ios")
                if [[ "$RUNNER_OS" == "macOS" ]]; then installer_filename="UnitySetup-iOS-Support-for-Editor-${version}.pkg"; fi;;
            "webgl")
                if [[ "$RUNNER_OS" == "Linux" ]]; then installer_filename="WebGL.tar.xz";
                else installer_filename="UnitySetup-WebGL-Support-for-Editor-${version}.pkg"; fi;;
        esac
        if [ -n "$installer_filename" ]; then
            module_installer="${download_dir}/${installer_filename}"
            if [ -f "$module_installer" ]; then
                run_installer "$module_installer"
            else
                echo "::warning::Could not find installer for module ${module_trimmed}"
            fi
        fi
    done
fi