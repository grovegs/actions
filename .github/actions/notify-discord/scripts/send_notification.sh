#!/bin/bash

if [[ -z "${WEBHOOK_URL}" ]]; then
  echo "::error::Webhook URL is required."
  exit 1
fi

escape_json() {
  local string="$1"
  printf '%s' "$string" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e ':a' -e 'N' -e '$!ba' \
    -e 's/\n/\\n/g' \
    -e 's/\r/\\r/g' \
    -e 's/	/\\t/g'
}

escaped_title=$(escape_json "$TITLE")
escaped_description=$(escape_json "$DESCRIPTION")
timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

PAYLOAD_FILE=$(mktemp)

cat > "$PAYLOAD_FILE" <<EOF
{
  "embeds": [{
    "title": "$escaped_title",
    "description": "$escaped_description",
    "color": ${COLOR},
    "timestamp": "${timestamp}"
  }]
}
EOF

echo "::notice::Sending notification to Discord"
if ! curl -s -H "Content-Type: application/json" -d @"$PAYLOAD_FILE" "$WEBHOOK_URL" > /dev/null; then
  rm -f "$PAYLOAD_FILE"
  echo "::error::Failed to send Discord notification."
  exit 1
fi

rm -f "$PAYLOAD_FILE"
echo "::notice::Successfully sent Discord notification"
