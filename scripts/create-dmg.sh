#!/bin/bash
# Create a styled DMG for ClaudeMonitor using create-dmg
set -e

APP_NAME="ClaudeMonitor"
BUILD_DIR="build"
DMG_FINAL="${BUILD_DIR}/${APP_NAME}.dmg"
ICON_SRC="icons/app-icon-1024.png"

# Clean previous DMG
rm -f "$DMG_FINAL"

# Generate volume icon (.icns) from app icon
ICONSET="/tmp/dmg-vol.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16 "$ICON_SRC" --out "$ICONSET/icon_16x16.png" > /dev/null
sips -z 32 32 "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png" > /dev/null
sips -z 32 32 "$ICON_SRC" --out "$ICONSET/icon_32x32.png" > /dev/null
sips -z 64 64 "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png" > /dev/null
sips -z 128 128 "$ICON_SRC" --out "$ICONSET/icon_128x128.png" > /dev/null
sips -z 256 256 "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256 256 "$ICON_SRC" --out "$ICONSET/icon_256x256.png" > /dev/null
sips -z 512 512 "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512 512 "$ICON_SRC" --out "$ICONSET/icon_512x512.png" > /dev/null
cp "$ICON_SRC" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o /tmp/dmg-vol.icns

# Generate background image (dark gradient + arrow)
python3 -c "
import struct, zlib, os

W, H = 540, 380

def make_row(y):
    # Light grey background (Finder uses black text)
    r, g, b = 238, 238, 238
    row = bytearray()
    for x in range(W):
        # Subtle arrow: dashed line y=168-172, x=210-320
        if 168 <= y <= 172 and 210 <= x <= 320 and (x % 13 < 8):
            row.extend([180, 180, 180, 255])
        # Arrowhead: triangle at x=320-340
        elif 160 <= y <= 180 and 320 <= x <= 340:
            mid = 170
            dist = abs(y - mid)
            prog = (x - 320) / 20
            if dist < (1 - prog) * 12:
                row.extend([180, 180, 180, 255])
            else:
                row.extend([r, g, b, 255])
        else:
            row.extend([r, g, b, 255])
    return bytes([0]) + bytes(row)

# Build PNG
raw = b''.join(make_row(y) for y in range(H))
def chunk(ctype, data):
    c = ctype + data
    return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

png = b'\\x89PNG\\r\\n\\x1a\\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9))
png += chunk(b'IEND', b'')

os.makedirs('assets', exist_ok=True)
with open('assets/dmg-background.png', 'wb') as f:
    f.write(png)
print('Background generated: assets/dmg-background.png')
"

# Create DMG with create-dmg
create-dmg \
    --volname "$APP_NAME" \
    --volicon /tmp/dmg-vol.icns \
    --background "assets/dmg-background.png" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "$APP_NAME.app" 150 170 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 390 170 \
    --text-size 14 \
    --no-internet-enable \
    "$DMG_FINAL" \
    "${BUILD_DIR}/${APP_NAME}.app"

echo "Styled DMG created: $DMG_FINAL"
