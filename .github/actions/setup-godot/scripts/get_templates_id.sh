#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <platform_templates>"
    exit 1
fi

platform_templates="$1"

templates_id=$(echo "$platform_templates" |
    tr '[:upper:]' '[:lower:]' | tr -d ' ' | tr ',' '\n' | sort |
    awk '{ printf "%s", substr($0, 1, 1) }')

echo "$templates_id"
