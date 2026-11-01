#!/usr/bin/env bash
set -euo pipefail

if [ -z "${VERSION_TYPE:-}" ]; then
  echo "::error::VERSION_TYPE environment variable is required"
  exit 1
fi

case "${VERSION_TYPE}" in
  auto | major | minor | patch)
    echo "::notice::Version bump type: ${VERSION_TYPE}"
    ;;
  *)
    echo "::error::Invalid version-type: ${VERSION_TYPE}. Valid options: auto, major, minor, patch"
    exit 1
    ;;
esac

VERSION_SUFFIX="${VERSION_SUFFIX:-}"
AUTO_MAJOR="${AUTO_MAJOR:-true}"

if [ -n "${VERSION_SUFFIX}" ] && ! [[ "${VERSION_SUFFIX}" =~ ^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$ ]]; then
  echo "::error::Invalid version-suffix: ${VERSION_SUFFIX}. Use letters, digits, hyphens and dots, such as dev"
  exit 1
fi

case "${AUTO_MAJOR}" in
  true | false) ;;
  *)
    echo "::error::Invalid auto-major: ${AUTO_MAJOR}. Valid options: true, false"
    exit 1
    ;;
esac

VERSION_TAG_PATTERN='^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'

latest_version_tag() {
  grep -E "${VERSION_TAG_PATTERN}" \
    | awk '{ base = $0; sub(/^v/, "", base); sub(/-.*/, "", base); print base " " $0 }' \
    | sort -V \
    | tail -n 1 \
    | cut -d ' ' -f 2
}

echo "::notice::Fetching Git tags..."
if ! git fetch --tags --quiet 2> /dev/null; then
  echo "::warning::Could not fetch tags from remote"
fi

latest_tag=$(git tag -l 2> /dev/null | latest_version_tag || true)

if [ -z "${latest_tag}" ]; then
  LATEST_VERSION="0.0.0"
  echo "::notice::No version tags found, using default version: ${LATEST_VERSION}"
else
  LATEST_VERSION="${latest_tag#v}"
  echo "::notice::Latest version found: ${LATEST_VERSION}"
fi

LATEST_BASE_VERSION="${LATEST_VERSION%%-*}"

if [[ "${LATEST_BASE_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
else
  echo "::error::Invalid version format: ${LATEST_VERSION}. Expected format: X.Y.Z"
  exit 1
fi

previous_tag=$(git tag --merged HEAD 2> /dev/null | latest_version_tag || true)

if [ -n "${previous_tag}" ]; then
  range="${previous_tag}..HEAD"
  echo "::notice::Reading commits since ${previous_tag}"
else
  range="HEAD"
  echo "::notice::Reading all commits"
fi

has_breaking=false
has_feature=false

while IFS= read -r -d $'\x1e' record; do
  record="${record#$'\n'}"
  [ -z "${record}" ] && continue

  subject="${record%%$'\x1f'*}"
  body="${record#*$'\x1f'}"
  subject=$(printf "%s" "${subject}" | sed 's/^[^a-zA-Z]*//')

  if printf "%s" "${subject}" | grep -qiE '^chore(\([^)]*\))?: release version '; then
    continue
  fi

  if printf "%s" "${subject}" | grep -qE '^[A-Za-z]+(\([^)]*\)|\[[^]]*\])?!:' \
    || printf "%s" "${body}" | grep -qE '^BREAKING[ -]CHANGE:'; then
    has_breaking=true
  fi

  if printf "%s" "${subject}" | grep -qiE '^feat(\([^)]*\)|\[[^]]*\])?!?:'; then
    has_feature=true
  fi
done < <(git log "${range}" --format='%s%x1f%b%x1e' 2> /dev/null || true)

if [ "${has_breaking}" = true ] && [ "${AUTO_MAJOR}" = true ] && [ "${MAJOR}" -ge 1 ]; then
  SUGGESTED_TYPE="major"
elif [ "${has_breaking}" = true ] || [ "${has_feature}" = true ]; then
  SUGGESTED_TYPE="minor"
else
  SUGGESTED_TYPE="patch"
fi

echo "::notice::Commits suggest a ${SUGGESTED_TYPE} bump"

type_rank() {
  case "$1" in
    major) printf "3" ;;
    minor) printf "2" ;;
    *) printf "1" ;;
  esac
}

if [ "${VERSION_TYPE}" = "auto" ]; then
  BUMP_TYPE="${SUGGESTED_TYPE}"
else
  BUMP_TYPE="${VERSION_TYPE}"
  if [ "$(type_rank "${BUMP_TYPE}")" -lt "$(type_rank "${SUGGESTED_TYPE}")" ]; then
    echo "::warning::Commits suggest ${SUGGESTED_TYPE}, releasing ${BUMP_TYPE} as chosen"
  fi
fi

case "${BUMP_TYPE}" in
  major)
    NEXT_BASE_VERSION="$((MAJOR + 1)).0.0"
    ;;
  minor)
    NEXT_BASE_VERSION="${MAJOR}.$((MINOR + 1)).0"
    ;;
  patch)
    NEXT_BASE_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
    ;;
esac

if [ -n "${VERSION_SUFFIX}" ]; then
  NEXT_VERSION="${NEXT_BASE_VERSION}-${VERSION_SUFFIX}"
else
  NEXT_VERSION="${NEXT_BASE_VERSION}"
fi

echo "::notice::Next version: ${NEXT_VERSION}"

{
  echo "latest-version=${LATEST_VERSION}"
  echo "next-version=${NEXT_VERSION}"
  echo "next-base-version=${NEXT_BASE_VERSION}"
  echo "bump-type=${BUMP_TYPE}"
} >> "${GITHUB_OUTPUT}"
