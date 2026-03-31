#!/bin/bash
# Create a styled DMG for ClaudeMonitor
set -e

APP_NAME="ClaudeMonitor"
BUILD_DIR="build"
DMG_TEMP="${BUILD_DIR}/${APP_NAME}-temp.dmg"
DMG_FINAL="${BUILD_DIR}/${APP_NAME}.dmg"
STAGING="${BUILD_DIR}/dmg-staging"
VOL_NAME="$APP_NAME"
WINDOW_W=540
WINDOW_H=340
ICON_SIZE=128
APP_X=140
APP_Y=150
APPS_X=400
APPS_Y=150

# Clean
rm -rf "$STAGING" "$DMG_TEMP" "$DMG_FINAL"
mkdir -p "$STAGING"

# Stage only app + Applications symlink
cp -R "${BUILD_DIR}/${APP_NAME}.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Create read-write DMG (larger to have room for background)
hdiutil create "$DMG_TEMP" \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -format UDRW \
    -fs HFS+ \
    -size 30m

# Mount
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite -noverify | grep "Apple_HFS" | sed 's/.*\(\/Volumes\/.*\)/\1/' | sed 's/[[:space:]]*$//')
echo "Mounted at: $MOUNT_DIR"

# Create and hide background
mkdir -p "$MOUNT_DIR/.background"

# Generate background PNG
python3 -c "
svg = '''<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${WINDOW_W}\" height=\"${WINDOW_H}\" viewBox=\"0 0 ${WINDOW_W} ${WINDOW_H}\">
  <defs>
    <linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"0.3\" y2=\"1\">
      <stop offset=\"0%\" stop-color=\"#1a1a2e\"/>
      <stop offset=\"100%\" stop-color=\"#0f0f1a\"/>
    </linearGradient>
  </defs>
  <rect width=\"${WINDOW_W}\" height=\"${WINDOW_H}\" fill=\"url(#bg)\"/>
  <line x1=\"228\" y1=\"158\" x2=\"328\" y2=\"158\" stroke=\"#e77d3e\" stroke-width=\"2\" stroke-opacity=\"0.25\" stroke-dasharray=\"8,5\"/>
  <polygon points=\"328,151 343,158 328,165\" fill=\"#e77d3e\" fill-opacity=\"0.25\"/>
</svg>'''
with open('/tmp/dmg-bg.svg', 'w') as f: f.write(svg)
"
rsvg-convert -w ${WINDOW_W} -h ${WINDOW_H} /tmp/dmg-bg.svg -o "$MOUNT_DIR/.background/bg.png" 2>/dev/null || \
    qlmanage -t -s ${WINDOW_W} -o /tmp/ /tmp/dmg-bg.svg 2>/dev/null && \
    mv /tmp/dmg-bg.svg.png "$MOUNT_DIR/.background/bg.png" 2>/dev/null || true

# Hide dotfiles
SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true
# Remove .fseventsd
rm -rf "$MOUNT_DIR/.fseventsd" 2>/dev/null || true

# Apply Finder layout via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, $((200 + WINDOW_W)), $((200 + WINDOW_H))}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to $ICON_SIZE
        set text size of theViewOptions to 13
        set label position of theViewOptions to bottom
        try
            set background picture of theViewOptions to file ".background:bg.png"
        end try
        set position of item "${APP_NAME}.app" of container window to {$APP_X, $APP_Y}
        set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Set volume icon
cp "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true

# Cleanup hidden files that Finder creates
rm -rf "$MOUNT_DIR/.fseventsd" 2>/dev/null || true
rm -rf "$MOUNT_DIR/.Trashes" 2>/dev/null || true

sync
sleep 1
hdiutil detach "$MOUNT_DIR"

# Convert to compressed read-only
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_TEMP"
rm -rf "$STAGING"

echo "Styled DMG created: $DMG_FINAL"
