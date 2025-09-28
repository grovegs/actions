#!/bin/bash

set -e

SEARCH_PATH="$1"
EXCLUDE_PATHS="$2"

echo "Formatting shell scripts in: $SEARCH_PATH"
echo "Excluding paths: $EXCLUDE_PATHS"

# Check if shfmt is installed
if ! command -v shfmt &> /dev/null; then
    echo "Error: shfmt is not installed"
    exit 1
fi

# Build find command with exclusions
FIND_CMD="find $SEARCH_PATH -name '*.sh'"

if [ -n "$EXCLUDE_PATHS" ]; then
    IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_PATHS"
    for exclude in "${EXCLUDE_ARRAY[@]}"; do
        FIND_CMD="$FIND_CMD -not -path '$exclude/*'"
    done
fi

# Find and format shell scripts
eval "$FIND_CMD" | while read -r file; do
    echo "Formatting: $file"
    shfmt -w -i 2 -ci "$file"
done

echo "Shell script formatting completed successfully"