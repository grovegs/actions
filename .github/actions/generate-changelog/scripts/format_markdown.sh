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

if [[ "$raw_changelog" == "No changes in this release." ]]; then
    formatted="## 🚀 Release Notes v${version}\n\nNo changes in this release."
else
    formatted="## 🚀 Release Notes v${version}\n\n"
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[A-Z] ]] && [[ ! "$line" =~ ^[A-Za-z]+: ]]; then
            case "$line" in
                "Features") formatted+="### 🚀 Features\n" ;;
                "Bug Fixes") formatted+="### 🐞 Bug Fixes\n" ;;
                "Chores") formatted+="### 🧹 Chores\n" ;;
                "Refactors") formatted+="### 🔨 Refactors\n" ;;
                "Tests") formatted+="### 🧪 Tests\n" ;;
                "CI/CD") formatted+="### 🔧 CI/CD\n" ;;
                "Reverts") formatted+="### ⏪ Reverts\n" ;;
                "Documentations") formatted+="### 📚 Documentations\n" ;;
                *) formatted+="### ${line}\n" ;;
            esac
        elif [ -n "$line" ]; then
            formatted+="- ${line}\n"
        fi
    done <<< "$raw_changelog"
fi

{
    echo "changelog_markdown<<EOF"
    echo -e "$formatted"
    echo "EOF"
} >> "$GITHUB_OUTPUT"