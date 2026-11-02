#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PACKAGE_PATH:-}" ]; then
  echo "::error::PACKAGE_PATH environment variable is required"
  exit 1
fi

if [ ! -d "${PACKAGE_PATH}" ]; then
  echo "::error::Package directory '${PACKAGE_PATH}' does not exist"
  exit 1
fi

if [ ! -f "${PACKAGE_PATH}/package.json" ]; then
  echo "::error::Package directory '${PACKAGE_PATH}' has no package.json"
  exit 1
fi

PACKAGE_PATH="${PACKAGE_PATH%/}"
PROBLEMS=0

while IFS= read -r -d '' asset; do
  case "${asset}" in
    *.meta)
      if [ ! -e "${asset%.meta}" ]; then
        echo "::error file=${asset}::${asset} has no asset next to it. Delete it, or restore the asset."
        PROBLEMS=$((PROBLEMS + 1))
      fi
      ;;
    *)
      if [ ! -f "${asset}.meta" ]; then
        echo "::error file=${asset}::${asset} has no .meta file. Unity ignores it in git packages, so open the package in Unity and commit the generated ${asset##*/}.meta."
        PROBLEMS=$((PROBLEMS + 1))
      fi
      ;;
  esac
done < <(find "${PACKAGE_PATH}" -mindepth 1 \( -name '.*' -o -name '*~' -o -iname 'cvs' -o -name '*.tmp' \) -prune -o -print0)

if [ "${PROBLEMS}" -gt 0 ]; then
  echo "::error::Found ${PROBLEMS} meta file problem(s) in '${PACKAGE_PATH}'"
  exit 1
fi

echo "::notice::✓ Every asset in '${PACKAGE_PATH}' has a .meta file"
