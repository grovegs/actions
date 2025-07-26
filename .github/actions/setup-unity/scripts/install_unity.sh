#!/bin/bash

if [ $# -ne 2 ]; then
    echo "::error::Usage: $0 <unity_version> <modules>"
    exit 1
fi

unity_version="$1"
modules="$2"

echo "::notice::Installing Unity ${unity_version} directly (without Unity Hub)"

if [[ "$RUNNER_OS" != "Windows" && "$RUNNER_OS" != "macOS" ]]; then
    echo "::error::Unity is only supported on Windows and macOS platforms"
    echo "::error::Current platform: $RUNNER_OS"
    exit 1
fi

get_unity_changeset() {
    local version="$1"
    local changeset_url="https://unity.com/releases/editor/archive"
    
    echo "::notice::Fetching changeset for Unity ${version}"
    
    case "${version}" in
        "6000.1.9f1")
            echo "ed7b183fd33d"
            ;;
        "6000.0.23f1")
            echo "7bb5b4536b23"
            ;;
        "2023.3.40f1")
            echo "8c2e6c8d9e0f"
            ;;
        "2022.3.47f1")
            echo "3cceed70b35e"
            ;;
        *)
            echo "::warning::Unknown changeset for version ${version}, using placeholder"
            echo "unknown"
            ;;
    esac
}

download_and_install_unity() {
    local version="$1"
    local changeset="$2"
    
    if [[ "$RUNNER_OS" == "macOS" ]]; then
        local base_url="https://download.unity3d.com/download_unity/${changeset}"
        local installer_name="Unity-${version}.pkg"
        local download_url="${base_url}/MacEditorInstaller/Unity-${version}.pkg"
        
        echo "::notice::Downloading Unity for macOS from ${download_url}"
        curl -L -o "${installer_name}" "${download_url}" || {
            echo "::error::Failed to download Unity installer"
            return 1
        }
        
        echo "::notice::Installing Unity silently"
        sudo installer -pkg "${installer_name}" -target / || {
            echo "::error::Failed to install Unity"
            return 1
        }
        
        rm "${installer_name}"
        
    elif [[ "$RUNNER_OS" == "Windows" ]]; then
        local base_url="https://download.unity3d.com/download_unity/${changeset}"
        local installer_name="UnitySetup64-${version}.exe"
        local download_url="${base_url}/Windows64EditorInstaller/UnitySetup64-${version}.exe"
        
        echo "::notice::Downloading Unity for Windows from ${download_url}"
        curl -L -o "${installer_name}" "${download_url}" || {
            echo "::error::Failed to download Unity installer"
            return 1
        }
        
        echo "::notice::Installing Unity silently"
        ./"${installer_name}" /S /D="C:\\Program Files\\Unity\\Hub\\Editor\\${version}" || {
            echo "::error::Failed to install Unity"
            return 1
        }
        
        rm "${installer_name}"
    fi
}

install_unity_modules() {
    local version="$1"
    local changeset="$2"
    local modules="$3"
    
    if [ -z "${modules}" ]; then
        echo "::notice::No additional modules requested"
        return 0
    fi
    
    echo "::notice::Installing Unity modules: ${modules}"
    
    IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
    
    for module in "${MODULE_ARRAY[@]}"; do
        module=$(echo "${module}" | xargs)
        install_unity_module "${version}" "${changeset}" "${module}"
    done
}

install_unity_module() {
    local version="$1"
    local changeset="$2"
    local module="$3"
    
    echo "::notice::Installing module: ${module}"
    
    local base_url="https://download.unity3d.com/download_unity/${changeset}"
    
    case "${module}" in
        "android")
            if [[ "$RUNNER_OS" == "macOS" ]]; then
                local module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-Android-Support-for-Editor-${version}.pkg"
                local module_file="UnitySetup-Android-Support-${version}.pkg"
            elif [[ "$RUNNER_OS" == "Windows" ]]; then
                local module_url="${base_url}/TargetSupportInstaller/UnitySetup-Android-Support-for-Editor-${version}.exe"
                local module_file="UnitySetup-Android-Support-${version}.exe"
            fi
            ;;
        "ios")
            if [[ "$RUNNER_OS" == "macOS" ]]; then
                local module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-iOS-Support-for-Editor-${version}.pkg"
                local module_file="UnitySetup-iOS-Support-${version}.pkg"
            else
                echo "::warning::iOS support is only available on macOS"
                return 0
            fi
            ;;
        "webgl")
            if [[ "$RUNNER_OS" == "macOS" ]]; then
                local module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-WebGL-Support-for-Editor-${version}.pkg"
                local module_file="UnitySetup-WebGL-Support-${version}.pkg"
            elif [[ "$RUNNER_OS" == "Windows" ]]; then
                local module_url="${base_url}/TargetSupportInstaller/UnitySetup-WebGL-Support-for-Editor-${version}.exe"
                local module_file="UnitySetup-WebGL-Support-${version}.exe"
            fi
            ;;
        *)
            echo "::warning::Unknown module: ${module}"
            return 0
            ;;
    esac
    
    echo "::notice::Downloading module from ${module_url}"
    curl -L -o "${module_file}" "${module_url}" || {
        echo "::warning::Failed to download module ${module}"
        return 1
    }
    
    if [[ "$RUNNER_OS" == "macOS" ]]; then
        sudo installer -pkg "${module_file}" -target / || {
            echo "::warning::Failed to install module ${module}"
        }
    elif [[ "$RUNNER_OS" == "Windows" ]]; then
        ./"${module_file}" /S || {
            echo "::warning::Failed to install module ${module}"
        }
    fi
    
    rm "${module_file}"
}

main() {
    local changeset
    changeset=$(get_unity_changeset "${unity_version}")
    
    if [ "${changeset}" = "unknown" ]; then
        echo "::error::Cannot proceed without changeset for Unity ${unity_version}"
        echo "::error::Please add changeset mapping for this version"
        exit 1
    fi
    
    echo "::notice::Using changeset: ${changeset}"
    
    download_and_install_unity "${unity_version}" "${changeset}" || {
        echo "::error::Unity installation failed"
        exit 1
    }
    
    install_unity_modules "${unity_version}" "${changeset}" "${modules}"
    
    echo "::notice::Unity ${unity_version} installation completed successfully"
}

main