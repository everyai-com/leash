#!/usr/bin/env bash
# Builds leash.app — a proper macOS bundle from the SwiftPM binary.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="leash"
BUNDLE_ID="com.everyai.leash"
VERSION="${VERSION:-0.1.0}"
BUILD_DIR=".build/app"
APP="$BUILD_DIR/$NAME.app"

# Universal build needs full Xcode; gracefully fall back to host arch otherwise.
ARCH_ARGS=(--arch arm64 --arch x86_64)
if ! xcrun --find xcodebuild >/dev/null 2>&1 \
   || ! [[ -x "$(xcode-select -p)/../SharedFrameworks/XCBuild.framework/Versions/A/Support/xcbuild" ]]; then
  echo "⚠  Full Xcode not detected — building host-arch only (CI will produce universal)"
  ARCH_ARGS=()
fi

echo "→ Building release binary"
swift build -c release ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}

BIN_PATH="$(swift build -c release ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"} --show-bin-path)/$NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "→ Generating icon"
swift scripts/make-icon.swift >/dev/null

echo "→ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$NAME"
chmod +x "$APP/Contents/MacOS/$NAME"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# SPM-built binaries lack the standard .app rpath; add it so embedded
# frameworks (Sparkle) resolve at runtime.
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "$APP/Contents/MacOS/$NAME" 2>/dev/null || true

# Embed Sparkle.framework for auto-update support
SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
  mkdir -p "$APP/Contents/Frameworks"
  cp -R "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/"
  echo "→ Embedded Sparkle.framework"
else
  echo "⚠  Sparkle framework not found at $SPARKLE_FRAMEWORK (run 'swift package resolve')"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${NAME}</string>
  <key>CFBundleDisplayName</key><string>leash</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${NAME}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSSupportsSuddenTermination</key><false/>
  <key>NSAppleEventsUsageDescription</key>
  <string>leash uses Apple Events to bring your terminal back to the front when Claude finishes.</string>
  <key>SUFeedURL</key>
  <string>https://raw.githubusercontent.com/everyai-com/leash/main/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>Dl18Rp8SmQvfBNqGJX/Dia/phdxATd9ClksOVU+x7uc=</string>
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUScheduledCheckInterval</key>
  <integer>3600</integer>
</dict>
</plist>
PLIST

# Prefer a real Developer ID cert if one is installed; fall back to ad-hoc.
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
  echo "→ Ad-hoc signing (no Developer ID found)"
else
  echo "→ Signing with: $SIGN_IDENTITY"
fi

# Hardened-runtime entitlements needed for Apple Events + notarization.
ENTITLEMENTS="$BUILD_DIR/leash.entitlements"
cat > "$ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.automation.apple-events</key><true/>
  <key>com.apple.security.network.server</key><true/>
</dict>
</plist>
EOF

codesign --force --deep --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" "$APP" >/dev/null

# Optional: notarize if creds are configured via `xcrun notarytool store-credentials`.
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "→ Notarizing (profile: $NOTARY_PROFILE)"
  NOTARY_ZIP="$BUILD_DIR/leash-notarize.zip"
  ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$NOTARY_ZIP"
fi

echo "→ Zipping for distribution"
cd "$BUILD_DIR"
ZIP="$NAME-$VERSION-macos.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$NAME.app" "$ZIP"
cd - >/dev/null

# Sparkle ed25519 signature for auto-update
SPARKLE_SIGN="$PWD/.build/artifacts/sparkle/Sparkle/bin/sign_update"
SIG_OUT=""
if [[ -x "$SPARKLE_SIGN" ]]; then
  SIG_OUT="$("$SPARKLE_SIGN" "$BUILD_DIR/$ZIP" || true)"
  echo "→ Sparkle signature:"
  echo "    $SIG_OUT"
fi

# Update appcast.xml with this version's entry
ZIP_SIZE=$(stat -f%z "$BUILD_DIR/$ZIP")
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
APPCAST="appcast.xml"
cat > "$APPCAST" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>leash</title>
    <link>https://raw.githubusercontent.com/everyai-com/leash/main/appcast.xml</link>
    <description>Auto-update feed for leash.</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure
        url="https://github.com/everyai-com/leash/releases/download/v$VERSION/$ZIP"
        length="$ZIP_SIZE"
        type="application/octet-stream"
        $SIG_OUT />
    </item>
  </channel>
</rss>
XML
echo "→ Wrote $APPCAST"

echo
echo "Built:"
echo "  $APP"
echo "  $BUILD_DIR/$ZIP"
echo "  $APPCAST"
