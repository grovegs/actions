#!/bin/bash

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "::error::Usage: $0 <project_path> [unity_version]"
    exit 1
fi

project_path="$1"
unity_version_input="$2"

extract_version_info() {
    local full_version="$1"
    local version=""
    local revision=""
    local pattern="^([^[:space:]]+)[[:space:]]*\(([a-f0-9]+)\)$"
    
    if [[ "$full_version" =~ $pattern ]]; then
        version="${BASH_REMATCH[1]}"
        revision="${BASH_REMATCH[2]}"
    else
        version="$full_version"
        revision=""
    fi
    
    echo "$version|$revision"
}

read_from_project_version() {
    local project_version_file="${project_path}/ProjectSettings/ProjectVersion.txt"
    
    if [ ! -f "${project_version_file}" ]; then
        echo "::error::ProjectVersion.txt not found at: ${project_version_file}"
        exit 1
    fi

    if [ ! -r "${project_version_file}" ]; then
        echo "::error::Cannot read file: ${project_version_file}"
        exit 1
    fi

    echo "::notice::Reading Unity version and revision from ${project_version_file}"

    local version
    local revision
    version=$(grep "^m_EditorVersion:" "${project_version_file}" | sed -E 's/^m_EditorVersion:\s*//' | tr -d '\r\n ')
    revision=$(grep "^m_EditorVersionWithRevision:" "${project_version_file}" | sed -E 's/.*\(([a-f0-9]+)\)/\1/' | tr -d '\r\n ')

    if [ -z "${version}" ]; then
        echo "::error::Failed to extract version from ${project_version_file}"
        exit 1
    fi

    if [ -z "${revision}" ]; then
        echo "::error::Failed to extract revision from ${project_version_file}"
        exit 1
    fi
    
    echo "$version|$revision"
}

if [ -n "$unity_version_input" ]; then
    echo "::notice::Using provided Unity version: ${unity_version_input}"
    
    version_info=$(extract_version_info "$unity_version_input")
    version=$(echo "$version_info" | cut -d'|' -f1)
    revision=$(echo "$version_info" | cut -d'|' -f2)
    
    if [ -z "$version" ]; then
        echo "::error::Invalid Unity version format: ${unity_version_input}"
        exit 1
    fi
    
    if [ -z "$revision" ]; then
        echo "::error::Unity version must include revision in parentheses (e.g., '6000.1.9f1 (ed7b183fd33d)')"
        echo "::error::Provided version: ${unity_version_input}"
        echo "::error::You can find the full version with revision in your project's ProjectSettings/ProjectVersion.txt file"
        exit 1
    fi
else
    echo "::notice::No Unity version provided, reading from ProjectVersion.txt"
    
    version_info=$(read_from_project_version)
    version=$(echo "$version_info" | cut -d'|' -f1)
    revision=$(echo "$version_info" | cut -d'|' -f2)
fi

if ! echo "${version}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+$'; then
    echo "::error::Invalid Unity version format: ${version}"
    echo "::error::Expected format: major.minor.patch[stage][build] (e.g., 6000.1.9f1)"
    exit 1
fi

if ! echo "${revision}" | grep -qE '^[a-f0-9]{12}$'; then
    echo "::error::Invalid Unity revision format: ${revision}"
    echo "::error::Expected format: 12-character hexadecimal string (e.g., ed7b183fd33d)"
    exit 1
fi

echo "::notice::Found Unity version: ${version}"
echo "::notice::Found Unity revision: ${revision}"

echo "version=${version}" >> "$GITHUB_OUTPUT"
echo "revision=${revision}" >> "$GITHUB_OUTPUT"