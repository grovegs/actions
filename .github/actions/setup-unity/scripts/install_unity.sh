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

create_unity_wrapper() {
    local unity_path="$1"

    echo "::notice::Creating Unity wrapper script..."

    if [ -L "/usr/local/bin/unity" ] || [ -f "/usr/local/bin/unity" ]; then
        echo "::notice::Removing existing unity command: /usr/local/bin/unity"
        if ! sudo rm -f "/usr/local/bin/unity"; then
            echo "::warning::Failed to remove existing unity command: /usr/local/bin/unity"
        fi
    fi

    if [ -L "/usr/local/bin/Unity" ] || [ -f "/usr/local/bin/Unity" ]; then
        echo "::notice::Removing legacy Unity command: /usr/local/bin/Unity"
        if ! sudo rm -f "/usr/local/bin/Unity"; then
            echo "::warning::Failed to remove legacy Unity command: /usr/local/bin/Unity"
        fi
    fi

    echo "::notice::Creating wrapper script: /usr/local/bin/unity -> ${unity_path}"

    local wrapper_script="#!/bin/bash
set -euo pipefail

unity_real_path=\"${unity_path}\"

if [ ! -f \"\$unity_real_path\" ]; then
    echo \"Error: Unity executable not found: \$unity_real_path\" >&2
    exit 1
fi"

    if [ "$RUNNER_OS" = "macOS" ]; then
        wrapper_script+="

unity_app_dir=\$(dirname \$(dirname \$(dirname \"\$unity_real_path\")))

cd \"\$unity_app_dir\""
    fi

    wrapper_script+="

exec \"\$unity_real_path\" \"\$@\"
"

    if echo "$wrapper_script" | sudo tee /usr/local/bin/unity > /dev/null; then
        if sudo chmod +x /usr/local/bin/unity; then
            echo "::notice::Successfully created Unity wrapper script"
        else
            echo "::error::Failed to make Unity wrapper script executable"
            exit 1
        fi
    else
        echo "::error::Failed to create Unity wrapper script"
        exit 1
    fi

    if command -v unity >/dev/null 2>&1; then
        echo "::notice::Unity command is now available in PATH"

        echo "::notice::Testing Unity wrapper script..."
        if unity -version >/dev/null 2>&1; then
            echo "::notice::Unity wrapper script test successful"
        else
            echo "::warning::Unity wrapper script test failed, but this may be normal for licensing checks"
        fi
    else
        echo "::warning::Unity command may not be available in PATH"
    fi
}

configure_android_environment() {
    local unity_version="$1"
    local installed_modules="$2"
    
    if [[ "${installed_modules}" != *"android"* ]]; then
        echo "::debug::Android module not installed, skipping Android environment configuration"
        return 0
    fi

    echo "::notice::Configuring Android environment..."

    local android_player_path=""
    
    case "$RUNNER_OS" in
        "macOS")
            local unity_search_paths=(
                "/Applications/Unity/Hub/Editor/${unity_version}/PlaybackEngines/AndroidPlayer"
                "/Applications/Unity/PlaybackEngines/AndroidPlayer"
                "/Applications/Unity-${unity_version}/PlaybackEngines/AndroidPlayer"
            )
            
            for path in "${unity_search_paths[@]}"; do
                if [ -d "${path}" ]; then
                    android_player_path="${path}"
                    echo "::notice::Found Unity Android Player at: ${android_player_path}"
                    break
                fi
            done
            ;;
            
        "Linux")
            local unity_search_paths=(
                "$HOME/Unity-${unity_version}/Editor/Data/PlaybackEngines/AndroidPlayer"
                "$HOME/Unity/Hub/Editor/${unity_version}/Editor/Data/PlaybackEngines/AndroidPlayer"
                "/opt/Unity-${unity_version}/Editor/Data/PlaybackEngines/AndroidPlayer"
            )
            
            for path in "${unity_search_paths[@]}"; do
                if [ -d "${path}" ]; then
                    android_player_path="${path}"
                    echo "::notice::Found Unity Android Player at: ${android_player_path}"
                    break
                fi
            done
            ;;
    esac

    if [ -z "${android_player_path}" ]; then
        echo "::warning::Android Player directory not found, attempting comprehensive search..."
        
        android_player_path=$(find /Applications /opt "$HOME" -path "*/PlaybackEngines/AndroidPlayer" -type d 2>/dev/null | head -1)
        
        if [ -n "${android_player_path}" ]; then
            echo "::notice::Found Unity Android Player at: ${android_player_path}"
        else
            echo "::error::Could not locate Unity Android Player directory"
            return 1
        fi
    fi

    local env_vars_set=0

    if [ -d "${android_player_path}/SDK" ]; then
        echo "ANDROID_SDK_ROOT=${android_player_path}/SDK" >> "$GITHUB_ENV"
        echo "::notice::Set ANDROID_SDK_ROOT=${android_player_path}/SDK"
        env_vars_set=1
    else
        echo "::warning::Android SDK not found at: ${android_player_path}/SDK"
    fi

    if [ -d "${android_player_path}/NDK" ]; then
        echo "ANDROID_NDK_ROOT=${android_player_path}/NDK" >> "$GITHUB_ENV"
        echo "::notice::Set ANDROID_NDK_ROOT=${android_player_path}/NDK"
        env_vars_set=1
    else
        echo "::warning::Android NDK not found at: ${android_player_path}/NDK"
    fi

    if [ -d "${android_player_path}/OpenJDK" ]; then
        echo "JAVA_HOME=${android_player_path}/OpenJDK" >> "$GITHUB_ENV"
        echo "::notice::Set JAVA_HOME=${android_player_path}/OpenJDK"
        env_vars_set=1
    else
        echo "::debug::OpenJDK not found at: ${android_player_path}/OpenJDK (may be using system Java)"
    fi

    if [ $env_vars_set -eq 1 ]; then
        echo "::notice::Android environment configured successfully"
    else
        echo "::warning::No Android environment variables were set"
    fi

    return 0
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

    create_unity_wrapper "${unity_exe_path}"

    configure_android_environment "${unity_version}" "${modules}"

    echo "::notice::Unity environment configuration completed successfully"
    echo "::notice::Unity executable: ${unity_exe_path}"
}

install_macos() {
    echo "::notice::Installing Unity for macOS..."

    local editor_installer="${download_dir}/Unity-${version}.pkg"
    run_mac_installer "${editor_installer}"

    if [ -n "${modules}" ] && [ "${modules}" != "" ]; then
        echo "::notice::Installing macOS modules: ${modules}"

        IFS=',' read -ra module_array <<< "${modules}"
        for module in "${module_array[@]}"; do
            module_trimmed=$(echo "${module}" | xargs)

            if [ -z "${module_trimmed}" ]; then
                continue
            fi

            echo "::notice::Installing module: ${module_trimmed}"

            local installer_name=""
            case "${module_trimmed}" in
                "android") installer_name="UnitySetup-Android-Support-for-Editor-${version}.pkg" ;;
                "ios") installer_name="UnitySetup-iOS-Support-for-Editor-${version}.pkg" ;;
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

            IFS=',' read -ra module_array <<< "${modules}"
            for module in "${module_array[@]}"; do
                module_trimmed=$(echo "${module}" | xargs)

                if [ -z "${module_trimmed}" ]; then
                    continue
                fi

                echo "::notice::Manually installing module: ${module_trimmed}"

                local archive_name=""
                case "${module_trimmed}" in
                    "android") archive_name="UnitySetup-Android-Support-for-Editor-${version}.tar.xz" ;;
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