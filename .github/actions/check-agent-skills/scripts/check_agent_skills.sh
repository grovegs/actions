#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SKILLS_PATH:-}" ]; then
  echo "::error::SKILLS_PATH environment variable is required"
  exit 1
fi

if [ ! -d "${SKILLS_PATH}" ]; then
  echo "::error::Directory '${SKILLS_PATH}' does not exist"
  exit 1
fi

SKILLS_PATH="${SKILLS_PATH%/}"
PROBLEMS=0
CHECKED=0

report() {
  local file="$1"
  local message="$2"

  echo "::error file=${file}::${file}: ${message}"
  PROBLEMS=$((PROBLEMS + 1))
}

read_value() {
  local front_matter="$1"
  local key="$2"

  printf '%s\n' "${front_matter}" | sed -n "s/^${key}:[[:space:]]*//p" | head -n 1 | sed 's/[[:space:]]*$//'
}

check_plain_scalar() {
  local file="$1"
  local key="$2"
  local value="$3"

  case "${value}" in
    \"*\" | \'*\')
      return 0
      ;;
    [\[\{\&\*\!\|\>\%\@\`\"\'\#]* | -\ * | \?\ *)
      report "${file}" "${key} starts with a character YAML reads as syntax. Put the value in double quotes."
      return 0
      ;;
  esac

  case "${value}" in
    *": "* | *:)
      report "${file}" "${key} contains a colon followed by a space, which YAML reads as a new key. Reword it or put the value in double quotes."
      ;;
    *" #"*)
      report "${file}" "${key} contains ' #', which YAML reads as a comment. Reword it or put the value in double quotes."
      ;;
  esac
}

check_skill() {
  local file="$1"
  local directory
  local first_line
  local closing_line
  local front_matter
  local name
  local description

  directory="$(basename "$(dirname "${file}")")"
  first_line="$(head -n 1 "${file}" | tr -d '\r')"

  if [ "${first_line}" != "---" ]; then
    report "${file}" "the first line must be '---' to open the front matter."
    return 0
  fi

  closing_line="$(tail -n +2 "${file}" | tr -d '\r' | grep -n -m 1 '^---$' | cut -d: -f1 || true)"

  if [ -z "${closing_line}" ]; then
    report "${file}" "the front matter is never closed with a '---' line."
    return 0
  fi

  front_matter="$(tail -n +2 "${file}" | head -n "$((closing_line - 1))" | tr -d '\r')"
  name="$(read_value "${front_matter}" "name")"
  description="$(read_value "${front_matter}" "description")"

  if [ -z "${name}" ]; then
    report "${file}" "the front matter has no name."
  elif ! printf '%s' "${name}" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    report "${file}" "name '${name}' must be lowercase letters, digits and single hyphens."
  elif [ "${#name}" -gt 64 ]; then
    report "${file}" "name is ${#name} characters long. The limit is 64."
  elif [ "${name}" != "${directory}" ]; then
    report "${file}" "name '${name}' must match its folder '${directory}'."
  fi

  if [ -z "${description}" ]; then
    report "${file}" "the front matter has no description on one line."
  elif [ "${#description}" -gt 1024 ]; then
    report "${file}" "description is ${#description} characters long. The limit is 1024."
  else
    check_plain_scalar "${file}" "description" "${description}"
  fi
}

while IFS= read -r -d '' skill; do
  CHECKED=$((CHECKED + 1))
  check_skill "${skill}"
done < <(find "${SKILLS_PATH}" \( -name '.git' -o -name 'node_modules' -o -name 'Library' \) -prune -o -type f -name 'SKILL.md' -print0)

if [ "${CHECKED}" -eq 0 ]; then
  echo "::notice::No SKILL.md files found in '${SKILLS_PATH}'"
  exit 0
fi

if [ "${PROBLEMS}" -gt 0 ]; then
  echo "::error::Found ${PROBLEMS} skill problem(s) in '${SKILLS_PATH}'"
  exit 1
fi

echo "::notice::✓ All ${CHECKED} skill(s) in '${SKILLS_PATH}' have a loadable front matter"
