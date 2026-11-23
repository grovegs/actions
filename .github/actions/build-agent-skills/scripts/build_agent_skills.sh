#!/usr/bin/env bash
set -euo pipefail

SKILLS_CHECK="${SKILLS_CHECK:-false}"

if [ "${SKILLS_CHECK}" != "true" ] && [ "${SKILLS_CHECK}" != "false" ]; then
  echo "::error::SKILLS_CHECK must be true or false, got '${SKILLS_CHECK}'"
  exit 1
fi

SKILLS_ROOT="${SKILLS_ROOT:-.}"

if [ ! -d "${SKILLS_ROOT}" ]; then
  echo "::error::Directory '${SKILLS_ROOT}' not found"
  exit 1
fi

ROOT="$(cd "${SKILLS_ROOT}" && pwd)"
SKILLS_DIR="${ROOT}/skills"
STALE=0
WRITTEN=0

if [ ! -d "${SKILLS_DIR}" ]; then
  echo "::notice::No skills folder in ${ROOT}, nothing to build"
  exit 0
fi

find_one() {
  local pattern="$1"
  local match
  local found=""
  local count=0

  shopt -s nullglob
  for match in ${pattern}; do
    if [ -d "${match}" ]; then
      found="${match}"
      count=$((count + 1))
    fi
  done
  shopt -u nullglob

  if [ "${count}" -gt 1 ]; then
    echo "::error::More than one folder matches ${pattern#"${ROOT}"/}" >&2
    return 1
  fi

  echo "${found}"
}

build_skill() {
  local skill_dir="$1"
  local fragment="$2"
  local target="$3"
  local expected

  expected="$(mktemp)"
  cat "${skill_dir}/SKILL.md" > "${expected}"

  if [ -f "${fragment}" ]; then
    {
      echo ""
      cat "${fragment}"
    } >> "${expected}"
  fi

  if [ "${SKILLS_CHECK}" = "true" ]; then
    if [ ! -f "${target}" ] || ! cmp -s "${expected}" "${target}"; then
      echo "::error file=${target#"${ROOT}"/}::Out of date. Edit the files under skills/ and build the agent skills again"
      STALE=$((STALE + 1))
    fi
  else
    mkdir -p "$(dirname "${target}")"
    cp "${expected}" "${target}"
    echo "Wrote ${target#"${ROOT}"/}"
    WRITTEN=$((WRITTEN + 1))
  fi

  rm -f "${expected}"
}

UNITY_PACKAGE="$(find_one "${ROOT}/src/*.Unity/Packages/com.grovegames.*")"
GODOT_ADDON="$(find_one "${ROOT}/src/*.Godot/addons/*")"

for skill_dir in "${SKILLS_DIR}"/*; do
  if [ ! -f "${skill_dir}/SKILL.md" ]; then
    continue
  fi

  name="$(basename "${skill_dir}")"

  if [ -n "${UNITY_PACKAGE}" ]; then
    build_skill "${skill_dir}" "${skill_dir}/unity.md" "${UNITY_PACKAGE}/Skills~/${name}/SKILL.md"
  fi

  if [ -n "${GODOT_ADDON}" ]; then
    if [ "${SKILLS_CHECK}" = "false" ]; then
      mkdir -p "${GODOT_ADDON}/skills"
      : > "${GODOT_ADDON}/skills/.gdignore"
    elif [ ! -f "${GODOT_ADDON}/skills/.gdignore" ]; then
      echo "::error::${GODOT_ADDON#"${ROOT}"/}/skills/.gdignore is missing. Build the agent skills again"
      STALE=$((STALE + 1))
    fi

    build_skill "${skill_dir}" "${skill_dir}/godot.md" "${GODOT_ADDON}/skills/${name}/SKILL.md"
  fi
done

if [ "${SKILLS_CHECK}" = "true" ]; then
  if [ "${STALE}" -gt 0 ]; then
    exit 1
  fi

  echo "✅ Engine skills match skills/"
  exit 0
fi

echo "Wrote ${WRITTEN} engine skill(s)"
