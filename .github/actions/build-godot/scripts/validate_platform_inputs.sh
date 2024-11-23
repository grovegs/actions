#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <platform> <key=value> [<key=value> ...]"
    exit 1
fi

platform="$1"
shift

missing_inputs=()

for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"

    if [[ -z "$value" || "$value" == "$pair" ]]; then
        missing_inputs+=("$key=<missing>")
    fi
done

if [[ ${#missing_inputs[@]} -gt 0 ]]; then
    echo "Error: Missing inputs for platform ${platform}: ${missing_inputs[*]}"
    exit 1
fi
