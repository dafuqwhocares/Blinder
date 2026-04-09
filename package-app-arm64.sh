#!/usr/bin/env bash
set -euo pipefail

# Build, package, and ad-hoc sign a macOS arm64 .app bundle.
# Usage:
#   ./package-app-arm64.sh
#
# Output:
#   dist/Blinder App.app

APP_NAME="BlinderApp"
DISPLAY_NAME="Blinder App"
BUNDLE_ID="com.ansgarscheffold.blinder"
VERSION="1.1"
BUILD_NUMBER="2"
ICON_NAME="BlinderAppIcon"

BUILD_PATH=".build-arm64-release"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${DISPLAY_NAME}.app"
BIN_OUT="${DIST_DIR}/${APP_NAME}-arm64"
BIN_IN_BUNDLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
PLIST_PATH="${APP_BUNDLE}/Contents/Info.plist"
ICON_WORKDIR="$(mktemp -d "/tmp/${APP_NAME}.iconwork.XXXXXX")"
ICONSET_DIR="${ICON_WORKDIR}/${ICON_NAME}.iconset"
ICON_SOURCE_PNG="${ICONSET_DIR}/icon-1024.png"
ICON_ICNS_PATH="${APP_BUNDLE}/Contents/Resources/${ICON_NAME}.icns"

cleanup() {
  rm -rf "${ICON_WORKDIR}"
}
trap cleanup EXIT

echo "==> Step 1/6: Build and sign arm64 binary"
if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  echo "Skipping build step (SKIP_BUILD=1)."
else
  "$(dirname "$0")/build-arm64-signed.sh"
fi

echo "==> Step 2/6: Prepare .app bundle structure"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> Step 3/6: Generate Finder icon (.icns)"
mkdir -p "${ICONSET_DIR}"
swift - "${ICON_SOURCE_PNG}" <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let side = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Failed to allocate bitmap.")
}

guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Failed to create graphics context.")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let sideF = CGFloat(side)
NSColor.clear.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: sideF, height: sideF)).fill()

let bgRect = NSRect(x: sideF * 0.04, y: sideF * 0.04, width: sideF * 0.92, height: sideF * 0.92)
let bgRadius = sideF * 0.21
let bg = NSBezierPath(roundedRect: bgRect, xRadius: bgRadius, yRadius: bgRadius)
NSColor(calibratedRed: 0.89, green: 0.62, blue: 0.20, alpha: 1.0).setFill()
bg.fill()
NSColor(calibratedRed: 0.73, green: 0.46, blue: 0.10, alpha: 0.30).setStroke()
bg.lineWidth = max(2.5, sideF * 0.014)
bg.stroke()

let glassesRect = NSRect(x: sideF * 0.18, y: sideF * 0.37, width: sideF * 0.64, height: sideF * 0.36)
let lensWidth = glassesRect.width * 0.40
let lensHeight = glassesRect.height * 0.62
let bridgeWidth = glassesRect.width * 0.13
let bridgeHeight = glassesRect.height * 0.17
let lensY = glassesRect.minY + (glassesRect.height - lensHeight) * 0.48
let leftX = glassesRect.minX
let rightX = glassesRect.maxX - lensWidth
let radius = lensHeight * 0.30
NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).setFill()

NSBezierPath(roundedRect: NSRect(x: leftX, y: lensY, width: lensWidth, height: lensHeight), xRadius: radius, yRadius: radius).fill()
NSBezierPath(roundedRect: NSRect(x: rightX, y: lensY, width: lensWidth, height: lensHeight), xRadius: radius, yRadius: radius).fill()
NSBezierPath(
    roundedRect: NSRect(
        x: glassesRect.midX - bridgeWidth * 0.5,
        y: lensY + (lensHeight - bridgeHeight) * 0.5,
        width: bridgeWidth,
        height: bridgeHeight
    ),
    xRadius: bridgeHeight * 0.35,
    yRadius: bridgeHeight * 0.35
).fill()
NSBezierPath(
    roundedRect: NSRect(
        x: leftX + lensWidth * 0.10,
        y: lensY + lensHeight * 0.70,
        width: glassesRect.width - lensWidth * 0.20,
        height: lensHeight * 0.17
    ),
    xRadius: lensHeight * 0.08,
    yRadius: lensHeight * 0.08
).fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to generate icon PNG.")
}
try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

for base in 16 32 128 256 512; do
  sips -z "${base}" "${base}" "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_${base}x${base}.png" >/dev/null
  scale2=$((base * 2))
  sips -z "${scale2}" "${scale2}" "${ICON_SOURCE_PNG}" --out "${ICONSET_DIR}/icon_${base}x${base}@2x.png" >/dev/null
done

iconutil -c icns "${ICONSET_DIR}" -o "${ICON_ICNS_PATH}"

echo "==> Step 4/6: Copy executable and write Info.plist"
cp "${BIN_OUT}" "${BIN_IN_BUNDLE}"
chmod +x "${BIN_IN_BUNDLE}"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${DISPLAY_NAME}</string>
  <key>CFBundleDisplayName</key><string>${DISPLAY_NAME}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>${ICON_NAME}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
EOF

echo "==> Step 5/6: Sign and verify .app bundle"
codesign --force --deep --sign - "${APP_BUNDLE}"
codesign --verify --verbose=2 "${APP_BUNDLE}"

echo "==> Step 6/6: Refresh Finder metadata"
touch "${APP_BUNDLE}"

echo
echo "Done."
echo "App bundle: ${APP_BUNDLE}"
