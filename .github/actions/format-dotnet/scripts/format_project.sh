#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "::error::Usage: $0 <project>"
  exit 1
fi

project="$1"

if [[ ! -d "${project}" ]]; then
  echo "::error::Project directory '${project}' does not exist."
  exit 1
fi

project_file="${project}/$(basename "${project}").csproj"

if [[ ! -f "${project_file}" ]]; then
  echo "::error::Project file '${project_file}' does not exist."
  exit 1
fi

echo "::notice::Formatting project: ${project_file}"
if ! dotnet format --verify-no-changes "${project_file}"; then
  echo "::warning::Code formatting issues found in ${project_file}"
  exit 1
fi
echo "::notice::Project formatting verified successfully"
