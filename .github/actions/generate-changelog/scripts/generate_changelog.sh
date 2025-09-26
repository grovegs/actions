#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "::error::Usage: $0 <next_version>"
    exit 1
fi

next_version=$1
current_branch=$(git rev-parse --abbrev-ref HEAD)

latest_version=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")

if [ -z "$latest_version" ]; then
    echo "::notice::No tags found in current branch history. Generating changelog from initial commit."
    commits=$(git log --pretty=format:"%s")
    comparison_range="initial commit to HEAD"
else
    echo "::notice::Generating changelog from ${latest_version} to ${next_version} on branch ${current_branch}"
    commits=$(git log "${latest_version}..HEAD" --pretty=format:"%s")
    comparison_range="${latest_version} to HEAD"
fi

if [ -z "$commits" ]; then
    echo "::warning::No commits found in range: ${comparison_range}"
    changelog="## 📝 Changelog (${current_branch})"$'\n\n'"No changes in this release."
    {
        echo "changelog<<EOF"
        echo "$changelog"
        echo "EOF"
    } >>"$GITHUB_OUTPUT"
    exit 0
fi

categories=("🚀 Features" "🐞 Bug Fixes" "🧹 Chores" "🔨 Refactors" "🧪 Tests" "🔧 CI/CD" "⏪ Reverts" "📚 Documentations")
commits_by_category=()

for i in "${!categories[@]}"; do
    commits_by_category[i]=""
done

while IFS= read -r commit; do
    commit=$(echo "${commit}" | sed -E 's/ \(#[0-9]+\)$//')
    commit_type=$(echo "${commit}" | grep -oE '^(feat|fix|fixes|hotfix|chore|style|docs|refactor|perf|test|ci|build|revert)(\([^)]+\))?:' | sed -E 's/\(.*\):$|:$//')

    if [ -n "${commit_type}" ]; then
        commit_type=${commit_type%:}
    else
        echo "::notice::Skipping commit with invalid format: ${commit}"
        continue
    fi

    case ${commit_type} in
    feat) category_index=0 ;;
    fix | fixes | hotfix) category_index=1 ;;
    chore | style) category_index=2 ;;
    refactor | perf) category_index=3 ;;
    test) category_index=4 ;;
    ci | build) category_index=5 ;;
    revert) category_index=6 ;;
    docs) category_index=7 ;;
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

title="## 📝 Changelog (${current_branch})"
changelog="${title}"$'\n\n'
for i in "${!categories[@]}"; do
    if [ -n "${commits_by_category[i]}" ]; then
        category_name=${categories[i]}
        changelog+="### ${category_name}"$'\n\n'"${commits_by_category[i]}"$'\n'
    fi
done

{
    echo "changelog<<EOF"
    echo "$changelog"
    echo "EOF"
} >>"$GITHUB_OUTPUT"

echo "::notice::Changelog generated successfully"