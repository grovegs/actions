#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "::error::Usage: $0 <project> <configuration> [<version>] [<define_symbols>]"
    exit 1
fi

project="$1"
configuration="$2"
version="${3:-}"
define_symbols="${4:-}"

if [[ ! -d "${project}" ]]; then
    echo "::error::Project directory '${project}' does not exist."
    exit 1
fi

if [[ "${project}" == "." ]]; then
    file_name="$(basename "$(pwd)")"
else
    file_name="$(basename "${project}")"
fi

project_file="${project}/${file_name}.csproj"

if [[ ! -f "${project_file}" ]]; then
    echo "::error::Project file '${project_file}' does not exist."
    exit 1
fi

version_flag=""
define_symbols_flag=""

if [[ -n "${version}" ]]; then
    version_flag="-p:Version=${version}"
fi

if [[ -n "${define_symbols}" ]]; then
    define_symbols_flag="-p:DefineSymbols=\"${define_symbols}\""
fi

echo "::group::Building ${project_file}"
echo "::debug::Configuration: ${configuration}"
echo "::debug::Version Flag: ${version_flag}"
echo "::debug::Define Symbols Flag: ${define_symbols_flag}"

dotnet build --nologo --configuration "${configuration}" "${project_file}" "${version_flag}" "${define_symbols_flag}"
build_exit_code=$?
echo "::endgroup::"

if [ $build_exit_code -ne 0 ]; then
    echo "::error::Build failed with exit code ${build_exit_code}"
    exit $build_exit_code
fi
