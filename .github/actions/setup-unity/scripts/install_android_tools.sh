#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "::error::Usage: $0 <unity_version> <jdk_path> <sdk_path> <ndk_path>"
    exit 1
fi

unity_version="$1"
jdk_path="$2"
sdk_path="$3"
ndk_path="$4"

validate_paths() {
    echo "::notice::Validating input paths..."

    if [ ! -d "${jdk_path}" ]; then
        echo "::error::JDK path does not exist: ${jdk_path}"
        exit 1
    fi

    if [ ! -d "${sdk_path}" ]; then
        echo "::error::SDK path does not exist: ${sdk_path}"
        exit 1
    fi

    if [ ! -d "${ndk_path}" ]; then
        echo "::error::NDK path does not exist: ${ndk_path}"
        exit 1
    fi

    echo "::notice::Input paths validated successfully"
    echo "::notice::JDK: ${jdk_path}"
    echo "::notice::SDK: ${sdk_path}"
    echo "::notice::NDK: ${ndk_path}"
}

find_unity_android_path() {
    local unity_version="$1"
    local android_player_path=""

    echo "::notice::Locating Unity Android Player path for version ${unity_version}..." >&2

    case "$RUNNER_OS" in
        "macOS")
            local unity_path="/Applications/Unity/Unity-${unity_version}"
            
            if [ -d "${unity_path}" ]; then
                android_player_path="${unity_path}/PlaybackEngines/AndroidPlayer"
                echo "::notice::Found Unity Android Player path: ${android_player_path}" >&2
            else
                echo "::error::Unity installation not found at: ${unity_path}" >&2
            fi
            ;;
        "Linux")
            local unity_dir="$HOME/Unity-${unity_version}"
            if [ -d "${unity_dir}" ]; then
                android_player_path="${unity_dir}/Editor/Data/PlaybackEngines/AndroidPlayer"
                echo "::notice::Found Unity Android Player path: ${android_player_path}" >&2
            else
                echo "::error::Unity installation not found at: ${unity_dir}" >&2
            fi
            ;;
        *)
            echo "::error::Unsupported platform: $RUNNER_OS" >&2
            exit 1
            ;;
    esac

    echo "${android_player_path}"
}

link_directory() {
    local source_path="$1"
    local target_path="$2"
    local description="$3"

    echo "::notice::Linking ${description}..."
    echo "::notice::Source: ${source_path}"
    echo "::notice::Target: ${target_path}"

    if [ -e "${target_path}" ] || [ -L "${target_path}" ]; then
        echo "::notice::Removing existing ${description} at ${target_path}"
        rm -rf "${target_path}"
    fi

    local parent_dir
    parent_dir=$(dirname "${target_path}")
    mkdir -p "${parent_dir}"

    if ln -sf "${source_path}" "${target_path}"; then
        echo "::notice::Successfully linked ${description}"
    else
        echo "::error::Failed to create symbolic link for ${description}"
        exit 1
    fi
}

verify_android_tools() {
    local android_player_path="$1"

    echo "::notice::Verifying Android tools installation..."

    local unity_sdk_dir="${android_player_path}/SDK"
    local unity_ndk_dir="${android_player_path}/NDK"
    local unity_jdk_dir="${android_player_path}/OpenJDK"

    if [ -f "${unity_jdk_dir}/bin/java" ]; then
        local java_version
        java_version=$("${unity_jdk_dir}/bin/java" -version 2>&1 | head -1)
        echo "::notice::✅ Java: ${java_version}"
    else
        echo "::warning::❌ Java executable not found at ${unity_jdk_dir}/bin/java"
    fi

    if [ -f "${unity_sdk_dir}/platform-tools/adb" ]; then
        local adb_version
        adb_version=$("${unity_sdk_dir}/platform-tools/adb" version 2>&1 | head -1)
        echo "::notice::✅ ADB: ${adb_version}"
    else
        echo "::warning::❌ ADB not found at ${unity_sdk_dir}/platform-tools/adb"
    fi

    if [ -f "${unity_ndk_dir}/ndk-build" ]; then
        local ndk_version="Unknown"
        if [ -f "${unity_ndk_dir}/source.properties" ]; then
            ndk_version=$(grep "Pkg.Revision" "${unity_ndk_dir}/source.properties" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "Unknown")
        fi
        echo "::notice::✅ NDK: ${ndk_version}"
    else
        echo "::warning::❌ NDK build tool not found at ${unity_ndk_dir}/ndk-build"
    fi

    echo "::notice::Android tools verification completed"
}

display_unity_paths() {
    local android_player_path="$1"

    echo "::notice::Unity Android Player Tools Setup Complete!"
    echo "::notice::"
    echo "::notice::Unity will automatically detect Android tools via symlinks at:"
    echo "::notice::  📁 Android Player: ${android_player_path}"
    echo "::notice::  ☕ JDK:           ${android_player_path}/OpenJDK -> $(readlink "${android_player_path}/OpenJDK" 2>/dev/null || echo "Link not found")"
    echo "::notice::  📱 SDK:           ${android_player_path}/SDK -> $(readlink "${android_player_path}/SDK" 2>/dev/null || echo "Link not found")"
    echo "::notice::  🔧 NDK:           ${android_player_path}/NDK -> $(readlink "${android_player_path}/NDK" 2>/dev/null || echo "Link not found")"
}

main() {
    echo "::notice::Starting Android tools symlink setup for Unity ${unity_version}"
    echo "::notice::Platform: ${RUNNER_OS}"

    validate_paths

    local android_player_path
    android_player_path=$(find_unity_android_path "${unity_version}")

    if [ -z "${android_player_path}" ]; then
        echo "::error::Failed to locate Unity Android Player path"
        exit 1
    fi

    echo "::notice::Creating Android Player directory structure..."
    mkdir -p "${android_player_path}"

    local unity_sdk_dir="${android_player_path}/SDK"
    local unity_ndk_dir="${android_player_path}/NDK"
    local unity_jdk_dir="${android_player_path}/OpenJDK"

    link_directory "${jdk_path}" "${unity_jdk_dir}" "OpenJDK"
    link_directory "${sdk_path}" "${unity_sdk_dir}" "Android SDK"
    link_directory "${ndk_path}" "${unity_ndk_dir}" "Android NDK"

    verify_android_tools "${android_player_path}"

    display_unity_paths "${android_player_path}"

    echo "::notice::Android tools symlink setup completed successfully"
}

main "$@"