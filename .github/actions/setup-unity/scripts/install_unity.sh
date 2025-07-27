#!/bin/bash

if [ $# -ne 3 ]; then
    echo "::error::Usage: $0 <version> <changeset> <modules>"
    exit 1
fi

version="$1"
changeset="$2"
modules="$3"

if [ -z "$version" ]; then
    echo "::error::Unity version is required"
    exit 1
fi

if [ -z "$changeset" ]; then
    echo "::error::Unity changeset/revision is required"
    exit 1
fi

if [[ "$RUNNER_OS" != "Windows" && "$RUNNER_OS" != "macOS" ]]; then
    echo "::error::Unity is only supported on Windows and macOS platforms"
    echo "::error::Current platform: $RUNNER_OS"
    exit 1
fi

if ! echo "${version}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+$'; then
    echo "::error::Invalid Unity version format: ${version}"
    echo "::error::Expected format: major.minor.patch[stage][build] (e.g., 6000.1.9f1)"
    exit 1
fi

if ! echo "${changeset}" | grep -qE '^[a-f0-9]{12}$'; then
    echo "::error::Invalid Unity changeset format: ${changeset}"
    echo "::error::Expected format: 12-character hexadecimal string (e.g., ed7b183fd33d)"
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
        if ! curl -L -o "${installer_name}" "${download_url}"; then
            echo "::error::Failed to download Unity installer from ${download_url}"
            echo "::error::Please verify that Unity version ${version} with changeset ${changeset} exists"
            return 1
        fi

        echo "::notice::Installing Unity silently"
        if ! sudo installer -pkg "${installer_name}" -target /; then
            echo "::error::Failed to install Unity from ${installer_name}"
            return 1
        fi

        sleep 5
        echo "::notice::Searching for Unity.app in /Applications..."
        find /Applications -name "Unity.app" -type d 2>/dev/null | head -10
        rm "${installer_name}"

    elif [[ "$RUNNER_OS" == "Windows" ]]; then
        local installer_name="UnitySetup64-${version}.exe"
        local download_url="${base_url}/Windows64EditorInstaller/${installer_name}"

        echo "::notice::Downloading Unity for Windows from ${download_url}"
        if ! curl -L -o "${installer_name}" "${download_url}"; then
            echo "::error::Failed to download Unity installer from ${download_url}"
            echo "::error::Please verify that Unity version ${version} with changeset ${changeset} exists"
            return 1
        fi

        echo "::notice::Installing Unity silently. This may take several minutes..."
        local install_dir="C:\\Program Files\\Unity-${version}"
        echo "::notice::Installing to: ${install_dir}"
        
        cmd //c "start /wait \"\" \"${installer_name}\" /S /D=\"${install_dir}\""
        
        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "::error::Unity installer exited with a non-zero code: $exit_code"
            rm "${installer_name}"
            return 1
        fi

        echo "::notice::Installation process finished. Verifying installation..."
        if [ -f "${install_dir}/Editor/Unity.exe" ]; then
            echo "::notice::Unity.exe found at ${install_dir}/Editor/Unity.exe. Verification successful."
        else
            echo "::error::Verification failed. Unity.exe not found at the expected location after installation."
            echo "::error::Searched in: ${install_dir}/Editor/Unity.exe"
            find "C:/Program Files" -name "Unity.exe" -type f 2>/dev/null | grep -i editor | head -5
            rm "${installer_name}"
            return 1
        fi

        rm "${installer_name}"
    fi

    echo "::notice::Unity ${version} installed successfully"
    return 0
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
        echo "::notice::Installing module: ${module}"
        if ! install_unity_module "${version}" "${changeset}" "${module}"; then
            echo "::warning::Failed to install module: ${module}"
        fi
    done
}

install_unity_module() {
    local version="$1"
    local changeset="$2"
    local module="$3"

    local base_url="https://download.unity3d.com/download_unity/${changeset}"
    local module_file=""
    local module_url=""

    case "${module}" in
        "android")
            if [[ "$RUNNER_OS" == "macOS" ]]; then
                module_file="UnitySetup-Android-Support-${version}.pkg"
                module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-Android-Support-for-Editor-${version}.pkg"
            else
                module_file="UnitySetup-Android-Support-${version}.exe"
                module_url="${base_url}/TargetSupportInstaller/UnitySetup-Android-Support-for-Editor-${version}.exe"
            fi
            ;;
        "ios")
            if [[ "$RUNNER_OS" != "macOS" ]]; then
                echo "::warning::iOS support is only available on macOS"
                return 0
            fi
            module_file="UnitySetup-iOS-Support-${version}.pkg"
            module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-iOS-Support-for-Editor-${version}.pkg"
            ;;
        "webgl")
            if [[ "$RUNNER_OS" == "macOS" ]]; then
                module_file="UnitySetup-WebGL-Support-${version}.pkg"
                module_url="${base_url}/MacEditorTargetInstaller/UnitySetup-WebGL-Support-for-Editor-${version}.pkg"
            else
                module_file="UnitySetup-WebGL-Support-${version}.exe"
                module_url="${base_url}/TargetSupportInstaller/UnitySetup-WebGL-Support-for-Editor-${version}.exe"
            fi
            ;;
        *)
            echo "::warning::Unknown or unsupported module: ${module}"
            echo "::warning::Supported modules: android, ios (macOS only), webgl"
            return 0
            ;;
    esac

    echo "::notice::Downloading module from ${module_url}"
    if ! curl -L -o "${module_file}" "${module_url}"; then
        echo "::warning::Failed to download module ${module} from ${module_url}"
        return 1
    fi

    if [[ "$RUNNER_OS" == "macOS" ]]; then
        if ! sudo installer -pkg "${module_file}" -target /; then
            echo "::warning::Failed to install module ${module} from ${module_file}"
            rm -f "${module_file}"
            return 1
        fi
    elif [[ "$RUNNER_OS" == "Windows" ]]; then
        echo "::notice::Installing module ${module} silently..."
        cmd //c "start /wait \"\" \"${module_file}\" /S"

        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "::warning::Module installer for ${module} exited with a non-zero code: $exit_code"
            rm -f "${module_file}"
            return 1
        fi
    fi

    rm -f "${module_file}"
    echo "::notice::Module ${module} installed successfully"
    return 0
}

main() {
    echo "::group::Installing Unity ${version}"
    if ! download_and_install_unity "${version}" "${changeset}"; then
        echo "::error::Unity installation failed"
        exit 1
    fi
    echo "::endgroup::"

    if [ -n "${modules}" ]; then
        echo "::group::Installing Unity Modules"
        install_unity_modules "${version}" "${changeset}" "${modules}"
        echo "::endgroup::"
    fi

    echo "::notice::Unity ${version} installation completed successfully"
}

main