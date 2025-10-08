#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "::error::Usage: $0 <raw_changelog> <version>"
  exit 1
fi

raw_changelog="$1"
version="$2"

if [ -z "$raw_changelog" ]; then
  echo "::error::Empty changelog provided"
  exit 1
fi

sanitize_text() {
  local text="$1"
  text="${text//\`/\\\`}"
  printf "%s" "$text"
}

if [[ "$raw_changelog" == "No changes in this release." ]]; then
  formatted="What's New in v${version}\n\nNo changes in this release."
else
  formatted="What's New in v${version}\n\n"

  while IFS= read -r line; do
    line=$(sanitize_text "$line")

    if [[ "$line" =~ ^[A-Z] ]] && [[ ! "$line" =~ ^[A-Za-z]+: ]]; then
      formatted+="\n${line}:\n"
    elif [ -n "$line" ]; then
      formatted+="• ${line}\n"
    fi
  done <<< "$raw_changelog"
fi

{
  echo "changelog_plain<<EOF"
  printf "%b" "$formatted"
  echo ""
  echo "EOF"
} >> "$GITHUB_OUTPUT"
