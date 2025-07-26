#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <project_path>"
    exit 1
fi

project_path="$1"
project_version_file="${project_path}/ProjectSettings/ProjectVersion.txt"

if [ ! -f "${project_version_file}" ]; then
    echo "::error::ProjectVersion.txt not found at: ${project_version_file}"
    exit 1
fi

if [ ! -r "${project_version_file}" ]; then
    echo "::error::Cannot read file: ${project_version_file}"
    exit 1
fi

echo "::notice::Reading Unity version and revision from ${project_version_file}"

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

echo "::notice::Found Unity version: ${version}"
echo "::notice::Found Unity revision: ${revision}"

echo "version=${version}" >> "$GITHUB_OUTPUT"
echo "revision=${revision}" >> "$GITHUB_OUTPUT"
