#!/bin/bash
set -euo pipefail

APP_NAME="CmdTab"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"

BUNDLE_DIR="${BUILD_DIR}/${APP_BUNDLE}"
MACOS_DIR="${BUNDLE_DIR}/Contents/MacOS"
RESOURCES_DIR="${BUNDLE_DIR}/Contents/Resources"

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "Compiling ${APP_NAME}..."

swiftc \
    -o "${MACOS_DIR}/${APP_NAME}" \
    Sources/main.swift \
    Sources/AppSettings.swift \
    Sources/InstantSpaceSwitcher.swift \
    Sources/WorkspaceOverlayController.swift \
    Sources/AppBlockView.swift \
    Sources/AppDelegate.swift \
    Sources/StatusBarController.swift \
    Sources/SettingsWindowController.swift \
    Sources/OverlayPanelController.swift \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -framework ServiceManagement \
    -O

cp Resources/Info.plist "${BUNDLE_DIR}/Contents/"

if [[ -f "${BUILD_DIR}/Resources/AppIcon.png" ]]; then
    cp "${BUILD_DIR}/Resources/AppIcon.png" "${RESOURCES_DIR}/AppIcon.png"

    ICONSET_DIR="${BUILD_DIR}/.build/CmdTab.iconset"
    rm -rf "${ICONSET_DIR}"
    mkdir -p "${ICONSET_DIR}"

    sips -z 16 16     "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
    sips -z 32 32     "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
    sips -z 64 64     "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
    sips -z 256 256   "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
    sips -z 512 512   "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "${BUILD_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/CmdTabIcon.icns"
else
    echo "Warning: Resources/AppIcon.png not found; app icon will use the system default."
fi

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    CODESIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -n 1)"
fi

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    echo "Signing with identity: ${CODESIGN_IDENTITY}"
    CODESIGN_ARGS=(--force --sign "${CODESIGN_IDENTITY}" --options runtime)
    if [[ "${CODESIGN_IDENTITY}" == Developer\ ID\ Application:* ]]; then
        CODESIGN_ARGS+=(--timestamp)
    fi
    codesign "${CODESIGN_ARGS[@]}" "${BUNDLE_DIR}"
else
    echo "Signing with ad-hoc signature..."
    codesign --force --sign - "${BUNDLE_DIR}"
    echo "Warning: ad-hoc signing can cause Accessibility permission resets after rebuilds."
fi

echo "Build complete: ${BUNDLE_DIR}"
echo ""
echo "To run: open ${BUNDLE_DIR}"
echo "On first launch, grant Accessibility permission in System Settings."
echo "Use a stable codesigning identity to preserve Accessibility permission across rebuilds."
