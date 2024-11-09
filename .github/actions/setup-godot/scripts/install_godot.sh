#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <installation_file>"
    exit 1
fi

installation_file="$1"

if [ ! -f "$installation_file" ]; then
    echo "Error: File '$installation_file' not found!"
    exit 1
fi

file_dir=$(dirname "$installation_file")
file_name=$(basename "$installation_file")
cd "$file_dir" || exit 1

if ! unzip "$file_name"; then
    echo "Extraction failed."
    exit 1
fi

rm "$file_name"

echo "$file_dir/$(basename "$file_name" .zip)"
