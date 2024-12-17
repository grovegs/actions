#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <project_dir>"
    exit 1
fi

project_dir="$1"

if [ ! -d "$project_dir" ]; then
    echo "Error: Directory '$project_dir' does not exist."
    exit 1
fi

if [[ "${project_dir}" == "." ]]; then
    file_name="$(basename "$(pwd)")"
else
    file_name="$(basename "${project_dir}")"
fi

csproj_file="${project_dir}/${file_name}.csproj"

if [ ! -f "$csproj_file" ]; then
    echo "Error: .csproj file '$csproj_file' not found."
    exit 1
fi

if ! dotnet build "$csproj_file"; then
    echo "Error: Failed to build the project."
    exit 1
fi

if ! godot --path "$project_dir" --headless --quiet --import; then
    echo "Error: Godot import failed."
    exit 1
fi
