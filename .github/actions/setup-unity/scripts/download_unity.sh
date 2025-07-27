#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "::error::Usage: $0 <version> <changeset> <modules> <download_dir>"
    exit 1
fi

version="$1"
changeset="$2"
modules="$3"
download_dir="$4"

echo "::notice::Creating download directory: ${download_dir}"
if ! mkdir -p "${download_dir}"; then
    echo "::error::Failed to create download directory: ${download_dir}"
    exit 1
fi

download_file() {
    local url="$1"
    local file_path="$2"
    local filename
    filename=$(basename "${file_path}")
    
    echo "::notice::Downloading ${filename} from ${url}"
    
    if [ -f "${file_path}" ]; then
        echo "::notice::File already exists, skipping: ${file_path}"
        return 0
    fi
    
    local temp_file
    temp_file="${file_path}.tmp"
    
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if curl --fail --location --silent --show-error --output "${temp_file}" "${url}"; then
            echo "::notice::Successfully downloaded ${filename}"
            mv "${temp_file}" "${file_path}"
            return 0
        else
            local curl_exit_code=$?
            retry_count=$((retry_count + 1))
            
            if [ $curl_exit_code -eq 22 ]; then
                echo "::warning::Module ${filename} is not available for this platform (HTTP 404)"
                rm -f "${temp_file}" 2>/dev/null || true
                return 1
            fi
            
            echo "::warning::Download attempt ${retry_count} failed for ${filename}"
            
            if [ $retry_count -lt $max_retries ]; then
                echo "::notice::Retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    echo "::error::Failed to download ${filename} after ${max_retries} attempts"
    echo "::error::URL: ${url}"
    rm -f "${temp_file}" 2>/dev/null || true
    return 1
}

validate_download() {
    local file_path="$1"
    local filename
    filename=$(basename "${file_path}")
    
    if [ ! -f "${file_path}" ]; then
        echo "::error::Downloaded file not found: ${file_path}"
        exit 1
    fi
    
    local file_size
    file_size=$(stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}" 2>/dev/null || echo "0")
    if [ "${file_size}" -lt 1048576 ]; then
        echo "::error::Downloaded file appears to be corrupted or incomplete: ${filename} (${file_size} bytes)"
        exit 1
    fi
    
    echo "::notice::Download validated: ${filename} (${file_size} bytes)"
}

get_platform_info() {
    case "$RUNNER_OS" in
        "macOS")
            echo "macOS"
            ;;
        "Linux")
            echo "Linux"
            ;;
        *)
            echo "::error::Unsupported platform: $RUNNER_OS"
            exit 1
            ;;
    esac
}

get_editor_info() {
    local platform="$1"
    
    case "$platform" in
        "macOS")
            echo "MacEditorInstallerArm64|Unity-${version}.pkg"
            ;;
        "Linux")
            echo "LinuxEditorInstaller|Unity.tar.xz"
            ;;
    esac
}

get_module_info() {
    local platform="$1"
    local module="$2"
    
    case "$platform" in
        "macOS")
            case "$module" in
                "android")
                    echo "MacEditorTargetInstaller|UnitySetup-Android-Support-for-Editor-${version}.pkg"
                    ;;
                "ios")
                    echo "MacEditorTargetInstaller|UnitySetup-iOS-Support-for-Editor-${version}.pkg"
                    ;;
                "webgl")
                    echo "MacEditorTargetInstaller|UnitySetup-WebGL-Support-for-Editor-${version}.pkg"
                    ;;
                "mac-il2cpp")
                    echo "MacEditorTargetInstaller|UnitySetup-Mac-IL2CPP-Support-for-Editor-${version}.pkg"
                    ;;
                "mac-mono")
                    echo "MacEditorTargetInstaller|UnitySetup-Mac-Mono-Support-for-Editor-${version}.pkg"
                    ;;
                "windows-mono")
                    echo "MacEditorTargetInstaller|UnitySetup-Windows-Mono-Support-for-Editor-${version}.pkg"
                    ;;
                "windows-il2cpp")
                    echo "MacEditorTargetInstaller|UnitySetup-Windows-IL2CPP-Support-for-Editor-${version}.pkg"
                    ;;
                "linux-il2cpp")
                    echo "MacEditorTargetInstaller|UnitySetup-Linux-IL2CPP-Support-for-Editor-${version}.pkg"
                    ;;
                "linux-mono")
                    echo "MacEditorTargetInstaller|UnitySetup-Linux-Mono-Support-for-Editor-${version}.pkg"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        "Linux")
            case "$module" in
                "webgl")
                    echo "LinuxEditorTargetInstaller|UnitySetup-WebGL-Support-for-Editor-${version}.tar.xz"
                    ;;
                "windows-mono")
                    echo "LinuxEditorTargetInstaller|UnitySetup-Windows-Mono-Support-for-Editor-${version}.tar.xz"
                    ;;
                "windows-il2cpp")
                    echo "LinuxEditorTargetInstaller|UnitySetup-Windows-IL2CPP-Support-for-Editor-${version}.tar.xz"
                    ;;
                "mac-mono")
                    echo "LinuxEditorTargetInstaller|UnitySetup-Mac-Mono-Support-for-Editor-${version}.tar.xz"
                    ;;
                "mac-il2cpp")
                    echo "LinuxEditorTargetInstaller|UnitySetup-Mac-IL2CPP-Support-for-Editor-${version}.tar.xz"
                    ;;
                "linux-il2cpp")
                    echo "LinuxEditorTargetInstaller|UnitySetup-Linux-IL2CPP-Support-for-Editor-${version}.tar.xz"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
    esac
}

echo "::notice::Starting Unity ${version} download for ${RUNNER_OS}"
echo "::notice::Changeset: ${changeset}"
echo "::notice::Modules: ${modules}"

platform=$(get_platform_info)
base_url="https://download.unity3d.com/download_unity/${changeset}"

editor_info=$(get_editor_info "$platform")
editor_path_segment=$(echo "$editor_info" | cut -d'|' -f1)
editor_filename=$(echo "$editor_info" | cut -d'|' -f2)
editor_url="${base_url}/${editor_path_segment}/${editor_filename}"
editor_file_path="${download_dir}/${editor_filename}"

download_file "${editor_url}" "${editor_file_path}"
validate_download "${editor_file_path}"

if [ -n "${modules}" ] && [ "${modules}" != "" ]; then
    echo "::notice::Processing modules: ${modules}"
    
    IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
    
    for module in "${MODULE_ARRAY[@]}"; do
        module_trimmed=$(echo "${module}" | xargs)
        
        if [ -z "${module_trimmed}" ]; then
            continue
        fi
        
        echo "::notice::Processing module: ${module_trimmed}"
        
        module_info=$(get_module_info "$platform" "$module_trimmed")
        
        if [ -z "$module_info" ]; then
            echo "::warning::Module '${module_trimmed}' is not supported on ${platform}, skipping"
            continue
        fi
        
        module_path_segment=$(echo "$module_info" | cut -d'|' -f1)
        module_filename=$(echo "$module_info" | cut -d'|' -f2)
        module_url="${base_url}/${module_path_segment}/${module_filename}"
        module_file_path="${download_dir}/${module_filename}"
        
        if download_file "${module_url}" "${module_file_path}"; then
            validate_download "${module_file_path}"
        else
            echo "::warning::Skipping module '${module_trimmed}' as it is not available for ${platform}"
        fi
    done
else
    echo "::notice::No modules specified for download"
fi

echo "::notice::Unity download completed successfully"