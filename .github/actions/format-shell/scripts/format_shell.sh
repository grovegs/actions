#!/bin/bash

set -e

SEARCH_PATH="$1"
EXCLUDE_PATHS="$2"

echo "Formatting shell scripts in: $SEARCH_PATH"
echo "Excluding paths: $EXCLUDE_PATHS"

if ! command -v shfmt &> /dev/null; then
    echo "shfmt not found in PATH, checking npm global bin..."

    if command -v npm &> /dev/null; then
        NPM_BIN="$(npm prefix -g)/bin"
        if [ -x "$NPM_BIN/shfmt" ]; then
            echo "Found shfmt in npm global bin: $NPM_BIN/shfmt"
            export PATH="$NPM_BIN:$PATH"
        fi
    fi

    if ! command -v shfmt &> /dev/null; then
        echo "Error: shfmt is not installed or not accessible"
        echo "PATH: $PATH"
        echo "Checking common locations:"
        ls -la /usr/local/bin/shfmt 2>/dev/null || echo "  Not in /usr/local/bin/"
        ls -la "$(npm prefix -g 2>/dev/null)/bin/shfmt" 2>/dev/null || echo "  Not in npm global bin"
        exit 1
    fi
fi

FIND_CMD="find $SEARCH_PATH -name '*.sh'"

if [ -n "$EXCLUDE_PATHS" ]; then
    IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_PATHS"
    for exclude in "${EXCLUDE_ARRAY[@]}"; do
        FIND_CMD="$FIND_CMD -not -path '$exclude/*'"
    done
fi

eval "$FIND_CMD" | while read -r file; do
    echo "Formatting: $file"
    shfmt -w -i 2 -ci "$file"
done

echo "Shell script formatting completed successfully"