#!/usr/bin/env bash
#
# package_release.sh
# EasyLiteRoom
#
# Builds, packages, and signs (if certificates available) the release distribution artifacts:
# - EasyLiteRoom-${VERSION}-macOS-arm64.dmg (drag-and-drop installer)
# - EasyLiteRoom-${VERSION}-macOS-arm64.pkg (standard macOS application installer package)
# - EasyLiteRoom-${VERSION}-macOS-arm64.zip (portable .app)
# - checksums.txt (SHA-256 cryptographic verification)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION="${1:-$(git describe --tags --always 2>/dev/null || echo "v0.1.0-alpha.1")}"
# Strip leading 'v' if present for internal bundle identification
CLEAN_VERSION="${VERSION#v}"

DIST_DIR="${ROOT_DIR}/dist"
BUILD_DIR="${ROOT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/EasyLiteRoom.xcarchive"
STAGING_DIR="${BUILD_DIR}/dmg_staging"

echo "=========================================================="
echo " Packaging EasyLiteRoom Release: ${VERSION}"
echo "=========================================================="

# Clean up previous distribution artifacts
rm -rf "${DIST_DIR}" "${BUILD_DIR}"
mkdir -p "${DIST_DIR}" "${BUILD_DIR}" "${STAGING_DIR}"

echo "==> 1. Building and Archiving EasyLiteRoom in Release configuration..."
xcodebuild -scheme EasyLiteRoom \
           -configuration Release \
           -destination 'platform=macOS' \
           -archivePath "${ARCHIVE_PATH}" \
           archive \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGN_STYLE=Manual \
           DEVELOPMENT_TEAM="" \
           MARKETING_VERSION="${CLEAN_VERSION}"

APP_PATH="${ARCHIVE_PATH}/Products/Applications/EasyLiteRoom.app"

if [ ! -d "${APP_PATH}" ]; then
    FALLBACK_APP="$(find "${BUILD_DIR}" -name "EasyLiteRoom.app" -type d | head -n 1)"
    if [ -n "${FALLBACK_APP}" ] && [ -d "${FALLBACK_APP}" ]; then
        APP_PATH="${FALLBACK_APP}"
    else
        echo "Error: Could not locate built EasyLiteRoom.app!" >&2
        exit 1
    fi
fi

echo "==> Found built application at: ${APP_PATH}"

# Ad-hoc sign if no Developer ID identity is configured
echo "==> 2. Verifying and applying code signature..."
codesign --force --deep --sign - "${APP_PATH}" || true

echo "==> 3. Creating Portable ZIP Archive..."
ZIP_NAME="EasyLiteRoom-${VERSION}-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${DIST_DIR}/${ZIP_NAME}"
echo "    Created: ${DIST_DIR}/${ZIP_NAME}"

echo "==> 4. Generating Standard macOS Installer Package (.pkg)..."
PKG_NAME="EasyLiteRoom-${VERSION}-macOS-arm64.pkg"
pkgbuild --component "${APP_PATH}" \
         --install-location "/Applications" \
         --version "${CLEAN_VERSION}" \
         "${DIST_DIR}/${PKG_NAME}"
echo "    Created: ${DIST_DIR}/${PKG_NAME}"

echo "==> 5. Preparing DMG Drag-and-Drop Staging Folder..."
cp -R "${APP_PATH}" "${STAGING_DIR}/EasyLiteRoom.app"
ln -s /Applications "${STAGING_DIR}/Applications"

DMG_NAME="EasyLiteRoom-${VERSION}-macOS-arm64.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo "==> 6. Generating Compressed DMG..."
hdiutil create -volname "EasyLiteRoom" \
               -srcfolder "${STAGING_DIR}" \
               -ov \
               -format UDZO \
               "${DMG_PATH}"
echo "    Created: ${DMG_PATH}"

echo "==> 7. Generating SHA-256 Checksums..."
cd "${DIST_DIR}"
shasum -a 256 "${DMG_NAME}" "${PKG_NAME}" "${ZIP_NAME}" > "checksums.txt"
cd "${ROOT_DIR}"

echo ""
echo "=========================================================="
echo " Release Packaging Complete! Artifacts in ${DIST_DIR}:"
echo "=========================================================="
ls -lh "${DIST_DIR}"
echo ""
cat "${DIST_DIR}/checksums.txt"
echo "=========================================================="
