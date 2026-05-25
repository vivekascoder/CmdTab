#!/bin/bash
set -euo pipefail

APP_NAME="CmdTab"
BUNDLE_ID="com.cmdtab.app"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${ROOT_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
STAGING_DIR="${DIST_DIR}/dmg-staging"

DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-}"
DEVELOPER_ID_INSTALLER="${DEVELOPER_ID_INSTALLER:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE="${NOTARIZE:-1}"

if [[ -z "${DEVELOPER_ID_APPLICATION}" ]]; then
    DEVELOPER_ID_APPLICATION="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -n 1)"
fi

if [[ -z "${DEVELOPER_ID_APPLICATION}" ]]; then
    echo "Missing Developer ID Application signing identity."
    echo "Install one from your paid Apple Developer account, or set DEVELOPER_ID_APPLICATION."
    exit 1
fi

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

echo "Building ${APP_NAME} with Developer ID signing..."
CODESIGN_IDENTITY="${DEVELOPER_ID_APPLICATION}" "${ROOT_DIR}/build.sh"

echo "Verifying app signature..."
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}" || true

echo "Creating DMG staging folder..."
mkdir -p "${STAGING_DIR}"
ditto "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "Creating DMG..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

if [[ -n "${DEVELOPER_ID_INSTALLER}" ]]; then
    echo "Signing DMG with installer identity: ${DEVELOPER_ID_INSTALLER}"
    codesign --force --sign "${DEVELOPER_ID_INSTALLER}" --timestamp "${DMG_PATH}"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q '"Developer ID Installer:'; then
    DEVELOPER_ID_INSTALLER="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Installer:[^"]*\)".*/\1/p' | head -n 1)"
    echo "Signing DMG with installer identity: ${DEVELOPER_ID_INSTALLER}"
    codesign --force --sign "${DEVELOPER_ID_INSTALLER}" --timestamp "${DMG_PATH}"
else
    echo "No Developer ID Installer identity found; signing DMG with application identity."
    codesign --force --sign "${DEVELOPER_ID_APPLICATION}" --timestamp "${DMG_PATH}"
fi

if [[ "${NOTARIZE}" == "1" ]]; then
    if [[ -z "${NOTARY_PROFILE}" ]]; then
        echo "Missing NOTARY_PROFILE."
        echo "Create one with:"
        echo "  xcrun notarytool store-credentials cmdtab-notary --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>"
        echo "Then run:"
        echo "  NOTARY_PROFILE=cmdtab-notary ./scripts/release_dmg.sh"
        exit 1
    fi

    echo "Submitting DMG for notarization..."
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
fi

echo "Verifying DMG assessment..."
spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}" || true

echo "Release DMG ready: ${DMG_PATH}"
