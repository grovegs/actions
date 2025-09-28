#!/bin/bash

if [ $# -ne 3 ]; then
  echo "::error::Usage: $0 <platform> <version> <ios_team_id>"
  exit 1
fi

platform="$1"
version="$2"
ios_team_id="$3"

IFS='.' read -r major minor patch <<< "$version"

if [[ -z "$major" || -z "$minor" || -z "$patch" ]]; then
  echo "::error::Invalid version format. Expected format: major.minor.patch (e.g., 1.0.0)"
  exit 1
fi

case ${platform} in
  Android)
    version_number=$(printf "%d%03d%04d" "$major" "$minor" "$patch")
    echo "::notice::Creating Android export options"
    export_options=(
      "version/code=${version_number}"
      "version/name=${version}"
    )
    ;;
  iOS)
    echo "::notice::Creating iOS export options"
    export_options=(
      "application/short_version=${version}"
      "application/version=${version}"
      "application/app_store_team_id=${ios_team_id}"
    )
    ;;
  *)
    echo "::error::Unsupported platform: ${platform}"
    exit 1
    ;;
esac

echo "::notice::Setting export options: ${export_options[*]}"
echo export_options="${export_options[*]}" >> "$GITHUB_OUTPUT"
