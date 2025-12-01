#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PACKAGE_FILE:-}" ]; then
  echo "::error::PACKAGE_FILE environment variable is required"
  exit 1
fi

if [ -z "${NUGET_API_KEY:-}" ]; then
  echo "::error::NUGET_API_KEY environment variable is required"
  exit 1
fi

if ! command -v dotnet > /dev/null 2>&1; then
  echo "::error::dotnet is not installed or not in PATH"
  exit 1
fi

if [ ! -f "${PACKAGE_FILE}" ]; then
  echo "::error::Package file '${PACKAGE_FILE}' does not exist"
  exit 1
fi

NUGET_SOURCE="${NUGET_SOURCE:-https://api.nuget.org/v3/index.json}"
SKIP_DUPLICATE="${SKIP_DUPLICATE:-true}"

echo "::notice::Publishing NuGet package: ${PACKAGE_FILE}"
echo "::notice::Source: ${NUGET_SOURCE}"
echo "::notice::Skip duplicate: ${SKIP_DUPLICATE}"

declare -a DOTNET_ARGS
DOTNET_ARGS=(
  "nuget"
  "push"
  "${PACKAGE_FILE}"
  "--api-key"
  "${NUGET_API_KEY}"
  "--source"
  "${NUGET_SOURCE}"
)

if [ "${SKIP_DUPLICATE}" = "true" ]; then
  DOTNET_ARGS+=("--skip-duplicate")
fi

MAX_RETRIES=3
RETRY_DELAY=10
ATTEMPT=0
SUCCESS=false

while [ ${ATTEMPT} -le ${MAX_RETRIES} ]; do
  if [ ${ATTEMPT} -gt 0 ]; then
    echo "::notice::Retrying publish (attempt ${ATTEMPT}/${MAX_RETRIES})..."
    echo "::notice::Waiting ${RETRY_DELAY} seconds..."
    sleep ${RETRY_DELAY}
  fi

  OUTPUT=$(mktemp)
  if dotnet "${DOTNET_ARGS[@]}" > "${OUTPUT}" 2>&1; then
    cat "${OUTPUT}"
    echo "::notice::✓ NuGet package published successfully"
    SUCCESS=true
    rm -f "${OUTPUT}"
    break
  fi

  cat "${OUTPUT}"

  if grep -q "409.*Conflict" "${OUTPUT}" 2>/dev/null; then
    echo "::warning::Package version already exists"
    if [ "${SKIP_DUPLICATE}" = "true" ]; then
      echo "::notice::Skipping duplicate as configured"
      SUCCESS=true
      rm -f "${OUTPUT}"
      break
    fi
  fi

  if grep -q "401.*Unauthorized" "${OUTPUT}" 2>/dev/null || \
     grep -q "403.*Forbidden" "${OUTPUT}" 2>/dev/null; then
    echo "::error::Authentication failed - invalid API key"
    rm -f "${OUTPUT}"
    break
  fi

  if grep -q "500" "${OUTPUT}" 2>/dev/null || \
     grep -q "503" "${OUTPUT}" 2>/dev/null || \
     grep -q "timeout" "${OUTPUT}" 2>/dev/null; then
    if [ ${ATTEMPT} -lt ${MAX_RETRIES} ]; then
      echo "::warning::Server error, will retry"
      ATTEMPT=$((ATTEMPT + 1))
      rm -f "${OUTPUT}"
      continue
    fi
  fi

  ATTEMPT=$((ATTEMPT + 1))
  rm -f "${OUTPUT}"
done

if [ "${SUCCESS}" = false ]; then
  echo "::error::Failed to publish NuGet package after $((MAX_RETRIES + 1)) attempts"
  exit 1
fi

echo "::notice::✓ NuGet package published: ${PACKAGE_FILE}"
