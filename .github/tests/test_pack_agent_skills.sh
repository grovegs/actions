#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UNITY_SCRIPT="${ROOT}/.github/actions/pack-unity-package/scripts/pack_package.sh"
GODOT_SCRIPT="${ROOT}/.github/actions/pack-godot-addon/scripts/pack_addon.sh"
WORK="$(mktemp -d)"
FAILURES=0

fail() {
  echo "$1"
  FAILURES=$((FAILURES + 1))
}

make_repo() {
  local repo="${WORK}/$1"

  mkdir -p "${repo}/skills/grovegames-x" "${repo}/skills/notes"
  mkdir -p "${repo}/com.grovegames.x" "${repo}/GroveGames.X"
  printf -- '---\nname: grovegames-x\ndescription: Rules.\n---\n\n# Shared\n' > "${repo}/skills/grovegames-x/SKILL.md"
  printf '## Unity\n\n- Unity rule.\n' > "${repo}/skills/grovegames-x/unity.md"
  echo "not a skill" > "${repo}/skills/notes/README.md"
  echo '{ "name": "com.grovegames.x", "version": "0.0.0" }' > "${repo}/com.grovegames.x/package.json"
  echo 'version="0.0.0"' > "${repo}/GroveGames.X/plugin.cfg"
}

pack_unity() {
  local repo="${WORK}/$1"
  local skills="$2"

  (
    cd "${repo}"
    HOME="${WORK}/home" GITHUB_OUTPUT="${WORK}/output" PACKAGE_PATH="com.grovegames.x" PACKAGE_VERSION="1.2.3" \
      PACKAGE_FILENAME="x-unity-$1" PACKAGE_SKILLS="${skills}" bash "${UNITY_SCRIPT}"
  ) > "${WORK}/out" 2>&1
}

pack_godot() {
  local repo="${WORK}/$1"
  local skills="$2"

  (
    cd "${repo}"
    HOME="${WORK}/home" GITHUB_OUTPUT="${WORK}/output" ADDON_PATH="GroveGames.X" ADDON_VERSION="1.2.3" \
      ADDON_FILENAME="x-godot-$1" ADDON_SKILLS="${skills}" bash "${GODOT_SCRIPT}"
  ) > "${WORK}/out" 2>&1
}

modified_files() {
  grep '^modified-files=' "${WORK}/output" | tail -n 1
}

mkdir -p "${WORK}/home"
UNITY_SKILL="com.grovegames.x/Skills~/grovegames-x/SKILL.md"
GODOT_SKILL="GroveGames.X/skills/grovegames-x/SKILL.md"
EXPECTED_UNITY="$(printf -- '---\nname: grovegames-x\ndescription: Rules.\n---\n\n# Shared\n\n## Unity\n\n- Unity rule.')"

make_repo full
pack_unity full skills || fail "packing the Unity package failed: $(cat "${WORK}/out")"

if [ "$(cat "${WORK}/full/${UNITY_SKILL}")" != "${EXPECTED_UNITY}" ]; then
  fail "the Unity skill is not SKILL.md followed by unity.md"
fi

modified_files | grep -q -F "${UNITY_SKILL}" || fail "the Unity skill is not in modified-files"

if [ -e "${WORK}/full/com.grovegames.x/Skills~/notes" ]; then
  fail "a folder without SKILL.md was copied to the Unity package"
fi

if ! tar -tzf "${WORK}/home/.unity/packages/x-unity-full.tgz" | grep -q -F "Skills~/grovegames-x/SKILL.md"; then
  fail "the Unity tarball has no skill"
fi

echo "- Another rule." >> "${WORK}/full/skills/grovegames-x/unity.md"
pack_unity full skills || fail "packing the Unity package a second time failed"
grep -q -F "Another rule." "${WORK}/full/${UNITY_SKILL}" || fail "a second pack did not refresh the Unity skill"

if [ "$(grep -c -F "# Shared" "${WORK}/full/${UNITY_SKILL}")" != "1" ]; then
  fail "a second pack appended to the Unity skill instead of replacing it"
fi

pack_godot full skills || fail "packing the Godot addon failed: $(cat "${WORK}/out")"

if ! cmp -s "${WORK}/full/skills/grovegames-x/SKILL.md" "${WORK}/full/${GODOT_SKILL}"; then
  fail "an engine without its own file does not get SKILL.md alone"
fi

[ -f "${WORK}/full/GroveGames.X/skills/.gdignore" ] || fail "the Godot skills folder has no .gdignore"
modified_files | grep -q -F "${GODOT_SKILL}" || fail "the Godot skill is not in modified-files"
modified_files | grep -q -F "GroveGames.X/skills/.gdignore" || fail ".gdignore is not in modified-files"

printf '## Godot\n\n- Godot rule.\n' > "${WORK}/full/skills/grovegames-x/godot.md"
pack_godot full skills || fail "packing the Godot addon a second time failed"
grep -q -F "Godot rule." "${WORK}/full/${GODOT_SKILL}" || fail "godot.md is not in the Godot skill"

if grep -q -F "Unity rule." "${WORK}/full/${GODOT_SKILL}"; then
  fail "unity.md leaked into the Godot skill"
fi

make_repo none
pack_unity none "" || fail "packing the Unity package without skills failed"
pack_godot none "" || fail "packing the Godot addon without skills failed"

if [ -e "${WORK}/none/com.grovegames.x/Skills~" ] || [ -e "${WORK}/none/GroveGames.X/skills" ]; then
  fail "skills were written without the skills input"
fi

make_repo missing
if pack_unity missing nowhere; then
  fail "the Unity pack accepted a skills folder that does not exist"
fi

if pack_godot missing nowhere; then
  fail "the Godot pack accepted a skills folder that does not exist"
fi

rm -rf "${WORK}"

if [ "${FAILURES}" -gt 0 ]; then
  echo "❌ ${FAILURES} check(s) failed"
  exit 1
fi

echo "✅ Pack actions ship agent skills"
