#!/usr/bin/env bash
set -euo pipefail

if [ -z "${WEBHOOK_URL:-}" ]; then
  echo "::error::WEBHOOK_URL environment variable is required"
  exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "::error::jq is not installed or not in PATH"
  exit 1
fi

if ! command -v curl > /dev/null 2>&1; then
  echo "::error::curl is not installed or not in PATH"
  exit 1
fi

escape_json() {
  local string="$1"
  printf '%s' "${string}" | jq -Rs .
}

TITLE="${TITLE:-}"
DESCRIPTION="${DESCRIPTION:-}"
COLOR="${COLOR:-3447003}"

title_json=$(escape_json "${TITLE}")
description_json=$(escape_json "${DESCRIPTION}")
timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

PAYLOAD=$(jq -n \
  --argjson title "${title_json}" \
  --argjson description "${description_json}" \
  --argjson color "${COLOR}" \
  --arg timestamp "${timestamp}" \
  '{
    embeds: [{
      title: $title,
      description: $description,
      color: $color,
      timestamp: $timestamp
    }]
  }')

description_length=${#DESCRIPTION}
if [ "${description_length}" -gt 4096 ]; then
  echo "::warning::Description is ${description_length} characters (limit: 4096). It may be truncated by Discord."
fi

echo "::notice::Sending notification to Discord"

MAX_RETRIES=3
RETRY_COUNT=0
SUCCESS=false

while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
  if [ ${RETRY_COUNT} -gt 0 ]; then
    echo "::notice::Retry attempt ${RETRY_COUNT}/${MAX_RETRIES}"
    sleep 2
  fi

  response=$(curl -s -w "\n%{http_code}" \
    --max-time 30 \
    --connect-timeout 10 \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" \
    "${WEBHOOK_URL}" 2>&1 || echo -e "\n000")

  http_code=$(echo "${response}" | tail -n1)
  body=$(echo "${response}" | sed '$d')

  if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
    echo "::notice::Successfully sent Discord notification (HTTP ${http_code})"
    SUCCESS=true
    break
  elif [[ "${http_code}" == "000" ]]; then
    echo "::warning::Network error (timeout or connection failed)"
    RETRY_COUNT=$((RETRY_COUNT + 1))
  else
    echo "::error::Failed to send Discord notification. HTTP code: ${http_code}"
    echo "::error::Response: ${body}"
    RETRY_COUNT=$((RETRY_COUNT + 1))
  fi
done

if [ "${SUCCESS}" = false ]; then
  echo "::error::Failed to send Discord notification after ${MAX_RETRIES} attempts"
  exit 1
fi
