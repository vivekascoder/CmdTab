#!/bin/bash
set -euo pipefail

APP_NAME="CmdTab"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"

rm -rf "${BUILD_DIR}/${APP_BUNDLE}"

mkdir -p "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources"

echo "Compiling ${APP_NAME}..."

swiftc \
    -o "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    Sources/main.swift \
    Sources/AppSettings.swift \
    Sources/AppDelegate.swift \
    Sources/StatusBarController.swift \
    Sources/SettingsWindowController.swift \
    Sources/OverlayPanelController.swift \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -O

cp Resources/Info.plist "${BUILD_DIR}/${APP_BUNDLE}/Contents/"

echo "Build complete: ${BUILD_DIR}/${APP_BUNDLE}"
echo ""
echo "To run: open ${BUILD_DIR}/${APP_BUNDLE}"
echo "On first launch, grant Accessibility permission in System Settings."
