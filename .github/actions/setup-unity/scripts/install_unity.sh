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

find_unity_installation() {
    local unity_version="$1"
    local unity_exe_path=""
    
    echo "::notice::Searching for Unity ${unity_version} installation..." >&2
    
    case "$RUNNER_OS" in
        "macOS")
            local search_paths=(
                "/Applications/Unity/Hub/Editor/${unity_version}/Unity.app"
                "/Applications/Unity/Unity.app"
                "/Applications/Unity-${unity_version}/Unity.app"
                "/Applications/Unity/Unity-${unity_version}/Unity.app"
                "/Applications/Unity ${unity_version}/Unity.app"
            )
            
            for path in "${search_paths[@]}"; do
                if [ -d "${path}" ]; then
                    unity_exe_path="${path}/Contents/MacOS/Unity"
                    if [ -f "${unity_exe_path}" ] && [ -x "${unity_exe_path}" ]; then
                        echo "::notice::Found Unity installation: ${path}" >&2
                        break
                    fi
                fi
            done
            
            if [ -z "${unity_exe_path}" ] || [ ! -f "${unity_exe_path}" ]; then
                echo "::notice::Performing comprehensive search for Unity installations..." >&2
                
                local found_path
                found_path=$(find /Applications -name "Unity.app" -type d 2>/dev/null | while read -r app_path; do
                    local exe_path="${app_path}/Contents/MacOS/Unity"
                    if [ -f "${exe_path}" ] && [ -x "${exe_path}" ]; then
                        local info_plist="${app_path}/Contents/Info.plist"
                        if [ -f "${info_plist}" ]; then
                            local app_version
                            app_version=$(defaults read "${info_plist}" CFBundleShortVersionString 2>/dev/null || echo "")
                            local bundle_version
                            bundle_version=$(defaults read "${info_plist}" CFBundleVersion 2>/dev/null || echo "")
                            
                            if [[ "${app_version}" == "${unity_version}"* ]] || [[ "${bundle_version}" == *"${unity_version}"* ]] || [[ "${app_path}" == *"${unity_version}"* ]]; then
                                echo "${exe_path}"
                                break
                            fi
                        fi
                    fi
                done | head -1)
                
                if [ -n "${found_path}" ]; then
                    unity_exe_path="${found_path}"
                fi
            fi
            ;;
            
        "Linux")
            local search_paths=(
                "$HOME/Unity-${unity_version}/Editor/Unity"
                "$HOME/Unity/Hub/Editor/${unity_version}/Editor/Unity"
                "/opt/Unity-${unity_version}/Editor/Unity"
                "/usr/local/Unity-${unity_version}/Editor/Unity"
            )
            
            for path in "${search_paths[@]}"; do
                if [ -f "${path}" ] && [ -x "${path}" ]; then
                    unity_exe_path="${path}"
                    echo "::notice::Found Unity installation: ${path}" >&2
                    break
                fi
            done
            
            if [ -z "${unity_exe_path}" ] || [ ! -f "${unity_exe_path}" ]; then
                echo "::notice::Performing comprehensive search for Unity installations..." >&2
                
                local search_dirs=(
                    "$HOME"
                    "/opt"
                    "/usr/local"
                )
                
                for dir in "${search_dirs[@]}"; do
                    if [ -d "${dir}" ]; then
                        local found_path
                        found_path=$(find "${dir}" -path "*/Editor/Unity" -type f -executable 2>/dev/null | while read -r exe_path; do
                            if "${exe_path}" -version 2>/dev/null | grep -q "Unity"; then
                                echo "${exe_path}"
                                break
                            fi
                        done | head -1)
                        
                        if [ -n "${found_path}" ]; then
                            unity_exe_path="${found_path}"
                            break
                        fi
                    fi
                done
            fi
            ;;
            
        *)
            echo "::error::Unsupported platform: $RUNNER_OS" >&2
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
    
    echo "::notice::Verifying Unity installation..."
    
    local version_output
    if version_output=$("${unity_path}" -version 2>&1 | head -5); then
        echo "::notice::Unity version verification successful:"
        echo "${version_output}" | while IFS= read -r line; do
            echo "::notice::  ${line}"
        done
    else
        echo "::warning::Could not verify Unity version (this may be normal)"
    fi
    
    return 0
}

create_symlinks() {
    local unity_path="$1"
    
    echo "::notice::Creating Unity symlinks..."
    
    local symlinks=("/usr/local/bin/unity" "/usr/local/bin/Unity")
    
    for symlink in "${symlinks[@]}"; do
        if [ -L "${symlink}" ]; then
            echo "::notice::Removing existing symlink: ${symlink}"
            if ! sudo rm -f "${symlink}"; then
                echo "::warning::Failed to remove existing symlink: ${symlink}"
            fi
        elif [ -f "${symlink}" ]; then
            echo "::warning::File exists at symlink location (not a symlink): ${symlink}"
        fi
    done
    
    echo "::notice::Creating symlink: /usr/local/bin/unity -> ${unity_path}"
    if sudo ln -s "${unity_path}" /usr/local/bin/unity; then
        echo "::notice::Successfully created Unity symlink"
    else
        echo "::error::Failed to create Unity symlink"
        exit 1
    fi
    
    if command -v unity >/dev/null 2>&1; then
        echo "::notice::Unity command is now available in PATH"
    else
        echo "::warning::Unity command may not be available in PATH"
    fi
}

setup_environment_variables() {
    local unity_path="$1"
    local unity_version="$2"
    
    echo "::notice::Setting up environment variables..."
    
    echo "UNITY_VERSION=${unity_version}" >> "$GITHUB_ENV"
    echo "UNITY_PATH=${unity_path}" >> "$GITHUB_ENV"
    echo "unity_path=${unity_path}" >> "$GITHUB_OUTPUT"
    
    echo "::notice::Environment variables configured:"
    echo "::notice::  UNITY_VERSION=${unity_version}"
    echo "::notice::  UNITY_PATH=${unity_path}"
}

configure_unity_environment() {
    local unity_version="$1"
    
    echo "::notice::Configuring Unity environment for version ${unity_version}"
    
    unity_exe_path=$(find_unity_installation "${unity_version}")
    
    if [ -z "${unity_exe_path}" ]; then
        echo "::error::Failed to locate Unity ${unity_version} installation"
        echo "::error::Please ensure Unity is properly installed"
        exit 1
    fi
    
    if ! verify_unity_installation "${unity_exe_path}"; then
        exit 1
    fi
    
    create_symlinks "${unity_exe_path}"
    setup_environment_variables "${unity_exe_path}" "${unity_version}"
    
    echo "::notice::Unity environment configuration completed successfully"
    echo "::notice::Unity executable: ${unity_exe_path}"
}

install_macos() {
    echo "::notice::Installing Unity for macOS..."
    
    local editor_installer="${download_dir}/Unity-${version}.pkg"
    run_mac_installer "${editor_installer}"
    
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
    
    configure_unity_environment "${version}"
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
    
    configure_unity_environment "${version}"
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