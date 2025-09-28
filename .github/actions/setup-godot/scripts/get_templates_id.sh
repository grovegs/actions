#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "::error::Usage: $0 <platform_templates>"
  exit 1
fi

platform_templates="$1"

echo "::notice::Processing platform templates"

templates_id=$(echo "$platform_templates" \
  | tr '[:upper:]' '[:lower:]' | tr -d ' ' | tr ',' '\n' | sort \
  | awk '{ printf "%s", substr($0, 1, 1) }')

if [[ -z "$templates_id" ]]; then
  echo "::warning::No templates ID generated"
else
  echo "::notice::Templates ID generated successfully"
fi

echo templates_id="${templates_id}" >> "$GITHUB_OUTPUT"
