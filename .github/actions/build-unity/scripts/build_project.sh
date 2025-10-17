#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PLATFORM:-}" ]; then
  echo "::error::PLATFORM environment variable is required"
  exit 1
fi

if [ -n "${UNITY_EMAIL:-}" ]; then
  echo "::add-mask::${UNITY_EMAIL}"
fi

if [ -n "${UNITY_PASSWORD:-}" ]; then
  echo "::add-mask::${UNITY_PASSWORD}"
fi

if [ -n "${UNITY_LICENSE_KEY:-}" ]; then
  echo "::add-mask::${UNITY_LICENSE_KEY}"
fi

if [ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
  echo "::add-mask::${ANDROID_KEYSTORE_PASSWORD}"
fi

if [ -n "${IOS_CERTIFICATE_PASSWORD:-}" ]; then
  echo "::add-mask::${IOS_CERTIFICATE_PASSWORD}"
fi

if [ "${CACHE_ENABLED:-false}" == "true" ]; then
  if [ "${CACHE_HIT:-false}" == "true" ]; then
    echo "::notice::✅ Using cached Unity Library - this should speed up the build significantly"
  else
    echo "::notice::❄️  Cold start - Unity Library will be rebuilt and cached for next time"
  fi
else
  echo "::notice::🚫 Caching disabled - build will not use or create cache"
fi

case "${PLATFORM}" in
  "Android")
    chmod +x "${GITHUB_ACTION_PATH}/scripts/build_android.sh"
    "${GITHUB_ACTION_PATH}/scripts/build_android.sh"
    ;;
  "iOS")
    chmod +x "${GITHUB_ACTION_PATH}/scripts/build_ios.sh"
    "${GITHUB_ACTION_PATH}/scripts/build_ios.sh"
    ;;
  *)
    echo "::error::Unsupported platform: ${PLATFORM}"
    exit 1
    ;;
esac
