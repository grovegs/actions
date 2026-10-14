#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DIRECTORY:-}" ]; then
  echo "::error::DIRECTORY environment variable is required"
  exit 1
fi

if [ -z "${PROJECT_NAME:-}" ]; then
  echo "::error::PROJECT_NAME environment variable is required"
  exit 1
fi

if [ -z "${BRANCH:-}" ]; then
  echo "::error::BRANCH environment variable is required"
  exit 1
fi

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "::error::CLOUDFLARE_API_TOKEN environment variable is required"
  exit 1
fi

if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  echo "::error::CLOUDFLARE_ACCOUNT_ID environment variable is required"
  exit 1
fi

if ! command -v npx > /dev/null 2>&1; then
  echo "::error::npx is not installed or not in PATH. Add actions/setup-node before this action."
  exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "::error::jq is not installed or not in PATH"
  exit 1
fi

if [ ! -d "${DIRECTORY}" ]; then
  echo "::error::Directory '${DIRECTORY}' does not exist"
  exit 1
fi

WRANGLER_VERSION="${WRANGLER_VERSION:-latest}"
OUTPUT_FILE="${RUNNER_TEMP}/wrangler_output.json"
rm -f "${OUTPUT_FILE}"

declare -a WRANGLER_ARGS
WRANGLER_ARGS=(
  "pages"
  "deploy"
  "${DIRECTORY}"
  "--project-name"
  "${PROJECT_NAME}"
  "--branch"
  "${BRANCH}"
  "--commit-dirty=true"
)

echo "::notice::Deploying '${DIRECTORY}' to Cloudflare Pages project '${PROJECT_NAME}' on branch '${BRANCH}' with wrangler@${WRANGLER_VERSION}"

if ! WRANGLER_OUTPUT_FILE_PATH="${OUTPUT_FILE}" npx --yes "wrangler@${WRANGLER_VERSION}" "${WRANGLER_ARGS[@]}"; then
  echo "::error::Cloudflare Pages deployment failed"
  echo "::notice::Check that the API token has the Cloudflare Pages Edit permission for account '${CLOUDFLARE_ACCOUNT_ID}'"
  echo "::notice::and that the project '${PROJECT_NAME}' exists as a Direct Upload project"
  rm -f "${OUTPUT_FILE}"
  exit 1
fi

DEPLOYMENT=""
if [ -f "${OUTPUT_FILE}" ]; then
  DEPLOYMENT=$(jq -c 'select(.type == "pages-deploy-detailed")' "${OUTPUT_FILE}" | tail -n 1)
fi
rm -f "${OUTPUT_FILE}"

if [ -z "${DEPLOYMENT}" ]; then
  echo "::error::Wrangler did not report deployment details"
  exit 1
fi

DEPLOYMENT_URL=$(jq -r '.url // ""' <<< "${DEPLOYMENT}")
ALIAS_URL=$(jq -r '.alias // ""' <<< "${DEPLOYMENT}")
ENVIRONMENT=$(jq -r '.environment // ""' <<< "${DEPLOYMENT}")
PRODUCTION_BRANCH=$(jq -r '.production_branch // ""' <<< "${DEPLOYMENT}")

echo "::notice::Deployment URL: ${DEPLOYMENT_URL}"
if [ -n "${ALIAS_URL}" ]; then
  echo "::notice::Alias URL: ${ALIAS_URL}"
fi
echo "::notice::Environment: ${ENVIRONMENT} (production branch is '${PRODUCTION_BRANCH}')"

{
  echo "deployment-url=${DEPLOYMENT_URL}"
  echo "alias-url=${ALIAS_URL}"
  echo "environment=${ENVIRONMENT}"
} >> "${GITHUB_OUTPUT}"

echo "::notice::✓ Cloudflare Pages deployment completed successfully"
