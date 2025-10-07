#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "::error::Usage: $0 <webhook_url> <title> <description> <color>"
  exit 1
fi

webhook_url="$1"
title="$2"
description="$3"
color="$4"

if [[ -z "${webhook_url}" ]]; then
  echo "::error::Webhook URL is required."
  exit 1
fi

timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

payload=$(cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$description",
    "color": $color,
    "timestamp": "${timestamp}"
  }]
}
EOF
)

echo "::notice::Sending notification to Discord"
if ! curl -s -H "Content-Type: application/json" -d "$payload" "$webhook_url" > /dev/null; then
  echo "::error::Failed to send Discord notification."
  exit 1
fi

echo "::notice::Successfully sent Discord notification"
