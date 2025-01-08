#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <keychain_password>"
    exit 1
fi

keychain_password="$1"

TEMP_DIR=$(mktemp -d)
KEYCHAIN_PATH="$TEMP_DIR/app-signing.keychain-db"

echo "::notice::Creating temporary keychain..."
security create-keychain -p "$keychain_password" "$KEYCHAIN_PATH"

echo "::notice::Configuring temporary keychain..."
security set-keychain-settings -lut 3600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$keychain_password" "$KEYCHAIN_PATH"

echo "::notice::Adding temporary keychain to search path..."
security list-keychain -d user -s "$KEYCHAIN_PATH"

echo "::notice::Temporary keychain created: $KEYCHAIN_PATH"
echo "Use this keychain for signing and other operations."

echo "Keychain path: $KEYCHAIN_PATH"
