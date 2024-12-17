#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <project> <configuration>"
    exit 1
fi

project="$1"
configuration="$2"

if [[ ! -d "${project}" ]]; then
    echo "Error: Project directory '${project}' does not exist."
    exit 1
fi

if [[ "${project}" == "." ]]; then
    file_name="$(basename "$(pwd)")"
else
    file_name="$(basename "${project}")"
fi

project_file="${project}/${file_name}.csproj"

if [[ ! -f "${project_file}" ]]; then
    echo "Error: Project file '${project_file}' does not exist."
    exit 1
fi

dotnet test --nologo --configuration "${configuration}" "${project_file}"
