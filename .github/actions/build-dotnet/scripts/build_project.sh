#!/bin/bash

set -x

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <project> <configuration> <version>"
    exit 1
fi

project="$1"
configuration="$2"
version="$3"

if [[ ! -d "${project}" ]]; then
    echo "Error: Project directory '${project}' does not exist."
    exit 1
fi

project_file="${project}/$(basename "${project}").csproj"

if [[ ! -f "${project_file}" ]]; then
    echo "Error: Project file '${project_file}' does not exist."
    exit 1
fi

version_flag=""

if [[ -n "${version}" ]]; then
    version_flag="-p:Version=${version}"
fi

dotnet build --nologo --configuration "${configuration}" "${project_file}" "${version_flag}"
