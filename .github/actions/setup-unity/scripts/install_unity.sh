#!/bin/bash

if [ $# -ne 3 ]; then
    echo "::error::Usage: $0 <version> <changeset> <modules>"
    exit 1
fi

version="$1"
changeset="$2"
modules="$3"

if [[ "$RUNNER_OS" != "Windows" && "$RUNNER_OS" != "macOS" ]]; then
    echo "::error::Unity is only supported on Windows and macOS platforms"
    echo "::error::Current platform: $RUNNER_OS"
    exit 1
fi

echo "::notice::Installing Unity ${version} (changeset: ${changeset}) directly (without Unity Hub)"

download_and_install_unity() {
    local version="$1"
    local changeset="$2"

    local base_url="https://download.unity3d.com/download_unity/${changeset}"

    if [[ "$RUNNER_OS" == "macOS" ]]; then
        local installer_name="Unity-${version}.pkg"
        local download_url="${base_url}/MacEditorInstaller/${installer_name}"

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
        local installer_name="UnitySetup64-${version}.exe"
        local download_url="${base_url}/Windows64EditorInstaller/${installer_name}"

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
                local module_file="UnitySetup-Android-Support-${version}.pkg"
                local module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-Android-Support-for-Editor-${version}.pkg"
            else
                local module_file="UnitySetup-Android-Support-${version}.exe"
                local module_url="${base_url}/TargetSupportInstaller/UnitySetup-Android-Support-for-Editor-${version}.exe"
            fi
            ;;
        "ios")
            if [[ "$RUNNER_OS" != "macOS" ]]; then
                echo "::warning::iOS support is only available on macOS"
                return 0
            fi
            local module_file="UnitySetup-iOS-Support-${version}.pkg"
            local module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-iOS-Support-for-Editor-${version}.pkg"
            ;;
        "webgl")
            if [[ "$RUNNER_OS" == "macOS" ]]; then
                local module_file="UnitySetup-WebGL-Support-${version}.pkg"
                local module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-WebGL-Support-for-Editor-${version}.pkg"
            else
                local module_file="UnitySetup-WebGL-Support-${version}.exe"
                local module_url="${base_url}/TargetSupportInstaller/UnitySetup-WebGL-Support-for-Editor-${version}.exe"
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
    download_and_install_unity "${version}" "${changeset}" || {
        echo "::error::Unity installation failed"
        exit 1
    }

    install_unity_modules "${version}" "${changeset}" "${modules}"

    echo "::notice::Unity ${version} installation completed successfully"
}

main
