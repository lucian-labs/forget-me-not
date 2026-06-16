#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Team id for automatic signing (iCloud/Push profiles)
set -a; source "$HOME/repos/lucian-utils/.env"; set +a
TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID missing from lucian-utils/.env}"
DEVICE_NAME="${FMN_DEVICE:-Part 2}"   # "An iPhone! Part 2" (the WiFi-connected device)

# App Store Connect API key — lets headless xcodebuild register App ID capabilities
# (iCloud container, Push) and generate the provisioning profile without an Xcode login.
KEY_ID="${APPLE_CONNECT_KEY_ID:?APPLE_CONNECT_KEY_ID missing from lucian-utils/.env}"
ISSUER_ID="${APPLE_CONNECT_ISSUER_ID:?APPLE_CONNECT_ISSUER_ID missing from lucian-utils/.env}"
KEY_PATH="$HOME/repos/lucian-utils/.apple-keys/AuthKey_${KEY_ID}.p8"
[ -f "$KEY_PATH" ] || { echo "API key not found at $KEY_PATH"; exit 1; }

xcodegen generate

# Match the device by name OR model substring, then extract its UUID robustly
# (column spacing varies; the iPhone 17 lists with model "iPhone 17").
DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | grep -i "$DEVICE_NAME" \
  | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)"
[ -n "$DEVICE_ID" ] || { echo "Device matching '$DEVICE_NAME' not found. Connect it, enable Developer Mode, trust this Mac."; exit 1; }

# Build for a generic iOS device (xcodebuild's device IDs differ from devicectl's,
# so don't pin to the devicectl UUID here); install/launch below use devicectl's ID.
xcodebuild -project ForgetMeNot.xcodeproj -scheme ForgetMeNot -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  build

APP="$(find build/Build/Products/Debug-iphoneos -maxdepth 1 -name '*.app' | head -1)"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
echo "Installed on $DEVICE_NAME ($DEVICE_ID)"
# Auto-launch is best-effort: it fails if the device is locked. Install is what matters.
xcrun devicectl device process launch --device "$DEVICE_ID" com.lucianlabs.forgetmenot \
  && echo "Launched." \
  || echo "(auto-launch skipped — unlock the device and open the app)"
