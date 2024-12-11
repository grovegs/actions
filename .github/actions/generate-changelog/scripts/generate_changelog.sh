#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <latest_version> <next_version>"
    exit 1
fi

latest_version=$1
next_version=$2

if ! git rev-parse "${latest_version}" >/dev/null 2>&1; then
    echo "Error: Tag '${latest_version}' does not exist."
    exit 1
fi

if ! git rev-parse "${next_version}" >/dev/null 2>&1; then
    echo "Error: Tag '${next_version}' does not exist."
    exit 1
fi

# Define categories and their corresponding emojis
categories=("🚀 Features" "🐞 Bug Fixes" "🧹 Chores" "🔨 Refactors" "🧪 Tests" "🔧 CI/CD" "⏪ Reverts")
commits_by_category=()

# Initialize commits_by_category with empty strings
for i in "${!categories[@]}"; do
    commits_by_category[i]=""
done

commits=$(git log "${latest_version}..${next_version}" --pretty=format:"%s")

while IFS= read -r commit; do
    commit=$(echo "${commit}" | sed -E 's/ \(#[0-9]+\)$//')
    branch_type=$(echo "${commit}" | grep -oE '^(feat|fix|fixes|hotfix|chore|docs|refactor|style|perf|test|build|ci|revert)(\([^)]+\))?:' | sed -E 's/\(.*\):$|:$//')

    if [ -n "${branch_type}" ]; then
        branch_type=${branch_type%:}
    else
        continue
    fi

    case ${branch_type} in
    feat) category_index=0 ;;
    fix) category_index=1 ;;
    chore) category_index=2 ;;
    refactor) category_index=3 ;;
    test) category_index=4 ;;
    ci | build) category_index=5 ;;
    revert) category_index=6 ;;
    *) continue ;;
    esac

    context=$(echo "${commit}" | grep -oE '\(.*\)' | tr -d '()')
    short_desc=$(echo "${commit}" | sed -E 's/^[a-z]+(\([a-z]+\))?: //')

    if [ -n "${context}" ]; then
        formatted_commit="${context}: ${short_desc}"
    else
        formatted_commit="${short_desc}"
    fi

    commits_by_category[category_index]+="- ${formatted_commit}"$'\n'
done <<<"${commits}"

# Generate Markdown changelog
changelog=""
for i in "${!categories[@]}"; do
    if [ -n "${commits_by_category[${i}]}" ]; then
        category_name=${categories[${i}]}
        changelog+="# ${category_name}"$'\n\n'"${commits_by_category[${i}]}"$'\n'
    fi
done

echo -e "${changelog}"
