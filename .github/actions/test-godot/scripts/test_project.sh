#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <project_dir>"
    exit 1
fi

project_dir="$1"

if [ ! -d "${project_dir}" ]; then
    echo "Error: Directory '${project_dir}' does not exist."
    exit 1
fi

csproj_file="${project_dir}/$(basename "${project_dir}").csproj"

if [ ! -f "${csproj_file}" ]; then
    echo "Error: .csproj file '${csproj_file}' not found."
    exit 1
fi

dotnet_output=$(dotnet build "${csproj_file}" 2>&1 || true)
dotnet_exit_code=$?

if [ "$dotnet_exit_code" -ne 0 ]; then
    echo "Error: Failed to build the project. Exit Code: $dotnet_exit_code"
    echo "dotnet build output:"
    echo "${dotnet_output}"
    exit $dotnet_exit_code
fi

godot_output=$(godot --path "${project_dir}" --headless --quiet --import 2>&1 || true)
error_count=$(echo "${godot_output}" | grep -c "ERROR:" || true)

if [ "$error_count" -gt 0 ]; then
    echo "Godot import failed with ${error_count} error(s)."
    echo "Errors:"
    echo "${godot_output}" | grep "ERROR:" | uniq
    exit 1
fi

echo -e "\033[32mPassed\!\033[0m"
