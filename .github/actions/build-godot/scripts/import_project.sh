#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <project_dir>"
    exit 1
fi

project_dir="$1"

if [ ! -d "$project_dir" ]; then
    echo "Error: Directory '$project_dir' does not exist."
    exit 1
fi

if ! godot --path "$project_dir" --headless --quiet --import; then
    echo "Error: Godot import failed."
    exit 1
fi
