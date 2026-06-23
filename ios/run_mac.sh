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

# Stamp a real build number (monotonic commit count) + revision (short SHA, +=dirty) so the
# in-app footer can confirm both devices are on the same build.
BUILD_NO="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
BUILD_REV="$(git rev-parse --short HEAD 2>/dev/null || echo dev)$(git diff --quiet HEAD 2>/dev/null || echo +)"

xcodebuild -project ForgetMeNot.xcodeproj -scheme ForgetMeNot -configuration Debug \
  -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath build \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" \
  CURRENT_PROJECT_VERSION="$BUILD_NO" FMN_BUILD_REV="$BUILD_REV" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  build

APP="$(find build/Build/Products/Debug-maccatalyst -maxdepth 1 -name '*.app' | head -1)"
[ -n "$APP" ] || { echo "No .app produced"; exit 1; }
killall ForgetMeNot 2>/dev/null || true   # quit any running instance so the rebuilt one launches
open -n "$APP"
echo "Opened $APP"
