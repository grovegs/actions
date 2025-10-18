#!/usr/bin/env bash
set -euo pipefail

MODULES_STRING="${UNITY_MODULES:-}"

if [ -z "${MODULES_STRING}" ]; then
  echo ""
  exit 0
fi

MODULES_ID=$(echo "${MODULES_STRING}" \
  | tr ',' '\n' \
  | sort \
  | while IFS= read -r module; do
      TRIMMED_MODULE=$(echo "${module}" | xargs)
      if [ -n "${TRIMMED_MODULE}" ]; then
        echo -n "${TRIMMED_MODULE:0:3}"
      fi
    done)

echo "${MODULES_ID}"
