#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "::error::Usage: $0 <next_version>"
    exit 1
fi

next_version=$1

latest_version=$(git describe --tags --abbrev=0)
if [ $? -ne 0 ]; then
    echo "::error::Failed to get latest version tag"
    exit 1
fi

echo "::notice::Generating changelog from ${latest_version} to ${next_version}"

categories=("🚀 Features" "🐞 Bug Fixes" "🧹 Chores" "🔨 Refactors" "🧪 Tests" "🔧 CI/CD" "⏪ Reverts")
commits_by_category=()

for i in "${!categories[@]}"; do
    commits_by_category[i]=""
done

commits=$(git log "${latest_version}..HEAD" --pretty=format:"%s")
if [ -z "$commits" ]; then
    echo "::warning::No commits found between ${latest_version} and HEAD"
fi

while IFS= read -r commit; do
    commit=$(echo "${commit}" | sed -E 's/ \(#[0-9]+\)$//')
    commit_type=$(echo "${commit}" | grep -oE '^(feat|fix|fixes|hotfix|chore|docs|refactor|style|perf|test|build|ci|revert)(\([^)]+\))?:' | sed -E 's/\(.*\):$|:$//')

    if [ -n "${commit_type}" ]; then
        commit_type=${commit_type%:}
    else
        echo "::warning::Skipping commit with invalid format: ${commit}"
        continue
    fi

    case ${commit_type} in
    feat) category_index=0 ;;
    fix) category_index=1 ;;
    chore) category_index=2 ;;
    refactor) category_index=3 ;;
    test) category_index=4 ;;
    ci | build) category_index=5 ;;
    revert) category_index=6 ;;
    *)
        echo "::warning::Unknown commit type: ${commit_type}"
        continue
        ;;
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

title="# 📝 Changelog: ${latest_version} → ${next_version}"
changelog="${title}"$'\n\n'
for i in "${!categories[@]}"; do
    if [ -n "${commits_by_category[i]}" ]; then
        category_name=${categories[i]}
        changelog+="## ${category_name}"$'\n\n'"${commits_by_category[i]}"$'\n'
    fi
done

{
    echo "changelog<<EOF"
    echo "$changelog"
    echo "EOF"
} >>"$GITHUB_OUTPUT"

echo "::notice::Changelog generated successfully"
