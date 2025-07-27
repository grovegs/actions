#!/bin/bash
set -e
if [ "$#" -ne 3 ]; then echo "::error::Usage: $0 <version> <modules> <download_dir>"; exit 1; fi
version="$1"
modules="$2"
download_dir="$3"
if [[ "$RUNNER_OS" == "macOS" ]]; then
    run_mac_installer() {
        local installer_path="$1"; echo "::notice::Running installer: ${installer_path}"
        if ! sudo installer -pkg "${installer_path}" -target /; then
            echo "::error::Installer exited with a non-zero status."
            exit 1
        fi
    }
    editor_installer="${download_dir}/Unity-${version}.pkg"
    run_mac_installer "${editor_installer}"
    if [ -n "${modules}" ]; then
        IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
        for module in "${MODULE_ARRAY[@]}"; do
            module_trimmed=$(echo "${module}" | xargs)
            installer_filename="UnitySetup-${module_trimmed^}-Support-for-Editor-${version}.pkg"
            module_installer="${download_dir}/${installer_filename}"
            if [ -f "$module_installer" ]; then run_mac_installer "$module_installer"; else echo "::warning::Could not find installer for module ${module_trimmed}"; fi
        done
    fi
fi
if [[ "$RUNNER_OS" == "Linux" ]]; then
    install_location="$HOME/Unity-${version}"
    mkdir -p "${install_location}"
    echo "::notice::Extracting Unity Editor to ${install_location}"
    if ! tar -xf "${download_dir}/Unity.tar.xz" -C "${install_location}"; then
        echo "::error::Failed to extract Unity Editor archive."
        exit 1
    fi
    
    unity_executable="${install_location}/Editor/Unity"
    chmod +x "${unity_executable}"
    
    if [ -n "${modules}" ]; then
        echo "::notice::Installing Linux modules: ${modules}"
        install_command=(
            "${unity_executable}"
            -install-modules
            -modules="${modules}"
            -silent
        )
        if ! "${install_command[@]}"; then
            echo "::error::Failed to install Linux modules."
            exit 1
        fi
    fi
fi