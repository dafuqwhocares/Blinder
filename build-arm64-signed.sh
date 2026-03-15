#!/usr/bin/env bash
set -euo pipefail

# Build and sign arm64 release binary for macOS.
# Usage:
#   ./build-arm64-signed.sh

APP_NAME="BlinderApp"
BUILD_PATH=".build-arm64-release-$(date +%s)"
DIST_DIR="dist"
OUT_BIN="${DIST_DIR}/${APP_NAME}-arm64"

echo "==> Building ${APP_NAME} (release, arm64)..."
swift build -c release --arch arm64 --build-path "${BUILD_PATH}"

echo "==> Preparing output directory..."
mkdir -p "${DIST_DIR}"
cp "${BUILD_PATH}/release/${APP_NAME}" "${OUT_BIN}"

echo "==> Signing binary (ad-hoc)..."
codesign --force --deep --sign - "${OUT_BIN}"

echo "==> Verifying signature..."
codesign --verify --verbose=2 "${OUT_BIN}"

echo "==> Build info:"
file "${OUT_BIN}"

echo
echo "Done."
echo "Signed binary: ${OUT_BIN}"
