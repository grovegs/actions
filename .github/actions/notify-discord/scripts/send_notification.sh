#!/bin/bash

if [[ -z "${WEBHOOK_URL}" ]]; then
  echo "::error::Webhook URL is required."
  exit 1
fi

escape_json() {
  local string="$1"
  printf '%s' "$string" | jq -Rs .
}

title_json=$(escape_json "$TITLE")
description_json=$(escape_json "$DESCRIPTION")
timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

PAYLOAD=$(jq -n \
  --argjson title "$title_json" \
  --argjson description "$description_json" \
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
if [ "$description_length" -gt 4096 ]; then
  echo "::warning::Description is ${description_length} characters (limit: 4096). It may be truncated by Discord."
fi

echo "::notice::Sending notification to Discord"

response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
  echo "::notice::Successfully sent Discord notification (HTTP $http_code)"
else
  echo "::error::Failed to send Discord notification. HTTP code: $http_code"
  echo "::error::Response: $body"
  exit 1
fi
