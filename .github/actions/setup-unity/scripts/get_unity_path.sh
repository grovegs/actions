#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <unity_version>"
    exit 1
fi

unity_version="$1"

echo "::notice::Getting Unity ${unity_version} installation path"

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
        "C:/Program Files/Unity/Hub/Editor/${unity_version}/Editor/Unity.exe"
        "C:/Program Files/Unity/Editor/Unity.exe"
        "C:/Program Files (x86)/Unity/Editor/Unity.exe"
        "C:/Program Files/Unity ${unity_version}/Editor/Unity.exe"
        "C:/Program Files/Unity-${unity_version}/Editor/Unity.exe"
    )
else
    echo "::error::Unsupported OS: $RUNNER_OS"
    exit 1
fi

unity_path=""

if [[ "$RUNNER_OS" == "macOS" ]]; then
    echo "::notice::Performing broad search for Unity installations..."
    found_apps=$(find /Applications -name "Unity.app" -type d 2>/dev/null | head -5)
    if [ -n "$found_apps" ]; then
        echo "::notice::Found Unity installations via search:"
        echo "$found_apps"
        unity_path=$(echo "$found_apps" | head -1)
        echo "::notice::Selected Unity at: ${unity_path}"
    fi
fi

if [ -z "${unity_path}" ]; then
    for path in "${unity_paths[@]}"; do
        echo "::debug::Checking path: ${path}"
        if [ -f "${path}" ] || [ -d "${path}" ]; then
            unity_path="${path}"
            echo "::notice::Found Unity at: ${unity_path}"
            break
        fi
    done
fi

if [ -z "${unity_path}" ]; then
    echo "::error::Unity ${unity_version} installation not found"
    echo "::error::Searched using find command and checked these specific paths:"
    for path in "${unity_paths[@]}"; do
        echo "  - ${path}"
    done
    
    if [[ "$RUNNER_OS" == "macOS" ]]; then
        echo "::error::Current /Applications directory contents:"
        find /Applications -maxdepth 1 -type d -name "*Unity*" 2>/dev/null | head -20
        if [ $? -ne 0 ] || [ -z "$(find /Applications -maxdepth 1 -type d -name "*Unity*" 2>/dev/null)" ]; then
            find /Applications -maxdepth 1 -type d 2>/dev/null | head -20
        fi
    fi
    
    exit 1
fi

echo "unity_path=${unity_path}" >> "$GITHUB_OUTPUT"

if [[ "$RUNNER_OS" == "Windows" ]]; then
    editor_dir=$(dirname "${unity_path}")
elif [[ "$RUNNER_OS" == "macOS" ]]; then
    editor_dir="${unity_path}/Contents/MacOS"
else
    editor_dir=$(dirname "${unity_path}")
fi

echo "editor_dir=${editor_dir}" >> "$GITHUB_OUTPUT"