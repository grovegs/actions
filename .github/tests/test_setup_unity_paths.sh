#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
FAILURES=0

for script in get_install_dir.sh install_unity.sh; do
  sed -n '/^read_cli_path() {/,/^}/p' "${ROOT}/.github/actions/setup-unity/scripts/${script}" > "${WORK}/${script}"

  if [ ! -s "${WORK}/${script}" ]; then
    echo "read_cli_path not found in ${script}"
    exit 1
  fi
done

if ! diff "${WORK}/get_install_dir.sh" "${WORK}/install_unity.sh" > /dev/null; then
  echo "The two copies of read_cli_path differ"
  exit 1
fi

# shellcheck disable=SC1091
source "${WORK}/get_install_dir.sh"

expect_path() {
  local name="$1"
  local output="$2"
  local expected="$3"
  local actual

  actual=$(read_cli_path "${output}")

  if [ "${actual}" != "${expected}" ]; then
    echo "${name}: expected '${expected}', got '${actual}'"
    FAILURES=$((FAILURES + 1))
  fi
}

expect_path "bare path" "/Applications/Unity/Editor" "/Applications/Unity/Editor"
expect_path "bare path with spaces" "/Volumes/My Disk/Unity" "/Volumes/My Disk/Unity"
expect_path "table with a path row" "$(printf 'key\tvalue\npath\t/Volumes/External/Unity/Editor')" "/Volumes/External/Unity/Editor"
expect_path "table, path with spaces" "$(printf 'key\tvalue\npath\t/A B/Unity.app')" "/A B/Unity.app"
expect_path "table without a header" "$(printf '6000.0.58f2\t/Apps/Unity/6000.0.58f2')" "/Apps/Unity/6000.0.58f2"
expect_path "table with another key" "$(printf 'key\tvalue\ninstallPath\t/Apps/Unity')" "/Apps/Unity"
expect_path "three columns" "$(printf 'version\tarch\tpath\n6000.1\tarm64\t/Apps/U')" "/Apps/U"
expect_path "table with carriage returns" "$(printf 'key\tvalue\r\npath\t/Apps/Unity\r\n')" "/Apps/Unity"
expect_path "bare path with a carriage return" "$(printf '/Apps/Unity\r\n')" "/Apps/Unity"
expect_path "warning before a bare path" "$(printf 'warning: update available\n/Apps/Unity')" "/Apps/Unity"
expect_path "home path" "~/Unity/Editor" "~/Unity/Editor"
expect_path "empty output" "" ""
expect_path "empty value column" "$(printf 'key\tvalue\npath\t')" ""

sed -n '/^list_installed_modules() {/,/^}/p' "${ROOT}/.github/actions/setup-unity/scripts/install_unity.sh" > "${WORK}/modules.sh"

if [ ! -s "${WORK}/modules.sh" ]; then
  echo "list_installed_modules not found in install_unity.sh"
  exit 1
fi

# shellcheck disable=SC1091
source "${WORK}/modules.sh"

UNITY_VERSION="6000.3.26f1"

unity() {
  if [ "${FAKE_MODULES:-ok}" = "fail" ]; then
    return 2
  fi

  printf 'id\tname\tcategory\tstatus\tdownload\tinstalled\taliases\n'
  printf 'documentation\tDocumentation\tDocumentation\tAvailable\t468 MB\t955 MB\t\n'
  printf 'android\tAndroid Build Support\tPlatforms\tInstalled\t2.11 GB\t6.73 GB\t\n'
  printf 'ios\tiOS Build Support\tPlatforms\tInstalled\t470 MB\t1.38 GB\t\n'
}

ACTUAL=$(list_installed_modules | tr '\n' ' ')

if [ "${ACTUAL}" != "android ios " ]; then
  echo "installed modules: got '${ACTUAL}', want 'android ios '"
  FAILURES=$((FAILURES + 1))
fi

ACTUAL=$(FAKE_MODULES=fail list_installed_modules 2> /dev/null | tr '\n' ' ')

if [ -n "${ACTUAL}" ]; then
  echo "a failed module listing: got '${ACTUAL}', want nothing"
  FAILURES=$((FAILURES + 1))
fi

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} editor path check(s) failed"
  exit 1
fi

echo "✅ Editor paths are read from every Unity CLI output form"
