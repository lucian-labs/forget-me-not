#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Team id for automatic signing (iCloud/Push profiles)
set -a; source "$HOME/repos/lucian-utils/.env"; set +a
TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID missing from lucian-utils/.env}"
DEVICE_NAME="${FMN_DEVICE:-iPhone 17}"

xcodegen generate

# Match the device by name OR model substring, then extract its UUID robustly
# (column spacing varies; the iPhone 17 lists with model "iPhone 17").
DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | grep -i "$DEVICE_NAME" \
  | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)"
[ -n "$DEVICE_ID" ] || { echo "Device matching '$DEVICE_NAME' not found. Connect it, enable Developer Mode, trust this Mac."; exit 1; }

xcodebuild -project ForgetMeNot.xcodeproj -scheme ForgetMeNot -configuration Debug \
  -destination "id=$DEVICE_ID" -derivedDataPath build \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" -allowProvisioningUpdates build

APP="$(find build/Build/Products/Debug-iphoneos -maxdepth 1 -name '*.app' | head -1)"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
xcrun devicectl device process launch --device "$DEVICE_ID" com.forgetmenot.app
echo "Installed + launched on $DEVICE_NAME ($DEVICE_ID)"
