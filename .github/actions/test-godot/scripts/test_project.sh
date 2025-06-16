#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "::error::Usage: $0 <project_dir>"
    exit 1
fi

project_dir="$1"

if [ ! -d "${project_dir}" ]; then
    echo "::error::Directory '${project_dir}' does not exist."
    exit 1
fi

if [[ "${project_dir}" == "." ]]; then
    file_name="$(basename "$(pwd)")"
else
    file_name="$(basename "${project_dir}")"
fi

csproj_file="${project_dir}/${file_name}.csproj"

if [ ! -f "${csproj_file}" ]; then
    echo "::error::.csproj file '${csproj_file}' not found."
    exit 1
fi

dotnet_output=$(dotnet build "${csproj_file}" 2>&1 || true)
dotnet_error_count=$(echo "${dotnet_output}" | grep -c "error " || true)
dotnet_warning_count=$(echo "${dotnet_output}" | grep -c "warning " || true)

if [ "${dotnet_error_count}" -gt 0 ]; then
    echo "::error::Dotnet build failed with ${dotnet_error_count} error(s)."
    echo "${dotnet_output}" | grep "error " | uniq | while read -r line; do
        echo "::error::${line}"
    done
fi

if [ "${dotnet_warning_count}" -gt 0 ]; then
    echo "::warning::Dotnet build completed with ${dotnet_warning_count} warning(s)."
    echo "${dotnet_output}" | grep "warning " | uniq | while read -r line; do
        echo "::warning::${line}"
    done
fi

godot_output=$(godot --path "${project_dir}" --headless --quiet --import 2>&1 || true)
godot_error_count=$(echo "${godot_output}" | grep -c "ERROR:" || true)
godot_warning_count=$(echo "${godot_output}" | grep -c "WARNING:" || true)

if [ "${godot_error_count}" -gt 0 ]; then
    echo "::error::Godot import failed with ${godot_error_count} error(s)."
    echo "${godot_output}" | grep "ERROR:" | uniq | while read -r line; do
        echo "::error::${line}"
    done
fi

if [ "${godot_warning_count}" -gt 0 ]; then
    echo "::warning::Godot import completed with ${godot_warning_count} warning(s)."
    echo "${godot_output}" | grep "WARNING:" | uniq | while read -r line; do
        echo "::warning::${line}"
    done
fi

total_errors=$((dotnet_error_count + godot_error_count))
total_warnings=$((dotnet_warning_count + godot_warning_count))

if [ "$total_errors" -eq 0 ]; then
    echo "::notice::Summary: No errors, ${total_warnings} warning(s)."
else
    echo "::error::Summary: ${total_errors} error(s), ${total_warnings} warning(s)."
fi
