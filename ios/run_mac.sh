#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Build + run the app on this Mac via Mac Catalyst.
set -a; source "$HOME/repos/lucian-utils/.env"; set +a
TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID missing from lucian-utils/.env}"
KEY_ID="${APPLE_CONNECT_KEY_ID:?APPLE_CONNECT_KEY_ID missing}"
ISSUER_ID="${APPLE_CONNECT_ISSUER_ID:?APPLE_CONNECT_ISSUER_ID missing}"
KEY_PATH="$HOME/repos/lucian-utils/.apple-keys/AuthKey_${KEY_ID}.p8"

xcodegen generate

xcodebuild -project ForgetMeNot.xcodeproj -scheme ForgetMeNot -configuration Debug \
  -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath build \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  build

APP="$(find build/Build/Products/Debug-maccatalyst -maxdepth 1 -name '*.app' | head -1)"
[ -n "$APP" ] || { echo "No .app produced"; exit 1; }
open "$APP"
echo "Opened $APP"
