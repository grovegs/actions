#!/bin/bash

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "::error::Usage: $0 <project_path> [unity_version]"
    exit 1
fi

project_path="$1"
unity_version="${2:-}"

if [ -n "${unity_version}" ]; then
    if ! echo "${unity_version}" | grep -qE '^6\.[0-9]+\.[0-9]+[a-z][0-9]+$'; then
        echo "::error::Invalid Unity version format: ${unity_version}. Expected format: 6.x.x[a-z]x (e.g., 6.0.0f1, 6.1.0b5)"
        exit 1
    fi
    
    echo "::notice::Using Unity version from input: ${unity_version}"
    echo "unity_version=${unity_version}" >> "$GITHUB_OUTPUT"
    exit 0
fi

project_version_file="${project_path}/ProjectSettings/ProjectVersion.txt"

if [ ! -f "${project_version_file}" ]; then
    echo "::error::ProjectVersion.txt not found at: ${project_version_file}"
    echo "::error::Please specify unity-version input or ensure project-path is correct"
    exit 1
fi

if [ ! -r "${project_version_file}" ]; then
    echo "::error::Cannot read file: ${project_version_file}"
    exit 1
fi

echo "::notice::ProjectVersion.txt contents:"
cat "${project_version_file}"

unity_version=$(grep "m_EditorVersion:" "${project_version_file}" | sed 's/m_EditorVersion: //' | tr -d '\r\n ')

if [ -z "${unity_version}" ]; then
    echo "::error::Failed to extract Unity version from ${project_version_file}"
    exit 1
fi

if ! echo "${unity_version}" | grep -qE '^6\.[0-9]+\.[0-9]+[a-z][0-9]+$'; then
    echo "::error::This action is for Unity 6 only. Found version: ${unity_version}"
    echo "::error::Unity 6 versions start with '6.' (e.g., 6.0.0f1)"
    exit 1
fi

echo "::notice::Found Unity version: ${unity_version}"
echo "unity_version=${unity_version}" >> "$GITHUB_OUTPUT"