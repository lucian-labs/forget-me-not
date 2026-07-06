#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Build + export App Store archives for BOTH iPhone/iPad and Mac Catalyst, signed for
# distribution. Automatic signing + the App Store Connect API key create the Apple
# Distribution cert + App Store provisioning profiles on demand (-allowProvisioningUpdates),
# so no cert needs to pre-exist. Produces uploadable artifacts in dist/ — it does NOT upload
# (create the App Store Connect app record first, then run the printed upload commands).
set -a; source "$HOME/repos/lucian-utils/.env"; set +a
TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID missing from lucian-utils/.env}"
KEY_ID="${APPLE_CONNECT_KEY_ID:?APPLE_CONNECT_KEY_ID missing}"
ISSUER_ID="${APPLE_CONNECT_ISSUER_ID:?APPLE_CONNECT_ISSUER_ID missing}"
KEY_PATH="$HOME/repos/lucian-utils/.apple-keys/AuthKey_${KEY_ID}.p8"
[ -f "$KEY_PATH" ] || { echo "ASC API key not found at $KEY_PATH"; exit 1; }

xcodegen generate
# Monotonic build number (App Store requires each upload to increase it).
BUILD_NO="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
BUILD_REV="$(git rev-parse --short HEAD 2>/dev/null || echo dev)$(git diff --quiet HEAD 2>/dev/null || echo +)"
rm -rf dist && mkdir -p dist
echo "Building version $(grep -m1 MARKETING_VERSION project.yml | tr -d ' \"' | cut -d: -f2) ($BUILD_NO / $BUILD_REV)"

AUTH=(-authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER_ID" -allowProvisioningUpdates)
COMMON=(-project ForgetMeNot.xcodeproj -scheme ForgetMeNot -configuration Release
        CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM"
        CURRENT_PROJECT_VERSION="$BUILD_NO" FMN_BUILD_REV="$BUILD_REV")

cat > dist/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST

echo "== iOS (iPhone/iPad) archive =="
xcodebuild "${COMMON[@]}" "${AUTH[@]}" -destination 'generic/platform=iOS' \
  -archivePath dist/FMN-ios.xcarchive archive
xcodebuild -exportArchive -archivePath dist/FMN-ios.xcarchive \
  -exportOptionsPlist dist/ExportOptions.plist -exportPath dist/ios "${AUTH[@]}"

echo "== Mac Catalyst archive =="
xcodebuild "${COMMON[@]}" "${AUTH[@]}" -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  -archivePath dist/FMN-mac.xcarchive archive
xcodebuild -exportArchive -archivePath dist/FMN-mac.xcarchive \
  -exportOptionsPlist dist/ExportOptions.plist -exportPath dist/mac "${AUTH[@]}"

echo ""
echo "Artifacts in dist/ (build $BUILD_NO). After the App Store Connect app record exists, upload:"
echo "  xcrun altool --upload-app -t ios   -f dist/ios/*.ipa --apiKey $KEY_ID --apiIssuer $ISSUER_ID"
echo "  xcrun altool --upload-app -t macos -f dist/mac/*.pkg --apiKey $KEY_ID --apiIssuer $ISSUER_ID"
