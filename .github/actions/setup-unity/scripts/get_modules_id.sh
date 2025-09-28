#!/bin/bash

modules_string="$1"

if [ -z "$modules_string" ]; then
  echo ""
  exit 0
fi

modules_id=$(echo "$modules_string" | tr ',' '\n' | sort | while read -r module; do
  trimmed_module=$(echo "$module" | xargs)
  if [ -n "$trimmed_module" ]; then
    echo -n "${trimmed_module:0:3}"
  fi
done)

echo "$modules_id"
