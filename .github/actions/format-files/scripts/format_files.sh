#!/bin/bash

set -e

FILES_PATTERN="$1"
IGNORE_PATH="$2"

echo "Formatting files with pattern: $FILES_PATTERN"
echo "Using ignore file: $IGNORE_PATH"

if ! command -v prettier &> /dev/null; then
    echo "Error: prettier is not installed"
    exit 1
fi

if [ -f "$IGNORE_PATH" ]; then
    prettier --write "$FILES_PATTERN" --ignore-path "$IGNORE_PATH" --plugin prettier-plugin-sh
else
    prettier --write "$FILES_PATTERN" --plugin prettier-plugin-sh
fi

echo "File formatting completed successfully"