#!/bin/bash

if ! command -v git > /dev/null 2>&1; then
  echo "::error::Git is not installed or not in PATH"
  exit 1
fi

latest_version=$(git describe --tags --abbrev=0 HEAD 2> /dev/null || echo "")

if [ -z "$latest_version" ]; then
  commits=$(git log --pretty=format:"%s")
else
  commits=$(git log "${latest_version}..HEAD" --pretty=format:"%s")
fi

if [ -z "$commits" ]; then
  {
    echo "changelog_raw<<EOF"
    echo "No changes in this release."
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

categories=("Features" "Bug Fixes" "Chores" "Refactors" "Tests" "CI/CD" "Reverts" "Documentation" "Other")
declare -a commits_by_category

for i in "${!categories[@]}"; do
  commits_by_category[i]=""
done

clean_commit() {
  local commit="$1"

  commit=$(printf "%s" "$commit" | sed 's/^[^a-zA-Z]*//')

  commit=$(printf "%s" "$commit" | sed 's/[[:space:]]\{1,\}/ /g')

  commit=$(printf "%s" "$commit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  printf "%s" "$commit"
}

get_commit_type() {
  local commit="$1"
  local commit_lower
  commit_lower=$(printf "%s" "$commit" | tr '[:upper:]' '[:lower:]')

  case "$commit_lower" in
    feat\(* | feat:* | feat\[*) printf "feat" ;;
    fix\(* | fix:* | fix\[* | fixes\(* | fixes:* | fixes\[* | hotfix\(* | hotfix:* | hotfix\[*) printf "fix" ;;
    chore\(* | chore:* | chore\[* | style\(* | style:* | style\[*) printf "chore" ;;
    docs\(* | docs:* | docs\[* | doc\(* | doc:* | doc\[*) printf "docs" ;;
    refactor\(* | refactor:* | refactor\[* | perf\(* | perf:* | perf\[*) printf "refactor" ;;
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

  case "$commit_type" in
    feat)
      remaining=$(printf "%s" "$commit" | sed 's/^[Ff][Ee][Aa][Tt][\[\(:]*//')
      ;;
    fix)
      remaining=$(printf "%s" "$commit" | sed 's/^[Ff][Ii][Xx][Ee]*[Ss]*[\[\(:]*//' | sed 's/^[Hh][Oo][Tt][Ff][Ii][Xx][\[\(:]*//')
      ;;
    chore)
      remaining=$(printf "%s" "$commit" | sed 's/^[Cc][Hh][Oo][Rr][Ee][\[\(:]*//' | sed 's/^[Ss][Tt][Yy][Ll][Ee][\[\(:]*//')
      ;;
    docs)
      remaining=$(printf "%s" "$commit" | sed 's/^[Dd][Oo][Cc][Ss]*[\[\(:]*//')
      ;;
    refactor)
      remaining=$(printf "%s" "$commit" | sed 's/^[Rr][Ee][Ff][Aa][Cc][Tt][Oo][Rr][\[\(:]*//' | sed 's/^[Pp][Ee][Rr][Ff][\[\(:]*//')
      ;;
    test)
      remaining=$(printf "%s" "$commit" | sed 's/^[Tt][Ee][Ss][Tt][Ss]*[\[\(:]*//')
      ;;
    ci)
      remaining=$(printf "%s" "$commit" | sed 's/^[Cc][Ii][\[\(:]*//' | sed 's/^[Bb][Uu][Ii][Ll][Dd][\[\(:]*//')
      ;;
    revert)
      remaining=$(printf "%s" "$commit" | sed 's/^[Rr][Ee][Vv][Ee][Rr][Tt][\[\(:]*//')
      ;;
    *)
      remaining="$commit"
      ;;
  esac

  if printf "%s" "$remaining" | grep -q '):\|]:\|}:'; then
    scope=$(printf "%s" "$remaining" | sed 's/^\([^:)]*[)\]]\):.*$/\1/' | sed 's/[[\](){}]//g')
    description=$(printf "%s" "$remaining" | sed 's/^[^:)]*[)\]]:*[[:space:]]*//')
  elif printf "%s" "$remaining" | grep -q ':'; then
    description=$(printf "%s" "$remaining" | sed 's/^[^:]*:[[:space:]]*//')
  else
    description="$remaining"
  fi

  if [ -n "$scope" ]; then
    scope=$(printf "%s" "$scope" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    scope=$(printf "%s" "$scope" | sed 's/^[^a-zA-Z0-9]*//;s/[^a-zA-Z0-9]*$//')
  fi

  description=$(printf "%s" "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -n "$description" ]; then
    first_char=$(printf "%s" "$description" | cut -c1)
    rest_chars=$(printf "%s" "$description" | cut -c2-)
    case "$first_char" in
      [A-Z]) description="$(printf "%s" "$first_char" | tr '[:upper:]' '[:lower:]')$rest_chars" ;;
    esac
  fi

  if [ -n "$scope" ] && [ -n "$description" ]; then
    printf "%s: %s" "$scope" "$description"
  elif [ -n "$description" ]; then
    printf "%s" "$description"
  else
    printf "%s" "$commit"
  fi
}

while IFS= read -r commit; do
  [ -z "$commit" ] && continue

  clean_commit_msg=$(clean_commit "$commit")
  [ -z "$clean_commit_msg" ] && continue

  commit_type=$(get_commit_type "$clean_commit_msg")

  case $commit_type in
    feat) category_index=0 ;;
    fix) category_index=1 ;;
    chore) category_index=2 ;;
    refactor) category_index=3 ;;
    test) category_index=4 ;;
    ci) category_index=5 ;;
    revert) category_index=6 ;;
    docs) category_index=7 ;;
    *)
      category_index=8
      commit_type="other"
      ;;
  esac

  if [ "$commit_type" = "other" ]; then
    formatted_commit="$clean_commit_msg"
  else
    formatted_commit=$(parse_commit "$clean_commit_msg" "$commit_type")
  fi

  if [ -n "$formatted_commit" ]; then
    if [ -z "${commits_by_category[category_index]}" ]; then
      commits_by_category[category_index]="- ${formatted_commit}"
    else
      commits_by_category[category_index]="${commits_by_category[category_index]}
- ${formatted_commit}"
    fi
  fi
done <<< "$commits"

changelog=""
for i in "${!categories[@]}"; do
  if [ -n "${commits_by_category[i]}" ]; then
    category_name=${categories[i]}
    if [ -z "$changelog" ]; then
      changelog="## ${category_name}
${commits_by_category[i]}"
    else
      changelog="${changelog}

${commits_by_category[i]}"
    fi
  fi
done

{
  echo "changelog_raw<<EOF"
  if [ -n "$changelog" ]; then
    printf "%s\n" "$changelog"
  else
    echo "No changes in this release."
  fi
  echo "EOF"
} >> "$GITHUB_OUTPUT"
