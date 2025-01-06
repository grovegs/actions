#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "::error::Usage: $0 <project_dir>"
    exit 1
fi

project_dir="$1"

if [ ! -d "$project_dir" ]; then
    echo "::error::Directory '$project_dir' does not exist."
    exit 1
fi

echo "::notice::Importing Godot project from '$project_dir'"

if ! godot --path "$project_dir" --headless --quiet --import; then
    echo "::error::Godot import failed."
    exit 1
fi

echo "::notice::Project import completed successfully"
