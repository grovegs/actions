#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PLATFORM:-}" ]; then
  echo "::error::PLATFORM environment variable is required"
  exit 1
fi

case "${PLATFORM}" in
  "Android"|"iOS")
    echo "::notice::Building for platform: ${PLATFORM}"
    ;;
  *)
    echo "::error::Unsupported platform: ${PLATFORM}. Supported values: Android, iOS"
    exit 1
    ;;
esac

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
    echo "::notice::✅ Restored exact Unity Library cache"
  elif [ -n "${CACHE_MATCHED_KEY:-}" ]; then
    echo "::notice::♻️  Restored partial Unity Library cache: ${CACHE_MATCHED_KEY}"
  else
    echo "::notice::❄️  Cold start - Unity Library will be rebuilt and cached for next time"
  fi
else
  echo "::notice::🚫 Caching disabled - build will not use or create cache"
fi

if ! command -v unity > /dev/null 2>&1; then
  echo "::error::Unity CLI is not installed. Run setup-unity before build-unity"
  exit 1
fi

UNITY_PATH_INPUT="${UNITY_PATH_INPUT:-}"
UNITY_PATH_INPUT="${UNITY_PATH_INPUT/#\~/$HOME}"

if [ -n "${UNITY_PATH_INPUT}" ]; then
  UNITY_VERSION=$(grep "m_EditorVersion:" "${PROJECT_DIR}/ProjectSettings/ProjectVersion.txt" | cut -d' ' -f2 | tr -d '\r')
  if [ "$(uname)" = "Darwin" ]; then
    UNITY_EDITOR_PATH="${UNITY_PATH_INPUT}/${UNITY_VERSION}/Unity.app"
  else
    UNITY_EDITOR_PATH="${UNITY_PATH_INPUT}/${UNITY_VERSION}/Editor/Unity"
  fi
else
  UNITY_EDITOR_PATH="${UNITY_EXECUTABLE:-}"
  UNITY_EDITOR_PATH="${UNITY_EDITOR_PATH%/Contents/MacOS/Unity}"
fi

if [ -n "${UNITY_EDITOR_PATH}" ] && [ ! -e "${UNITY_EDITOR_PATH}" ]; then
  echo "::error::Unity not found at: ${UNITY_EDITOR_PATH}"
  exit 1
fi

echo "::notice::Using Unity: ${UNITY_EDITOR_PATH:-resolved by Unity CLI from ProjectVersion.txt}"
export UNITY_EDITOR_PATH

case "${PLATFORM}" in
  "Android")
    chmod +x "${GITHUB_ACTION_PATH}/scripts/build_android.sh"
    "${GITHUB_ACTION_PATH}/scripts/build_android.sh"
    ;;
  "iOS")
    chmod +x "${GITHUB_ACTION_PATH}/scripts/build_ios.sh"
    "${GITHUB_ACTION_PATH}/scripts/build_ios.sh"
    ;;
esac
