#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RAW_CHANGELOG:-}" ]; then
  echo "::error::RAW_CHANGELOG environment variable is required"
  exit 1
fi

if [ -z "${VERSION:-}" ]; then
  echo "::error::VERSION environment variable is required"
  exit 1
fi

sanitize_text() {
  local text="$1"
  text="${text//\`/\\\`}"
  printf "%s" "${text}"
}

if [[ "${RAW_CHANGELOG}" == "No changes in this release." ]]; then
  formatted="## Release Notes v${VERSION}\n\nNo changes in this release."
else
  formatted="## Release Notes v${VERSION}\n\n"

  while IFS= read -r line; do
    line=$(sanitize_text "${line}")

    if [[ "${line}" =~ ^[A-Z] ]] && [[ ! "${line}" =~ ^[A-Za-z]+: ]]; then
      case "${line}" in
        "Features") formatted+="### 🚀 Features\n" ;;
        "Bug Fixes") formatted+="### 🐞 Bug Fixes\n" ;;
        "Chores") formatted+="### 🧹 Chores\n" ;;
        "Refactors") formatted+="### 🔨 Refactors\n" ;;
        "Tests") formatted+="### 🧪 Tests\n" ;;
        "CI/CD") formatted+="### 🔧 CI/CD\n" ;;
        "Reverts") formatted+="### ⏪ Reverts\n" ;;
        "Documentation") formatted+="### 📚 Documentation\n" ;;
        "Other") formatted+="### 📦 Other\n" ;;
        *) formatted+="- ${line}\n" ;;
      esac
    elif [ -n "${line}" ]; then
      formatted+="- ${line}\n"
    fi
  done <<< "${RAW_CHANGELOG}"
fi

{
  echo "changelog-markdown<<EOF"
  printf "%b" "${formatted}"
  echo ""
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
