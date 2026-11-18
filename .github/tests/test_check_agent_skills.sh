#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/.github/actions/check-agent-skills/scripts/check_agent_skills.sh"
WORK="$(mktemp -d)"
FAILURES=0

write_skill() {
  mkdir -p "${WORK}/$1/x"
  printf '%b' "$2" > "${WORK}/$1/x/SKILL.md"
}

expect_accepted() {
  if ! SKILLS_PATH="${WORK}/$1" bash "${SCRIPT}" > /dev/null 2>&1; then
    echo "Rejected a valid skill: $1"
    FAILURES=$((FAILURES + 1))
  fi
}

expect_rejected() {
  if SKILLS_PATH="${WORK}/$1" bash "${SCRIPT}" > /dev/null 2>&1; then
    echo "Accepted a broken skill: $1"
    FAILURES=$((FAILURES + 1))
  fi
}

mkdir -p "${WORK}/none"
expect_accepted none

write_skill plain '---\nname: x\ndescription: Rules for x. Use when y.\n---\nbody\n'
write_skill folded '---\nname: x\ndescription: >\n  Rules for x.\n  Use when y: z.\n---\n'
write_skill literal '---\nname: x\ndescription: |-\n  Rules\n---\n'
write_skill next-line '---\nname: x\ndescription:\n  Rules for x\n---\n'
write_skill quoted-name '---\nname: "x"\ndescription: ok\n---\n'
write_skill comment '---\nname: x # the name\ndescription: ok\n---\n'
write_skill space-before-colon '---\nname : x\ndescription: ok\n---\n'
write_skill bom '\357\273\277---\nname: x\ndescription: ok\n---\n'
write_skill closing-with-space '---\nname: x\ndescription: ok\n--- \nbody\n'
write_skill crlf '---\r\nname: x\r\ndescription: ok\r\n---\r\n'
write_skill flow-list '---\nname: x\ndescription: ok\nallowed-tools: [Read, Bash]\n---\n'
write_skill double-quoted '---\nname: x\ndescription: "Rules: quoted # fine \\"inner\\""\n---\n'
write_skill single-quoted "---\nname: x\ndescription: 'it''s fine: yes'\n---\n"

mkdir -p "${WORK}/large/x"
{
  printf -- '---\nname: x\ndescription: ok\n---\n'
  awk 'BEGIN { for (i = 0; i < 40000; i++) print "a line of body text that makes the file large" }'
} > "${WORK}/large/x/SKILL.md"

for valid in plain folded literal next-line quoted-name comment space-before-colon bom closing-with-space crlf flow-list double-quoted single-quoted large; do
  expect_accepted "${valid}"
done

write_skill other-key-colon '---\nname: x\ndescription: ok\nallowed-tools: Bash(git:*), Read: y\n---\n'
write_skill junk-line '---\nname: x\ndescription: ok\njust some words\n---\n'
write_skill tab-indent '---\nname: x\ndescription: ok\n\tindented: y\n---\n'
write_skill no-space-after-colon '---\nname: x\ndescription:Text\n---\n'
write_skill two-quoted-parts '---\nname: x\ndescription: "a" and "b"\n---\n'
write_skill bad-single-quote "---\nname: x\ndescription: 'it's bad'\n---\n"
write_skill colon-in-description '---\nname: x\ndescription: Rules for x: use when y.\n---\n'
write_skill empty-block '---\nname: x\ndescription: >\n---\n'
write_skill no-description '---\nname: x\n---\n'
write_skill name-mismatch '---\nname: other\ndescription: ok\n---\n'
write_skill uppercase-name '---\nname: X\ndescription: ok\n---\n'
write_skill never-closed '---\nname: x\ndescription: ok\n'
write_skill no-opening 'name: x\ndescription: ok\n---\n'

for broken in other-key-colon junk-line tab-indent no-space-after-colon two-quoted-parts bad-single-quote colon-in-description empty-block no-description name-mismatch uppercase-name never-closed no-opening; do
  expect_rejected "${broken}"
done

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} agent skill check(s) failed"
  exit 1
fi

echo "✅ Agent skills are checked"
