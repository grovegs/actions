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

solution_file="${project}/$(basename "${project}").sln"
project_file="${project}/$(basename "${project}").csproj"

if [[ -f "${solution_file}" ]]; then
  target_file="${solution_file}"
  file_type="solution"
elif [[ -f "${project_file}" ]]; then
  target_file="${project_file}"
  file_type="project"
else
  echo "::error::Neither solution file '${solution_file}' nor project file '${project_file}' exists."
  exit 1
fi

echo "::notice::Formatting ${file_type}: ${target_file}"
if ! dotnet format --verify-no-changes "${target_file}"; then
  echo "::warning::Code formatting issues found in ${target_file}"
  exit 1
fi
echo "::notice::${file_type^} formatting verified successfully"
