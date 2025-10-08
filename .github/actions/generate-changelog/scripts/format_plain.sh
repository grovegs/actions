#!/bin/bash

if [ -z "$RAW_CHANGELOG" ]; then
  echo "::error::Empty changelog provided"
  exit 1
fi

if [ -z "$VERSION" ]; then
  echo "::error::Version not provided"
  exit 1
fi

sanitize_text() {
  local text="$1"
  text="${text//\`/\\\`}"
  printf "%s" "$text"
}

if [[ "$RAW_CHANGELOG" == "No changes in this release." ]]; then
  formatted="What's New in v${VERSION}\n\nNo changes in this release."
else
  formatted="What's New in v${VERSION}\n\n"

  while IFS= read -r line; do
    line=$(sanitize_text "$line")

    if [[ "$line" =~ ^[A-Z] ]] && [[ ! "$line" =~ ^[A-Za-z]+: ]]; then
      formatted+="\n${line}:\n"
    elif [ -n "$line" ]; then
      formatted+="• ${line}\n"
    fi
  done <<< "$RAW_CHANGELOG"
fi

{
  echo "changelog_plain<<EOF"
  printf "%b" "$formatted"
  echo ""
  echo "EOF"
} >> "$GITHUB_OUTPUT"
