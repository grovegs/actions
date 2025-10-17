#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PLATFORM:-}" ]; then
  echo "::error::PLATFORM environment variable is required"
  exit 1
fi

case "${PLATFORM}" in
  "Android"|"iOS")
    echo "::notice::Validating inputs for platform: ${PLATFORM}"
    ;;
  *)
    echo "::error::Unsupported platform: ${PLATFORM}. Supported values: Android, iOS"
    exit 1
    ;;
esac

MISSING_INPUTS=()

validate_android() {
  if [ -z "${ANDROID_KEYSTORE:-}" ]; then
    MISSING_INPUTS+=("android-keystore")
  fi

  if [ -z "${ANDROID_KEYSTORE_USER:-}" ]; then
    MISSING_INPUTS+=("android-keystore-user")
  fi

  if [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
    MISSING_INPUTS+=("android-keystore-password")
  fi

  if [[ -n "${ANDROID_FORMAT:-}" ]]; then
    if [[ ! "${ANDROID_FORMAT}" =~ ^(apk|aab)$ ]]; then
      echo "::error::Invalid android-format: ${ANDROID_FORMAT}. Supported values: apk, aab"
      exit 1
    fi
  fi
}

validate_ios() {
  if [ -z "${IOS_TEAM_ID:-}" ]; then
    MISSING_INPUTS+=("ios-team-id")
  fi

  if [ -z "${IOS_CERTIFICATE:-}" ]; then
    MISSING_INPUTS+=("ios-certificate")
  fi

  if [ -z "${IOS_CERTIFICATE_PASSWORD:-}" ]; then
    MISSING_INPUTS+=("ios-certificate-password")
  fi

  if [ -z "${IOS_PROVISIONING_PROFILE:-}" ]; then
    MISSING_INPUTS+=("ios-provisioning-profile")
  fi

  if [ -z "${IOS_PROVISIONING_PROFILE_UUID:-}" ]; then
    MISSING_INPUTS+=("ios-provisioning-profile-uuid")
  fi

  if [ -z "${IOS_EXPORT_METHOD:-}" ]; then
    MISSING_INPUTS+=("ios-export-method")
  fi

  if [[ -n "${IOS_EXPORT_METHOD:-}" ]]; then
    if [[ ! "${IOS_EXPORT_METHOD}" =~ ^(ad-hoc|app-store|development|enterprise)$ ]]; then
      echo "::error::Invalid ios-export-method: ${IOS_EXPORT_METHOD}. Supported values: ad-hoc, app-store, development, enterprise"
      exit 1
    fi
  fi

  if [[ -n "${IOS_TEAM_ID:-}" ]]; then
    if [[ ! "${IOS_TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]]; then
      echo "::warning::iOS Team ID format appears invalid. Expected 10 uppercase alphanumeric characters."
    fi
  fi

  if [[ -n "${IOS_PROVISIONING_PROFILE_UUID:-}" ]]; then
    if [[ ! "${IOS_PROVISIONING_PROFILE_UUID}" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]; then
      echo "::warning::iOS provisioning profile UUID format appears invalid. Expected UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    fi
  fi
}

case "${PLATFORM}" in
  "Android")
    validate_android
    ;;
  "iOS")
    validate_ios
    ;;
esac

if [[ ${#MISSING_INPUTS[@]} -gt 0 ]]; then
  echo "::error::Missing required inputs for platform ${PLATFORM}:"
  for input in "${MISSING_INPUTS[@]}"; do
    echo "::error::  - ${input}"
  done
  exit 1
fi

echo "::notice::✅ All required inputs are present and valid for platform ${PLATFORM}"
