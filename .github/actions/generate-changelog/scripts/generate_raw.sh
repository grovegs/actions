#!/bin/bash

if ! command -v git >/dev/null 2>&1; then
    echo "::error::Git is not installed or not in PATH"
    exit 1
fi

latest_version=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")

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

categories=("Features" "Bug Fixes" "Chores" "Refactors" "Tests" "CI/CD" "Reverts" "Documentations")
commits_by_category=()

for i in "${!categories[@]}"; do
    commits_by_category[i]=""
done

while IFS= read -r commit; do
    commit=$(echo "$commit" | sed 's/ (#[0-9][0-9]*)\$//')
    
    commit_type=""
    if echo "$commit" | grep -q '^feat[:(]'; then
        commit_type="feat"
    elif echo "$commit" | grep -q '^fix[:(]'; then
        commit_type="fix"
    elif echo "$commit" | grep -q '^fixes[:(]'; then
        commit_type="fixes"
    elif echo "$commit" | grep -q '^hotfix[:(]'; then
        commit_type="hotfix"
    elif echo "$commit" | grep -q '^chore[:(]'; then
        commit_type="chore"
    elif echo "$commit" | grep -q '^style[:(]'; then
        commit_type="style"
    elif echo "$commit" | grep -q '^docs[:(]'; then
        commit_type="docs"
    elif echo "$commit" | grep -q '^refactor[:(]'; then
        commit_type="refactor"
    elif echo "$commit" | grep -q '^perf[:(]'; then
        commit_type="perf"
    elif echo "$commit" | grep -q '^test[:(]'; then
        commit_type="test"
    elif echo "$commit" | grep -q '^ci[:(]'; then
        commit_type="ci"
    elif echo "$commit" | grep -q '^build[:(]'; then
        commit_type="build"
    elif echo "$commit" | grep -q '^revert[:(]'; then
        commit_type="revert"
    else
        continue
    fi

    case $commit_type in
    feat) category_index=0 ;;
    fix | fixes | hotfix) category_index=1 ;;
    chore | style) category_index=2 ;;
    refactor | perf) category_index=3 ;;
    test) category_index=4 ;;
    ci | build) category_index=5 ;;
    revert) category_index=6 ;;
    docs) category_index=7 ;;
    *) continue ;;
    esac

    context=$(echo "$commit" | grep -o '([^)]*)')
    context=${context#(}
    context=${context%)}
    
    short_desc=$(echo "$commit" | sed 's/^[a-z]*[:(][^:]*: *//')
    short_desc=$(echo "$short_desc" | sed 's/^[a-z]*: *//')

    if [ -n "$context" ]; then
        formatted_commit="${context}: ${short_desc}"
    else
        formatted_commit="$short_desc"
    fi

    commits_by_category[category_index]+="${formatted_commit}"$'\n'
done <<< "$commits"

changelog=""
for i in "${!categories[@]}"; do
    if [ -n "${commits_by_category[i]}" ]; then
        category_name=${categories[i]}
        changelog+="${category_name}"$'\n'"${commits_by_category[i]}"$'\n'
    fi
done

{
    echo "changelog_raw<<EOF"
    printf "%s" "$changelog"
    echo "EOF"
} >> "$GITHUB_OUTPUT"