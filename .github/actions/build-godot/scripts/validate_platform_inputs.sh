#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <platform> <required_input1> <required_input2> ..."
    exit 1
fi

platform="$1"
shift

missing_inputs=()

for input in "$@"; do
    if [[ -z "${!input}" ]]; then
        missing_inputs+=("$input")
    fi
done

if [[ ${#missing_inputs[@]} -gt 0 ]]; then
    echo "Error: Missing inputs for platform ${platform}: ${missing_inputs[*]}"
    exit 1
fi
