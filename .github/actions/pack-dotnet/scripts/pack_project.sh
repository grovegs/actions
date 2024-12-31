#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <project> <configuration> <version> <filename>"
    exit 1
fi

project="$1"
configuration="$2"
version="$3"
filename="$4"

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

nupkgs_dir=~/.nupkgs

if ! mkdir -p "${nupkgs_dir}"; then
    echo "Error: Failed to create directory '${nupkgs_dir}'."
    exit 1
fi

file="${nupkgs_dir}/${filename}.nupkg"

if ! dotnet pack --no-build --nologo --output "${nupkgs_dir}" --configuration "${configuration}" /p:PackageVersion="${version}" "${project_file}" >/dev/null; then
    echo "Error: Failed to pack the project."
    exit 1
fi

source_file=$(find "${nupkgs_dir}" -name "*.nupkg" -type f -print -quit)

if [[ -z "${source_file}" ]]; then
    echo "Error: No .nupkg file found in ${nupkgs_dir}."
    exit 1
fi

if ! mv "${source_file}" "${file}"; then
    echo "Error: Failed to rename '${source_file}' to '${file}'."
    exit 1
fi

echo file="$file" >>"$GITHUB_OUTPUT"
