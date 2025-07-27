#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "::error::Usage: $0 <project_path> [unity_version]"
    exit 1
fi

project_path="$1"
unity_version_input="${2:-}"

extract_version_info() {
    local full_version="$1"
    local version=""
    local changeset=""
    
    if [[ "$full_version" =~ ^([0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+)[[:space:]]*\(([a-f0-9]{12})\)[[:space:]]*$ ]]; then
        version="${BASH_REMATCH[1]}"
        changeset="${BASH_REMATCH[2]}"
    elif [[ "$full_version" =~ ^([0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+)$ ]]; then
        echo "::error::Unity version must include changeset in parentheses (e.g., '6000.1.9f1 (ed7b183fd33d)')"
        echo "::error::Provided version: ${full_version}"
        echo "::error::You can find the full version with changeset in your project's ProjectSettings/ProjectVersion.txt file"
        exit 1
    else
        echo "::error::Invalid Unity version format: ${full_version}"
        echo "::error::Expected format: 'major.minor.patch[stage][build] (changeset)' (e.g., '6000.1.9f1 (ed7b183fd33d)')"
        exit 1
    fi
    
    echo "$version|$changeset"
}

read_from_project_version() {
    local project_version_file="${project_path}/ProjectSettings/ProjectVersion.txt"
    
    if [ ! -f "${project_version_file}" ]; then
        echo "::error::ProjectVersion.txt not found at: ${project_version_file}"
        echo "::error::Please ensure the project path is correct or provide explicit unity-version"
        exit 1
    fi

    if [ ! -r "${project_version_file}" ]; then
        echo "::error::Cannot read file: ${project_version_file}"
        echo "::error::Please check file permissions"
        exit 1
    fi

    echo "::notice::Reading Unity version from ${project_version_file}"
    
    local version=""
    local changeset=""
    
    version=$(grep "^m_EditorVersion:" "${project_version_file}" | sed -E 's/^m_EditorVersion:[[:space:]]*//' | tr -d '\r\n ')
    changeset=$(grep "^m_EditorVersionWithRevision:" "${project_version_file}" | sed -E 's/.*\(([a-f0-9]{12})\).*/\1/' | tr -d '\r\n ')
    
    if [ -z "${version}" ]; then
        echo "::error::Failed to extract Unity version from ${project_version_file}"
        echo "::error::Please check the file format or provide explicit unity-version"
        exit 1
    fi

    if [ -z "${changeset}" ] || [ "${changeset}" = "${version}" ]; then
        echo "::error::Failed to extract Unity changeset from ${project_version_file}"
        echo "::error::The file may not contain changeset information. Please provide explicit unity-version with changeset"
        exit 1
    fi
    
    echo "$version|$changeset"
}

validate_version_format() {
    local version="$1"
    local changeset="$2"
    
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+$ ]]; then
        echo "::error::Invalid Unity version format: ${version}"
        echo "::error::Expected format: major.minor.patch[stage][build] (e.g., 6000.1.9f1, 2023.3.1f1)"
        exit 1
    fi
    
    if ! [[ "$changeset" =~ ^[a-f0-9]{12}$ ]]; then
        echo "::error::Invalid Unity changeset format: ${changeset}"
        echo "::error::Expected format: 12-character hexadecimal string (e.g., ed7b183fd33d)"
        exit 1
    fi
}

if [ -n "$unity_version_input" ]; then
    echo "::notice::Using provided Unity version: ${unity_version_input}"
    
    version_info=$(extract_version_info "$unity_version_input")
    version=$(echo "$version_info" | cut -d'|' -f1)
    changeset=$(echo "$version_info" | cut -d'|' -f2)
else
    echo "::notice::No Unity version provided, reading from ProjectVersion.txt"
    
    if [ ! -d "$project_path" ]; then
        echo "::error::Project path does not exist: ${project_path}"
        exit 1
    fi
    
    version_info=$(read_from_project_version)
    version=$(echo "$version_info" | cut -d'|' -f1)
    changeset=$(echo "$version_info" | cut -d'|' -f2)
fi

validate_version_format "$version" "$changeset"

echo "::notice::Unity version validated: ${version}"
echo "::notice::Unity changeset validated: ${changeset}"

echo "version=${version}" >> "$GITHUB_OUTPUT"
echo "changeset=${changeset}" >> "$GITHUB_OUTPUT"