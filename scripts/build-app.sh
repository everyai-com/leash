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
</dict>
</plist>
PLIST

echo "→ Ad-hoc signing (so it launches without quarantine fights)"
codesign --force --deep --sign - "$APP" >/dev/null

echo "→ Zipping for distribution"
cd "$BUILD_DIR"
ZIP="$NAME-$VERSION-macos.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$NAME.app" "$ZIP"
cd - >/dev/null

echo
echo "Built:"
echo "  $APP"
echo "  $BUILD_DIR/$ZIP"
