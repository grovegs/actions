#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <project> <configuration> <version> <define_constants>"
    exit 1
fi

project="$1"
configuration="$2"
version="$3"
define_constants="$4"

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

version_flag=""
define_constants_flag=""

if [[ -n "${version}" ]]; then
    version_flag="-p:Version=${version}"
fi

if [[ -n "${define_constants}" ]]; then
    define_constants_flag="-p:DefineConstants=$(DefineConstants);${define_constants}"
fi

dotnet build --nologo --configuration "${configuration}" "${project_file}" "${version_flag}" "${define_constants_flag}"
