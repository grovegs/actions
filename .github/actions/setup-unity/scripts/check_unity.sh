#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <unity_version>"
    exit 1
fi

unity_version="$1"

if [ -z "${unity_version}" ]; then
    echo "::error::Unity version not provided."
    exit 1
fi

echo "::notice::Checking for Unity ${unity_version} installation"

if [[ "$RUNNER_OS" == "Linux" ]]; then
    unity_paths=(
        "$HOME/Unity/Hub/Editor/${unity_version}"
        "/opt/Unity/Hub/Editor/${unity_version}"
    )
elif [[ "$RUNNER_OS" == "macOS" ]]; then
    unity_paths=(
        "/Applications/Unity/Hub/Editor/${unity_version}"
        "$HOME/Unity/Hub/Editor/${unity_version}"
        "/Applications/Unity ${unity_version}"
    )
elif [[ "$RUNNER_OS" == "Windows" ]]; then
    unity_paths=(
        "C:/Program Files/Unity/Hub/Editor/${unity_version}"
        "C:/Program Files (x86)/Unity/Hub/Editor/${unity_version}"
        "$HOME/Unity/Hub/Editor/${unity_version}"
    )
else
    echo "::error::Unsupported OS: $RUNNER_OS"
    exit 1
fi

is_installed="false"
found_path=""

for path in "${unity_paths[@]}"; do
    echo "::debug::Checking path: ${path}"
    
    if [[ "$RUNNER_OS" == "Windows" ]]; then
        unity_exe="${path}/Editor/Unity.exe"
    elif [[ "$RUNNER_OS" == "macOS" ]]; then
        unity_exe="${path}/Unity.app/Contents/MacOS/Unity"
    else
        unity_exe="${path}/Editor/Unity"
    fi
    
    if [ -f "${unity_exe}" ]; then
        is_installed="true"
        found_path="${path}"
        echo "::notice::Unity ${unity_version} found at: ${found_path}"
        break
    fi
done

if [ "${is_installed}" == "false" ]; then
    echo "::warning::Unity ${unity_version} is not installed"
    
    if command -v unity-hub &>/dev/null; then
        echo "::notice::Unity Hub is available, can proceed with installation"
    else
        echo "::notice::Unity Hub is not installed, will need to install it first"
    fi
fi

echo "is_installed=${is_installed}" >> "$GITHUB_OUTPUT"
echo "found_path=${found_path}" >> "$GITHUB_OUTPUT"