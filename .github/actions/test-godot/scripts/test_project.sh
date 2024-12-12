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
dotnet_error_count=$(echo "${dotnet_output}" | grep -c "error " || true)
dotnet_warning_count=$(echo "${dotnet_output}" | grep -c "warning " || true)

if [ "${dotnet_error_count}" -gt 0 ]; then
    echo "Dotnet build failed with ${dotnet_error_count} error(s)."
    echo "Errors:"
    echo "${dotnet_output}" | grep "error " | uniq
fi

if [ "${dotnet_warning_count}" -gt 0 ]; then
    echo "Dotnet build completed with ${dotnet_warning_count} warning(s)."
    echo "Warnings:"
    echo "${dotnet_output}" | grep "warning " | uniq
fi

godot_output=$(godot --path "${project_dir}" --headless --quiet --import 2>&1 || true)
godot_error_count=$(echo "${godot_output}" | grep -c "ERROR:" || true)
godot_warning_count=$(echo "${godot_output}" | grep -c "WARNING:" || true)

if [ "${godot_error_count}" -gt 0 ]; then
    echo "Godot import failed with ${godot_error_count} error(s)."
    echo "Errors:"
    echo "${godot_output}" | grep "ERROR:" | uniq
fi

if [ "${godot_warning_count}" -gt 0 ]; then
    echo "Godot import completed with ${godot_warning_count} warning(s)."
    echo "Warnings:"
    echo "${godot_output}" | grep "WARNING:" | uniq
fi

total_errors=$((dotnet_error_count + godot_error_count))
total_warnings=$((dotnet_warning_count + godot_warning_count))

if [ "$total_errors" -eq 0 ]; then
    echo -e "\033[32mPassed!\033[0m"
    echo "Summary: No errors, ${total_warnings} warning(s)."
else
    echo -e "\033[31mFailed!\033[0m"
    echo "Summary: ${total_errors} error(s), ${total_warnings} warning(s)."
    exit 1
fi
