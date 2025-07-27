#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "::error::Usage: $0 <unity_version>"
    exit 1
fi

unity_version="$1"

find_unity_installation() {
    local version="$1"
    local unity_exe_path=""
    
    echo "::notice::Searching for Unity ${version} installation..."
    
    case "$RUNNER_OS" in
        "macOS")
            local search_paths=(
                "/Applications/Unity/Hub/Editor/${version}/Unity.app"
                "/Applications/Unity/Unity.app"
                "/Applications/Unity-${version}/Unity.app"
            )
            
            for path in "${search_paths[@]}"; do
                if [ -d "${path}" ]; then
                    unity_exe_path="${path}/Contents/MacOS/Unity"
                    if [ -f "${unity_exe_path}" ] && [ -x "${unity_exe_path}" ]; then
                        echo "::notice::Found Unity installation: ${path}"
                        break
                    fi
                fi
            done
            
            if [ -z "${unity_exe_path}" ] || [ ! -f "${unity_exe_path}" ]; then
                echo "::notice::Performing comprehensive search for Unity installations..."
                
                local found_path
                found_path=$(find /Applications -name "Unity.app" -type d 2>/dev/null | while read -r app_path; do
                    local exe_path="${app_path}/Contents/MacOS/Unity"
                    if [ -f "${exe_path}" ] && [ -x "${exe_path}" ]; then
                        local info_plist="${app_path}/Contents/Info.plist"
                        if [ -f "${info_plist}" ]; then
                            local app_version
                            app_version=$(defaults read "${info_plist}" CFBundleVersion 2>/dev/null || echo "")
                            if [[ "${app_version}" == *"${version}"* ]]; then
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
                "$HOME/Unity-${version}/Editor/Unity"
                "$HOME/Unity/Hub/Editor/${version}/Editor/Unity"
                "/opt/Unity-${version}/Editor/Unity"
                "/usr/local/Unity-${version}/Editor/Unity"
            )
            
            for path in "${search_paths[@]}"; do
                if [ -f "${path}" ] && [ -x "${path}" ]; then
                    unity_exe_path="${path}"
                    echo "::notice::Found Unity installation: ${path}"
                    break
                fi
            done
            
            if [ -z "${unity_exe_path}" ] || [ ! -f "${unity_exe_path}" ]; then
                echo "::notice::Performing comprehensive search for Unity installations..."
                
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
            echo "::error::Unsupported platform: $RUNNER_OS"
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