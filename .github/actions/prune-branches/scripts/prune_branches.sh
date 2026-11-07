#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GH_TOKEN:-}" ]; then
  echo "::error::GH_TOKEN environment variable is required"
  exit 1
fi

if [ -z "${REPOSITORY:-}" ]; then
  echo "::error::REPOSITORY environment variable is required"
  exit 1
fi

STALE_DAYS="${STALE_DAYS:-0}"
DRY_RUN="${DRY_RUN:-false}"

if ! printf "%s" "${STALE_DAYS}" | grep -qE '^[0-9]+$'; then
  echo "::error::STALE_DAYS must be a whole number of days, got '${STALE_DAYS}'"
  exit 1
fi

if [ "${DRY_RUN}" != "true" ] && [ "${DRY_RUN}" != "false" ]; then
  echo "::error::DRY_RUN must be true or false, got '${DRY_RUN}'"
  exit 1
fi

OWNER="${REPOSITORY%%/*}"

declare -a EXCLUDE_PATTERNS=()
while IFS= read -r pattern; do
  pattern="${pattern#"${pattern%%[![:space:]]*}"}"
  pattern="${pattern%"${pattern##*[![:space:]]}"}"
  if [ -n "${pattern}" ]; then
    EXCLUDE_PATTERNS+=("${pattern}")
  fi
done <<< "${EXCLUDE_BRANCHES:-}"

is_excluded() {
  local branch="$1"
  local pattern

  for pattern in ${EXCLUDE_PATTERNS[@]+"${EXCLUDE_PATTERNS[@]}"}; do
    # shellcheck disable=SC2053
    if [[ "${branch}" == ${pattern} ]]; then
      return 0
    fi
  done

  return 1
}

DEFAULT_BRANCH=$(gh api "repos/${REPOSITORY}" --jq '.default_branch')
BRANCHES=$(gh api "repos/${REPOSITORY}/branches?per_page=100" --paginate --jq '.[] | select(.protected | not) | [.name, .commit.sha] | @tsv')

declare -a DELETED=()
declare -a FAILED=()
declare -a SUMMARY_ROWS=()

while IFS=$'\t' read -r branch sha; do
  if [ -z "${branch}" ] || [ "${branch}" = "${DEFAULT_BRANCH}" ] || is_excluded "${branch}"; then
    continue
  fi

  pull_requests=$(gh api -X GET "repos/${REPOSITORY}/pulls" \
    -f head="${OWNER}:${branch}" \
    -f state=all \
    -f per_page=100 \
    --jq "[([.[] | select(.state == \"open\")] | length), ([.[] | select(.merged_at != null and .head.sha == \"${sha}\")] | length)] | @tsv")
  open_count=$(printf "%s" "${pull_requests}" | cut -f1)
  merged_count=$(printf "%s" "${pull_requests}" | cut -f2)

  if [ "${open_count}" -gt 0 ]; then
    continue
  fi

  reason=""
  if [ "${merged_count}" -gt 0 ]; then
    reason="merged"
  elif [ "${STALE_DAYS}" -gt 0 ]; then
    age_days=$(gh api "repos/${REPOSITORY}/commits/${sha}" --jq '(now - (.commit.committer.date | fromdateiso8601)) / 86400 | floor')
    if [ "${age_days}" -ge "${STALE_DAYS}" ]; then
      reason="stale for ${age_days} days"
    fi
  fi

  if [ -z "${reason}" ]; then
    continue
  fi

  if [ "${DRY_RUN}" = "true" ]; then
    echo "Would delete ${branch} (${reason})"
  elif gh api -X DELETE "repos/${REPOSITORY}/git/refs/heads/${branch}" > /dev/null; then
    echo "Deleted ${branch} (${reason})"
  else
    echo "::warning::Could not delete ${branch}"
    FAILED+=("${branch}")
    continue
  fi

  DELETED+=("${branch}")
  SUMMARY_ROWS+=("| \`${branch}\` | ${reason} |")
done <<< "${BRANCHES}"

{
  echo "deleted-branches<<EOF"
  for branch in ${DELETED[@]+"${DELETED[@]}"}; do
    echo "${branch}"
  done
  echo "EOF"
} >> "${GITHUB_OUTPUT}"

if [ "${DRY_RUN}" = "true" ]; then
  HEADING="Branches that would be deleted"
else
  HEADING="Deleted branches"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### 🧹 ${HEADING}"
    echo ""
    if [ ${#DELETED[@]} -eq 0 ]; then
      echo "None."
    else
      echo "| Branch | Reason |"
      echo "| --- | --- |"
      for row in "${SUMMARY_ROWS[@]}"; do
        echo "${row}"
      done
    fi
  } >> "${GITHUB_STEP_SUMMARY}"
fi

echo "::notice::${HEADING}: ${#DELETED[@]}"

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "::error::Could not delete ${#FAILED[@]} branches: ${FAILED[*]}"
  exit 1
fi
