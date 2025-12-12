#!/usr/bin/env bash
set -euo pipefail

if ! command -v git > /dev/null 2>&1; then
  echo "::error::Git is not installed or not in PATH"
  exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "::error::jq is not installed or not in PATH"
  exit 1
fi

latest_version=$(git tag --merged HEAD --sort=-version:refname | head -n 1 2> /dev/null || echo "")

if [ -z "${latest_version}" ]; then
  commits=$(git log --pretty=format:"%s")
else
  commits=$(git log "${latest_version}..HEAD" --pretty=format:"%s")
fi

declare -a features=()
declare -a fixes=()
declare -a chores=()
declare -a refactors=()
declare -a perf=()
declare -a tests=()
declare -a ci=()
declare -a reverts=()
declare -a docs=()
declare -a other=()

clean_commit() {
  local commit="$1"
  commit=$(printf "%s" "${commit}" | sed 's/^[^a-zA-Z]*//')
  commit=$(printf "%s" "${commit}" | sed 's/[[:space:]]\{1,\}/ /g')
  commit=$(printf "%s" "${commit}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  printf "%s" "${commit}"
}

get_commit_type() {
  local commit="$1"
  local commit_lower
  commit_lower=$(printf "%s" "${commit}" | tr '[:upper:]' '[:lower:]')

  case "${commit_lower}" in
    feat\(* | feat:* | feat\[*) printf "feat" ;;
    fix\(* | fix:* | fix\[* | fixes\(* | fixes:* | fixes\[* | hotfix\(* | hotfix:* | hotfix\[*) printf "fix" ;;
    perf\(* | perf:* | perf\[*) printf "perf" ;;
    chore\(* | chore:* | chore\[* | style\(* | style:* | style\[*) printf "chore" ;;
    docs\(* | docs:* | docs\[* | doc\(* | doc:* | doc\[*) printf "docs" ;;
    refactor\(* | refactor:* | refactor\[*) printf "refactor" ;;
    test\(* | test:* | test\[* | tests\(* | tests:* | tests\[*) printf "test" ;;
    ci\(* | ci:* | ci\[* | build\(* | build:* | build\[*) printf "ci" ;;
    revert\(* | revert:* | revert\[*) printf "revert" ;;
    *) printf "" ;;
  esac
}

parse_commit() {
  local commit="$1"
  local commit_type="$2"
  local scope=""
  local description=""
  local remaining

  case "${commit_type}" in
    feat)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^[Ff][Ee][Aa][Tt]//')
      ;;
    fix)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^([Ff][Ii][Xx][Ee]*[Ss]*|[Hh][Oo][Tt][Ff][Ii][Xx])//')
      ;;
    perf)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^[Pp][Ee][Rr][Ff]//')
      ;;
    chore)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^([Cc][Hh][Oo][Rr][Ee]|[Ss][Tt][Yy][Ll][Ee])//')
      ;;
    docs)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^[Dd][Oo][Cc][Ss]*//')
      ;;
    refactor)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^[Rr][Ee][Ff][Aa][Cc][Tt][Oo][Rr]//')
      ;;
    test)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^[Tt][Ee][Ss][Tt][Ss]*//')
      ;;
    ci)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^([Cc][Ii]|[Bb][Uu][Ii][Ll][Dd])//')
      ;;
    revert)
      remaining=$(printf "%s" "${commit}" | sed -E 's/^[Rr][Ee][Vv][Ee][Rr][Tt]//')
      ;;
    *)
      remaining="${commit}"
      ;;
  esac

  if printf "%s" "${remaining}" | grep -qE '^[\[\(]([^\]\)]+)[\]\)]:'; then
    scope=$(printf "%s" "${remaining}" | sed -E 's/^[\[\(]([^\]\)]+)[\]\)]:.*/\1/')
    description=$(printf "%s" "${remaining}" | sed -E 's/^[\[\(][^\]\)]+[\]\)]:[[:space:]]*//')
  elif printf "%s" "${remaining}" | grep -qE '^:'; then
    description=$(printf "%s" "${remaining}" | sed -E 's/^:[[:space:]]*//')
  else
    description="${remaining}"
  fi

  if [ -n "${scope}" ]; then
    scope=$(printf "%s" "${scope}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  fi

  description=$(printf "%s" "${description}" | sed -E 's/^[[:space:]]*//;s/[[:space:]]*\(#[0-9]+\)[[:space:]]*$//;s/[[:space:]]*$//')

  if [ -n "${description}" ]; then
    local first_char
    local rest_chars
    first_char=$(printf "%s" "${description}" | cut -c1)
    rest_chars=$(printf "%s" "${description}" | cut -c2-)
    case "${first_char}" in
      [A-Z]) description="$(printf "%s" "${first_char}" | tr '[:upper:]' '[:lower:]')${rest_chars}" ;;
    esac
  fi

  if [ -n "${scope}" ] && [ -n "${description}" ]; then
    printf '{"scope":"%s","description":"%s"}' "${scope}" "${description}"
  elif [ -n "${description}" ]; then
    printf '{"scope":"","description":"%s"}' "${description}"
  else
    printf '{"scope":"","description":"%s"}' "${commit}"
  fi
}

while IFS= read -r commit; do
  [ -z "${commit}" ] && continue

  clean_commit_msg=$(clean_commit "${commit}")
  [ -z "${clean_commit_msg}" ] && continue

  commit_type=$(get_commit_type "${clean_commit_msg}")

  if [ -z "${commit_type}" ]; then
    formatted_commit=$(printf '{"scope":"","description":"%s"}' "${clean_commit_msg}")
    other+=("${formatted_commit}")
  else
    formatted_commit=$(parse_commit "${clean_commit_msg}" "${commit_type}")

    case ${commit_type} in
      feat) features+=("${formatted_commit}") ;;
      fix) fixes+=("${formatted_commit}") ;;
      perf) perf+=("${formatted_commit}") ;;
      chore) chores+=("${formatted_commit}") ;;
      refactor) refactors+=("${formatted_commit}") ;;
      test) tests+=("${formatted_commit}") ;;
      ci) ci+=("${formatted_commit}") ;;
      revert) reverts+=("${formatted_commit}") ;;
      docs) docs+=("${formatted_commit}") ;;
    esac
  fi
done <<< "${commits}"

array_to_json() {
  local array_name=$1
  eval "local array_size=\${#${array_name}[@]}"

  if [ "$array_size" -eq 0 ]; then
    echo '[]'
  else
    eval "printf '%s\n' \"\${${array_name}[@]}\"" | jq -s 'map(fromjson)'
  fi
}

json_obj=$(jq -n \
  --argjson features "$(array_to_json features)" \
  --argjson fixes "$(array_to_json fixes)" \
  --argjson perf "$(array_to_json perf)" \
  --argjson chores "$(array_to_json chores)" \
  --argjson refactors "$(array_to_json refactors)" \
  --argjson tests "$(array_to_json tests)" \
  --argjson ci "$(array_to_json ci)" \
  --argjson reverts "$(array_to_json reverts)" \
  --argjson docs "$(array_to_json docs)" \
  --argjson other "$(array_to_json other)" \
  '{
    features: $features,
    fixes: $fixes,
    perf: $perf,
    chores: $chores,
    refactors: $refactors,
    tests: $tests,
    ci: $ci,
    reverts: $reverts,
    docs: $docs,
    other: $other
  }'
)

{
  echo "changelog-raw<<EOF"
  printf "%s" "${json_obj}"
  echo ""
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
