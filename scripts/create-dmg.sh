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
WINDOW_H=380
ICON_SIZE=128
APP_X=140
APP_Y=160
APPS_X=400
APPS_Y=160

# Clean
rm -rf "$STAGING" "$DMG_TEMP" "$DMG_FINAL"
mkdir -p "$STAGING"

# Stage files
cp -R "${BUILD_DIR}/${APP_NAME}.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Create background
BG_DIR="$STAGING/.background"
mkdir -p "$BG_DIR"
python3 -c "
svg = '''<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${WINDOW_W}\" height=\"${WINDOW_H}\" viewBox=\"0 0 ${WINDOW_W} ${WINDOW_H}\">
  <defs>
    <linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"0.3\" y2=\"1\">
      <stop offset=\"0%\" stop-color=\"#1e2030\"/>
      <stop offset=\"100%\" stop-color=\"#141622\"/>
    </linearGradient>
  </defs>
  <rect width=\"${WINDOW_W}\" height=\"${WINDOW_H}\" fill=\"url(#bg)\"/>
  <!-- Subtle arrow hint -->
  <line x1=\"230\" y1=\"170\" x2=\"330\" y2=\"170\" stroke=\"#e77d3e\" stroke-width=\"2\" stroke-opacity=\"0.3\" stroke-dasharray=\"6,4\"/>
  <polygon points=\"330,163 345,170 330,177\" fill=\"#e77d3e\" fill-opacity=\"0.3\"/>
</svg>'''
with open('${BG_DIR}/bg.svg', 'w') as f: f.write(svg)
"
# Convert SVG to PNG
qlmanage -t -s ${WINDOW_W} -o "$BG_DIR" "$BG_DIR/bg.svg" 2>/dev/null || true
if [ -f "$BG_DIR/bg.svg.png" ]; then
    mv "$BG_DIR/bg.svg.png" "$BG_DIR/bg.png"
    rm -f "$BG_DIR/bg.svg"
else
    # Fallback: create a simple dark PNG via sips
    sips -s format png --resampleWidth ${WINDOW_W} --resampleHeight ${WINDOW_H} /tmp/ClaudeMonitor-icon.png --out "$BG_DIR/bg.png" 2>/dev/null || true
fi

# Create read-write DMG
hdiutil create "$DMG_TEMP" \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -format UDRW \
    -fs HFS+ \
    -size 20m

# Mount
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite -noverify | grep "/Volumes/" | tail -1 | sed 's/.*\(\/Volumes\/.*\)/\1/' | xargs)
echo "Mounted at: $MOUNT_DIR"

# Apply Finder settings via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, $((200 + WINDOW_W)), $((200 + WINDOW_H))}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to $ICON_SIZE
        try
            set background picture of theViewOptions to file ".background:bg.png"
        end try
        set position of item "$APP_NAME.app" of container window to {$APP_X, $APP_Y}
        set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Set custom volume icon
cp "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
SetFile -c icnC "${MOUNT_DIR}/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true

# Finalize
sync
hdiutil detach "$MOUNT_DIR"

# Convert to compressed read-only
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_FINAL"
rm -f "$DMG_TEMP"
rm -rf "$STAGING"

echo "Styled DMG created: $DMG_FINAL"
