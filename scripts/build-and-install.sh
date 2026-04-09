#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="ClaudeMenuBar"
DERIVED_DATA="/tmp/ClaudeMenuBar-build"
DMG_DIR="/tmp/ClaudeMenuBar-dmg"
DMG_TMP="/tmp/$APP_NAME-tmp.dmg"
DMG_PATH="$PROJECT_DIR/$APP_NAME.dmg"

echo "=== Building $APP_NAME ==="

# Find Xcode
if [ -d "/Applications/Xcode.app" ]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
elif xcode-select -p &>/dev/null; then
  export DEVELOPER_DIR="$(xcode-select -p)"
else
  echo "Error: Xcode not found. Install Xcode from the App Store."
  exit 1
fi

# Build
xcodebuild build \
  -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS' \
  -quiet

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: Build succeeded but $APP_NAME.app not found."
  exit 1
fi

echo "  ✓ Build succeeded"

# Install hooks
bash "$SCRIPT_DIR/install.sh"

# Generate background image
echo "=== Creating DMG ==="
BG_IMAGE="/tmp/dmg-bg.png"
swift "$SCRIPT_DIR/dmg-background.swift" "$BG_IMAGE"

# Prepare DMG contents
rm -rf "$DMG_DIR" "$DMG_TMP" "$DMG_PATH"
mkdir -p "$DMG_DIR/.background"
cp -R "$APP_PATH" "$DMG_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_DIR/Applications"
cp "$BG_IMAGE" "$DMG_DIR/.background/background.png"

# Create writable DMG
hdiutil create "$DMG_TMP" \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov -format UDRW \
  -quiet

# Mount and style with AppleScript
DEVICE=$(hdiutil attach "$DMG_TMP" -readwrite -noverify | grep '/Volumes/' | awk '{print $1}')
VOLUME="/Volumes/$APP_NAME"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 800, 520}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 80
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to {150, 200}
    set position of item "Applications" of container window to {450, 200}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

# Unmount
sync
hdiutil detach "$DEVICE" -quiet

# Convert to compressed read-only DMG
hdiutil convert "$DMG_TMP" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  -quiet

echo "  ✓ DMG created at $DMG_PATH"

# Clean up
rm -rf "$DERIVED_DATA" "$DMG_DIR" "$DMG_TMP" "$BG_IMAGE"

# Open the DMG
open "$DMG_PATH"

echo ""
echo "=== Done ==="
echo "Drag $APP_NAME.app to Applications, then launch it."
