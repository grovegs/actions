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
        "/Applications/Unity/Hub/Editor/${unity_version}/Unity.app"
        "/Applications/Unity-${unity_version}/Unity.app"
        "$HOME/Applications/Unity/Unity.app"
    )
elif [[ "$RUNNER_OS" == "Windows" ]]; then
    unity_paths=(
        "C:/Program Files/Unity/Hub/Editor/${unity_version}/Editor/Unity.exe"
        "C:/Program Files/Unity/Editor/Unity.exe"
        "C:/Program Files (x86)/Unity/Editor/Unity.exe"
    )
else
    echo "::error::Unsupported OS: $RUNNER_OS"
    exit 1
fi

unity_path=""

for path in "${unity_paths[@]}"; do
    if [ -f "${path}" ] || [ -d "${path}" ]; then
        unity_path="${path}"
        echo "::notice::Found Unity at: ${unity_path}"
        break
    fi
done

if [ -z "${unity_path}" ]; then
    echo "::error::Unity ${unity_version} installation not found"
    echo "::error::Checked paths:"
    for path in "${unity_paths[@]}"; do
        echo "  - ${path}"
    done
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