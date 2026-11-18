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
BOM=$(printf '\357\273\277')
TAB=$(printf '\t')

report() {
  local file="$1"
  local message="$2"

  echo "::error file=${file}::${file}: ${message}"
  PROBLEMS=$((PROBLEMS + 1))
}

strip_comment() {
  local value="$1"

  case "${value}" in
    *" #"*) value="${value%% #*}" ;;
  esac

  printf '%s' "${value}" | sed 's/[[:space:]]*$//'
}

check_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local text_only="$4"

  case "${value}" in
    "")
      return 0
      ;;
    \"*)
      if ! printf '%s' "${value}" | grep -Eq '^"([^"\\]|\\["\\/bfnrt0 ]|\\u[0-9A-Fa-f]{4})*"([[:space:]]+#.*)?$'; then
        report "${file}" "${key} has a double-quoted value that does not close cleanly. Escape inner quotes as \\\" and end the value with one quote."
      fi
      return 0
      ;;
    \'*)
      if ! printf '%s' "${value}" | grep -Eq "^'([^']|'')*'([[:space:]]+#.*)?\$"; then
        report "${file}" "${key} has a single-quoted value that does not close cleanly. Write an inner quote as two single quotes."
      fi
      return 0
      ;;
    "|"* | ">"*)
      return 0
      ;;
    "["* | "{"*)
      if [ "${text_only}" = "true" ]; then
        report "${file}" "${key} starts with a character YAML reads as a list or a map. Put the value in double quotes."
      fi
      return 0
      ;;
    [\&\*\!\%\@\`\#]* | "- "* | "? "*)
      report "${file}" "${key} starts with a character YAML reads as syntax. Put the value in double quotes."
      return 0
      ;;
  esac

  case "${value}" in
    *": "* | *":${TAB}"* | *:)
      report "${file}" "${key} contains a colon followed by a space, which YAML reads as a new key. Reword it or put the value in double quotes."
      ;;
  esac
}

unquote() {
  local value="$1"

  case "${value}" in
    \"*\") value="${value#\"}" && value="${value%\"}" ;;
    \'*\') value="${value#\'}" && value="${value%\'}" ;;
  esac

  printf '%s' "${value}"
}

check_skill() {
  local file="$1"
  local directory
  local first_line
  local closing_line
  local front_matter
  local line
  local key
  local value
  local name=""
  local description=""
  local has_name="false"
  local has_description="false"
  local pending_block=""

  directory="$(basename "$(dirname "${file}")")"
  first_line="$(awk 'NR == 1 { sub(/\r$/, ""); print; exit }' "${file}")"
  first_line="${first_line#"${BOM}"}"

  if [ "${first_line}" != "---" ]; then
    report "${file}" "the first line must be '---' to open the front matter."
    return 0
  fi

  closing_line="$(awk 'NR > 1 { sub(/\r$/, ""); if ($0 ~ /^---[[:space:]]*$/) { print NR; exit } }' "${file}")"

  if [ -z "${closing_line}" ]; then
    report "${file}" "the front matter is never closed with a '---' line."
    return 0
  fi

  front_matter="$(awk -v last="${closing_line}" 'NR > 1 && NR < last { sub(/\r$/, ""); print }' "${file}")"

  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      "${TAB}"*)
        report "${file}" "a front matter line starts with a tab. YAML indents with spaces."
        continue
        ;;
      "" | "#"*)
        continue
        ;;
      " "*)
        if [ -n "${pending_block}" ] && [ -n "$(printf '%s' "${line}" | tr -d '[:space:]')" ]; then
          if [ "${pending_block}" = "description" ]; then
            description="block"
          fi
          pending_block=""
        fi
        continue
        ;;
    esac

    if [ "${pending_block}" = "description" ]; then
      report "${file}" "description has no text."
    fi
    pending_block=""

    if ! printf '%s' "${line}" | grep -Eq '^[A-Za-z0-9_-]+[[:space:]]*:([[:space:]]|$)'; then
      report "${file}" "'${line}' is not a 'key: value' line. A key needs a colon and a space before its value."
      continue
    fi

    key="$(printf '%s' "${line}" | sed -E 's/^([A-Za-z0-9_-]+)[[:space:]]*:.*$/\1/')"
    value="$(printf '%s' "${line}" | sed -E 's/^[A-Za-z0-9_-]+[[:space:]]*:[[:space:]]*//' | sed 's/[[:space:]]*$//')"

    case "${key}" in
      name)
        has_name="true"
        check_value "${file}" "name" "${value}" "true"
        name="$(unquote "$(strip_comment "${value}")")"
        ;;
      description)
        has_description="true"
        check_value "${file}" "description" "${value}" "true"
        case "${value}" in
          "" | "|"* | ">"*) pending_block="description" ;;
          *) description="${value}" ;;
        esac
        ;;
      *)
        check_value "${file}" "${key}" "${value}" "false"
        ;;
    esac
  done <<< "${front_matter}"

  if [ "${pending_block}" = "description" ]; then
    report "${file}" "description has no text."
    description="reported"
  fi

  if [ "${has_name}" = "false" ] || [ -z "${name}" ]; then
    report "${file}" "the front matter has no name."
  elif ! printf '%s' "${name}" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    report "${file}" "name '${name}' must be lowercase letters, digits and single hyphens."
  elif [ "${#name}" -gt 64 ]; then
    report "${file}" "name is ${#name} characters long. The limit is 64."
  elif [ "${name}" != "${directory}" ]; then
    report "${file}" "name '${name}' must match its folder '${directory}'."
  fi

  if [ "${has_description}" = "false" ]; then
    report "${file}" "the front matter has no description."
  elif [ -z "${description}" ]; then
    report "${file}" "description has no text."
  elif [ "${#description}" -gt 1024 ]; then
    report "${file}" "description is ${#description} characters long. The limit is 1024."
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

echo "::notice::✓ All ${CHECKED} skill(s) in '${SKILLS_PATH}' have a front matter that passes the checks"
