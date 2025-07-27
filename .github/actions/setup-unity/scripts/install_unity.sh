#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "::error::Usage: $0 <version> <modules> <download_dir>"
    exit 1
fi

version="$1"
modules="$2"
download_dir="$3"

validate_download_dir() {
    if [ ! -d "${download_dir}" ]; then
        echo "::error::Download directory does not exist: ${download_dir}"
        exit 1
    fi
    
    echo "::notice::Using download directory: ${download_dir}"
}

run_mac_installer() {
    local installer_path="$1"
    local installer_name
    installer_name=$(basename "${installer_path}")
    
    if [ ! -f "${installer_path}" ]; then
        echo "::error::Installer not found: ${installer_path}"
        exit 1
    fi
    
    echo "::notice::Installing ${installer_name}..."
    
    if ! pkgutil --check-signature "${installer_path}" >/dev/null 2>&1; then
        echo "::warning::Installer signature could not be verified: ${installer_name}"
    fi
    
    if sudo installer -pkg "${installer_path}" -target / -verbose; then
        echo "::notice::Successfully installed ${installer_name}"
    else
        local exit_code
        exit_code=$?
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
    
    echo "::notice::Extracting ${archive_name} to ${extract_dir}..."
    
    if ! mkdir -p "${extract_dir}"; then
        echo "::error::Failed to create extraction directory: ${extract_dir}"
        exit 1
    fi
    
    if tar -xf "${archive_path}" -C "${extract_dir}" --verbose; then
        echo "::notice::Successfully extracted ${archive_name}"
    else
        local exit_code
        exit_code=$?
        echo "::error::Failed to extract ${archive_name} (exit code: ${exit_code})"
        exit 1
    fi
}

install_macos() {
    echo "::notice::Installing Unity for macOS..."
    
    local editor_installer="${download_dir}/Unity-${version}.pkg"
    run_mac_installer "${editor_installer}"
    
    echo "::notice::Verifying Unity installation..."
    
    local unity_app=""
    local search_paths=(
        "/Applications/Unity/Unity.app"
        "/Applications/Unity/Hub/Editor/${version}/Unity.app"
        "/Applications/Unity-${version}/Unity.app"
        "/Applications/Unity ${version}/Unity.app"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -d "${path}" ]; then
            unity_app="${path}"
            echo "::notice::Found Unity installation: ${unity_app}"
            break
        fi
    done
    
    if [ -z "${unity_app}" ]; then
        echo "::notice::Performing comprehensive search for Unity installation..."
        
        local found_app
        found_app=$(find /Applications -name "Unity.app" -type d 2>/dev/null | while read -r app_path; do
            local info_plist="${app_path}/Contents/Info.plist"
            if [ -f "${info_plist}" ]; then
                local app_version
                app_version=$(defaults read "${info_plist}" CFBundleShortVersionString 2>/dev/null || echo "")
                local bundle_version
                bundle_version=$(defaults read "${info_plist}" CFBundleVersion 2>/dev/null || echo "")
                
                if [[ "${app_version}" == "${version}"* ]] || [[ "${bundle_version}" == *"${version}"* ]]; then
                    echo "${app_path}"
                    break
                fi
            fi
        done | head -1)
        
        if [ -n "${found_app}" ]; then
            unity_app="${found_app}"
            echo "::notice::Found Unity installation through comprehensive search: ${unity_app}"
        fi
    fi
    
    if [ -z "${unity_app}" ] || [ ! -d "${unity_app}" ]; then
        echo "::warning::Unity installation directory not found in standard locations"
        echo "::notice::Listing Unity-related applications in /Applications:"
        find /Applications -name "*Unity*" -type d 2>/dev/null | head -10 | while read -r app; do
            echo "::notice::  Found: ${app}"
        done
        
        echo "::notice::Using first available Unity installation for verification"
        unity_app=$(find /Applications -name "Unity.app" -type d 2>/dev/null | head -1)
        
        if [ -z "${unity_app}" ]; then
            echo "::error::No Unity installation found after successful installer execution"
            exit 1
        fi
    fi
    
    local unity_executable="${unity_app}/Contents/MacOS/Unity"
    if [ ! -f "${unity_executable}" ] || [ ! -x "${unity_executable}" ]; then
        echo "::error::Unity executable not found or not executable: ${unity_executable}"
        exit 1
    fi
    
    echo "::notice::Unity successfully installed at: ${unity_app}"
    
    if [ -n "${modules}" ] && [ "${modules}" != "" ]; then
        echo "::notice::Installing macOS modules: ${modules}"
        
        IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
        for module in "${MODULE_ARRAY[@]}"; do
            module_trimmed=$(echo "${module}" | xargs)
            
            if [ -z "${module_trimmed}" ]; then
                continue
            fi
            
            echo "::notice::Installing module: ${module_trimmed}"
            
            local installer_name=""
            case "${module_trimmed}" in
                "android") installer_name="UnitySetup-Android-Support-for-Editor-${version}.pkg" ;;
                "ios") installer_name="UnitySetup-iOS-Support-for-Editor-${version}.pkg" ;;
                "webgl") installer_name="UnitySetup-WebGL-Support-for-Editor-${version}.pkg" ;;
                "mac-il2cpp") installer_name="UnitySetup-Mac-IL2CPP-Support-for-Editor-${version}.pkg" ;;
                "mac-mono") installer_name="UnitySetup-Mac-Mono-Support-for-Editor-${version}.pkg" ;;
                "windows-mono") installer_name="UnitySetup-Windows-Mono-Support-for-Editor-${version}.pkg" ;;
                "windows-il2cpp") installer_name="UnitySetup-Windows-IL2CPP-Support-for-Editor-${version}.pkg" ;;
                "linux-il2cpp") installer_name="UnitySetup-Linux-IL2CPP-Support-for-Editor-${version}.pkg" ;;
                "linux-mono") installer_name="UnitySetup-Linux-Mono-Support-for-Editor-${version}.pkg" ;;
                *)
                    echo "::warning::Unknown module for macOS: ${module_trimmed}"
                    continue
                    ;;
            esac
            
            module_installer="${download_dir}/${installer_name}"
            if [ -f "${module_installer}" ]; then
                run_mac_installer "${module_installer}"
            else
                echo "::warning::Module installer not found: ${installer_name}"
            fi
        done
    fi
}

install_linux() {
    echo "::notice::Installing Unity for Linux..."
    
    local install_location="$HOME/Unity-${version}"
    
    local editor_archive="${download_dir}/Unity.tar.xz"
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
    
    if [ -n "${modules}" ] && [ "${modules}" != "" ]; then
        echo "::notice::Installing Linux modules: ${modules}"
        
        echo "::notice::Attempting to install modules using Unity's module installer..."
        
        install_command=(
            "${unity_executable}"
            -batchmode
            -quit
            -nographics
            -logFile /tmp/unity_module_install.log
            -installModules "${modules}"
        )
        
        if "${install_command[@]}"; then
            echo "::notice::Successfully installed modules using Unity's module installer"
        else
            echo "::warning::Unity module installer failed, attempting manual installation..."
            
            IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
            for module in "${MODULE_ARRAY[@]}"; do
                module_trimmed=$(echo "${module}" | xargs)
                
                if [ -z "${module_trimmed}" ]; then
                    continue
                fi
                
                echo "::notice::Manually installing module: ${module_trimmed}"
                
                local archive_name=""
                case "${module_trimmed}" in
                    "android") archive_name="UnitySetup-Android-Support-for-Editor-${version}.tar.xz" ;;
                    "webgl") archive_name="UnitySetup-WebGL-Support-for-Editor-${version}.tar.xz" ;;
                    "windows-mono") archive_name="UnitySetup-Windows-Mono-Support-for-Editor-${version}.tar.xz" ;;
                    "windows-il2cpp") archive_name="UnitySetup-Windows-IL2CPP-Support-for-Editor-${version}.tar.xz" ;;
                    "mac-mono") archive_name="UnitySetup-Mac-Mono-Support-for-Editor-${version}.tar.xz" ;;
                    "mac-il2cpp") archive_name="UnitySetup-Mac-IL2CPP-Support-for-Editor-${version}.tar.xz" ;;
                    "linux-il2cpp") archive_name="UnitySetup-Linux-IL2CPP-Support-for-Editor-${version}.tar.xz" ;;
                    *)
                        echo "::warning::Unknown module for Linux: ${module_trimmed}"
                        continue
                        ;;
                esac
                
                module_archive="${download_dir}/${archive_name}"
                if [ -f "${module_archive}" ]; then
                    extract_linux_archive "${module_archive}" "${install_location}"
                else
                    echo "::warning::Module archive not found: ${archive_name}"
                fi
            done
        fi
    fi
}

echo "::notice::Starting Unity installation for ${RUNNER_OS}"
echo "::notice::Version: ${version}"
echo "::notice::Modules: ${modules}"

validate_download_dir

case "$RUNNER_OS" in
    "macOS")
        install_macos
        ;;
    "Linux")
        install_linux
        ;;
    *)
        echo "::error::Unsupported platform: $RUNNER_OS"
        exit 1
        ;;
esac

echo "::notice::Unity installation completed successfully"