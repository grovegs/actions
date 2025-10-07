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

echo "::notice::Formatting project folder: ${project}"
if ! dotnet format --verify-no-changes "${project}"; then
  echo "::warning::Code formatting issues found in ${project}"
  exit 1
fi
echo "::notice::Project formatting verified successfully"
