#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "::error::Usage: $0 <project> <configuration>"
  exit 1
fi

project="$1"
configuration="$2"

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

echo "::notice::Running tests for project '${project_file}' with configuration '${configuration}'"
dotnet test --nologo --configuration "${configuration}" "${project_file}"
