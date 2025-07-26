#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <unity_version>"
    exit 1
fi

unity_version="$1"

if [ -z "${unity_version}" ]; then
    echo "::error::Unity version not provided"
    exit 1
fi

if [[ "$RUNNER_OS" != "Windows" && "$RUNNER_OS" != "macOS" ]]; then
    echo "::error::Unity is only supported on Windows and macOS platforms"
    echo "::error::Current platform: $RUNNER_OS"
    echo "is_installed=false" >> "$GITHUB_OUTPUT"
    exit 0
fi

echo "::notice::Checking for Unity ${unity_version} installation"

if [[ "$RUNNER_OS" == "macOS" ]]; then
    unity_paths=(
        "/Applications/Unity/Unity.app"
        "/Applications/Unity.app"
        "/Applications/Unity ${unity_version}.app"
        "/Applications/Unity-${unity_version}.app"
        "/Applications/Unity_${unity_version}.app"
        "/Applications/Unity/Hub/Editor/${unity_version}/Unity.app"
        "/Applications/Unity ${unity_version}/Unity.app"
        "/Applications/Unity-${unity_version}/Unity.app"
        "$HOME/Applications/Unity/Unity.app"
        "$HOME/Applications/Unity.app"
        "$HOME/Applications/Unity-${unity_version}/Unity.app"
    )
elif [[ "$RUNNER_OS" == "Windows" ]]; then
    unity_paths=(
        "C:/Program Files/Unity/Hub/Editor/${unity_version}"
        "C:/Program Files/Unity"
        "C:/Program Files (x86)/Unity"
        "C:/Program Files/Unity ${unity_version}"
        "C:/Program Files/Unity-${unity_version}"
    )
fi

is_installed="false"
found_path=""

if [[ "$RUNNER_OS" == "macOS" ]]; then
    found_apps=$(find /Applications -name "Unity.app" -type d 2>/dev/null | head -5)
    if [ -n "$found_apps" ]; then
        is_installed="true"
        found_path=$(echo "$found_apps" | head -1)
        echo "::notice::Unity found via search at: ${found_path}"
    fi
fi

if [ "${is_installed}" == "false" ]; then
    for path in "${unity_paths[@]}"; do
        echo "::debug::Checking path: ${path}"
        
        if [[ "$RUNNER_OS" == "Windows" ]]; then
            if [ -d "${path}" ]; then
                unity_exe="${path}/Editor/Unity.exe"
                if [ ! -f "${unity_exe}" ]; then
                    unity_exe="${path}/Unity.exe"
                fi
            fi
        elif [[ "$RUNNER_OS" == "macOS" ]]; then
            if [ -d "${path}" ]; then
                unity_exe="${path}/Contents/MacOS/Unity"
            fi
        fi
        
        if [ -f "${unity_exe}" ]; then
            if [[ "${path}" == *"${unity_version}"* ]]; then
                is_installed="true"
                found_path="${path}"
                echo "::notice::Unity ${unity_version} found at: ${found_path}"
                break
            else
                echo "::debug::Found Unity executable at ${unity_exe}, verifying version..."
                
                if [[ "$RUNNER_OS" == "Windows" ]]; then
                    installed_version=$("${unity_exe}" -version 2>/dev/null | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+" | head -1)
                else
                    installed_version=$("${unity_exe}" -version 2>&1 | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+" | head -1)
                fi
                
                if [ -n "${installed_version}" ]; then
                    echo "::debug::Detected installed version: ${installed_version}"
                    if [ "${installed_version}" = "${unity_version}" ]; then
                        is_installed="true"
                        found_path="${path}"
                        echo "::notice::Unity ${unity_version} found at: ${found_path}"
                        break
                    else
                        echo "::debug::Version mismatch: expected ${unity_version}, found ${installed_version}"
                    fi
                else
                    echo "::debug::Could not determine version of Unity installation at ${path}"
                    if [[ "${path}" == *"/Applications/Unity"* ]] || [[ "${path}" == *"Program Files/Unity"* ]]; then
                        echo "::warning::Found Unity installation but could not verify version. Assuming compatible."
                        is_installed="true"
                        found_path="${path}"
                        break
                    fi
                fi
            fi
        fi
    done
fi

if [ "${is_installed}" == "false" ]; then
    echo "::warning::Unity ${unity_version} is not installed"
    echo "::notice::Will proceed with direct Unity installation"
else
    echo "::notice::Unity ${unity_version} installation verified"
fi

echo "is_installed=${is_installed}" >> "$GITHUB_OUTPUT"
echo "found_path=${found_path}" >> "$GITHUB_OUTPUT"