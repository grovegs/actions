#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/.github/actions/build-agent-skills/scripts/build_agent_skills.sh"
WORK="$(mktemp -d)"
FAILURES=0

fail() {
  echo "$1"
  FAILURES=$((FAILURES + 1))
}

run() {
  local repo="$1"
  local check="$2"

  SKILLS_ROOT="${WORK}/${repo}" SKILLS_CHECK="${check}" bash "${SCRIPT}" > "${WORK}/out" 2>&1
}

make_repo() {
  local repo="$1"

  mkdir -p "${WORK}/${repo}/skills/grovegames-x"
  mkdir -p "${WORK}/${repo}/src/GroveGames.X.Unity/Packages/com.grovegames.x"
  mkdir -p "${WORK}/${repo}/src/GroveGames.X.Godot/addons/GroveGames.X"
  printf -- '---\nname: grovegames-x\ndescription: Rules.\n---\n\n# Shared\n' > "${WORK}/${repo}/skills/grovegames-x/SKILL.md"
  printf '## Unity\n\n- Unity rule.\n' > "${WORK}/${repo}/skills/grovegames-x/unity.md"
}

UNITY="src/GroveGames.X.Unity/Packages/com.grovegames.x/Skills~/grovegames-x/SKILL.md"
GODOT="src/GroveGames.X.Godot/addons/GroveGames.X/skills/grovegames-x/SKILL.md"

make_repo full
run full false || fail "write failed: $(cat "${WORK}/out")"

EXPECTED_UNITY="$(printf -- '---\nname: grovegames-x\ndescription: Rules.\n---\n\n# Shared\n\n## Unity\n\n- Unity rule.')"

if [ "$(cat "${WORK}/full/${UNITY}")" != "${EXPECTED_UNITY}" ]; then
  fail "the Unity skill is not the shared rules followed by unity.md"
fi

if ! cmp -s "${WORK}/full/skills/grovegames-x/SKILL.md" "${WORK}/full/${GODOT}"; then
  fail "an engine without its own file does not get the shared rules alone"
fi

if [ ! -f "${WORK}/full/src/GroveGames.X.Godot/addons/GroveGames.X/skills/.gdignore" ]; then
  fail "the Godot skills folder has no .gdignore"
fi

run full true || fail "check failed right after a write: $(cat "${WORK}/out")"

echo "- Another rule." >> "${WORK}/full/skills/grovegames-x/unity.md"
if run full true; then
  fail "check passed after the source changed"
fi
grep -q -F "${UNITY}" "${WORK}/out" || fail "check does not name the stale file"

run full false
echo "edited by hand" >> "${WORK}/full/${GODOT}"
if run full true; then
  fail "check passed after a shipped skill was edited"
fi

run full false
rm "${WORK}/full/src/GroveGames.X.Godot/addons/GroveGames.X/skills/.gdignore"
if run full true; then
  fail "check passed without .gdignore"
fi

mkdir -p "${WORK}/none"
run none true || fail "a repository without skills fails"

make_repo unity-only
rm -rf "${WORK}/unity-only/src/GroveGames.X.Godot"
run unity-only false || fail "a repository without a Godot addon fails"
[ -f "${WORK}/unity-only/${UNITY}" ] || fail "no Unity skill without a Godot addon"

make_repo two
mkdir -p "${WORK}/two/src/GroveGames.Y.Unity/Packages/com.grovegames.y"
if run two false; then
  fail "two Unity packages are accepted"
fi

if SKILLS_ROOT="${WORK}/full" SKILLS_CHECK=maybe bash "${SCRIPT}" > /dev/null 2>&1; then
  fail "an unknown check value is accepted"
fi

rm -rf "${WORK}"

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} build-agent-skills check(s) failed"
  exit 1
fi

echo "✅ build-agent-skills writes and checks the engine skills"
