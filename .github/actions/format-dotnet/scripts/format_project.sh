#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <project>"
    exit 1
fi

project="$1"

if [[ ! -d "${project}" ]]; then
    echo "Error: Project directory '${project}' does not exist."
    exit 1
fi

project_file="${project}/$(basename "${project}").csproj"

if [[ ! -f "${project_file}" ]]; then
    echo "Error: Project file '${project_file}' does not exist."
    exit 1
fi

dotnet format --verify-no-changes "${project_file}"
