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

TITLE="${TITLE:-}"
DESCRIPTION="${DESCRIPTION:-}"
COLOR="${COLOR:-3447003}"
TITLE_LIMIT=250
DESCRIPTION_LIMIT=4000
timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

if ! PAYLOAD=$(jq -n \
  --arg title "${TITLE}" \
  --arg description "${DESCRIPTION}" \
  --argjson color "${COLOR}" \
  --argjson title_limit "${TITLE_LIMIT}" \
  --argjson description_limit "${DESCRIPTION_LIMIT}" \
  --arg timestamp "${timestamp}" \
  'def clip($limit):
    if length <= $limit then . else .[0:($limit - 1)] + "…" end;
  def fit($limit):
    if length <= $limit then .
    else
      split("\n\n") as $blocks
      | if ($blocks | length) < 2 then clip($limit)
        else
          ("\n…\n\n" + $blocks[-1]) as $footer
          | ($blocks[0:-1] | join("\n\n")) as $body
          | ($limit - ($footer | length)) as $available
          | if $available < 1 then clip($limit)
            else
              $body[0:$available] as $cut
              | ($cut | rindex("\n")) as $line
              | (if $line != null and $line > 0 then $cut[0:$line] else $cut end) + $footer
            end
        end
    end;
  {
    embeds: [{
      title: ($title | gsub("\n"; " ") | clip($title_limit)),
      description: ($description | fit($description_limit)),
      color: $color,
      timestamp: $timestamp
    }]
  }'); then
  echo "::error::Failed to build the Discord payload"
  exit 1
fi

if [ "$(printf '%s' "${DESCRIPTION}" | jq -Rs 'length')" -gt "${DESCRIPTION_LIMIT}" ]; then
  echo "::warning::Description is longer than ${DESCRIPTION_LIMIT} characters and was shortened to fit the Discord embed limit."
fi

echo "::notice::Sending notification to Discord"

MAX_RETRIES=3
RETRY_DELAY=2
ATTEMPT=0
SUCCESS=false

while [ ${ATTEMPT} -le ${MAX_RETRIES} ]; do
  if [ ${ATTEMPT} -gt 0 ]; then
    echo "::notice::Retrying notification (attempt ${ATTEMPT}/${MAX_RETRIES})..."
    echo "::notice::Waiting ${RETRY_DELAY} seconds..."
    sleep ${RETRY_DELAY}
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
    ATTEMPT=$((ATTEMPT + 1))
  elif [[ "${http_code}" == "429" ]]; then
    echo "::warning::Rate limited by Discord (HTTP 429)"
    ATTEMPT=$((ATTEMPT + 1))
    if [ ${ATTEMPT} -le ${MAX_RETRIES} ]; then
      RETRY_DELAY=5
    fi
  else
    echo "::warning::Failed to send Discord notification (HTTP ${http_code})"
    if [ -n "${body}" ]; then
      echo "::warning::Response: ${body}"
    fi
    ATTEMPT=$((ATTEMPT + 1))
  fi
done

if [ "${SUCCESS}" = false ]; then
  echo "::error::Failed to send Discord notification after $((MAX_RETRIES + 1)) attempts"
  exit 1
fi

echo "::notice::✓ Discord notification sent successfully"
