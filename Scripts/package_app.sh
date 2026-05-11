#!/bin/bash
# Builds DripMeter.app at the repo root. Adhoc-signs by default; pass
# DRIPMETER_SIGNING=identity:"Developer ID Application: ..." to override.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-release}"
BUNDLE_ID="io.drip-cli.dripmeter"
APP_NAME="DripMeter"
APP_PATH="${APP_NAME}.app"

# shellcheck disable=SC1091
. ./version.env
SHORT_VERSION="${DRIPMETER_VERSION:-0.1.0}"
BUILD_NUMBER="${DRIPMETER_BUILD:-1}"

echo "→ Regenerating app icon from Branding/AppIcon.png (if present)"
./Scripts/make_icons.sh

# Sync optional menu-bar + brand-logo assets into the SPM resource directory
# so `Bundle.module` can find them at runtime.
RESOURCE_DIR="Sources/DripMeter/Resources"
for asset in MenuBarIcon.pdf MenuBarIcon.png BrandingLogo.png BrandingLogo.pdf; do
    if [[ -f "Branding/${asset}" ]]; then
        cp "Branding/${asset}" "${RESOURCE_DIR}/${asset}"
        echo "  → copied Branding/${asset} into resources"
    else
        # If the user removed a branding file, drop the stale copy too.
        rm -f "${RESOURCE_DIR}/${asset}"
    fi
done

echo "→ Compiling Swift package (configuration=${CONFIGURATION})"
swift build -c "${CONFIGURATION}"

BIN_PATH="$(swift build -c "${CONFIGURATION}" --show-bin-path)/${APP_NAME}"
RESOURCES_PATH="$(swift build -c "${CONFIGURATION}" --show-bin-path)/${APP_NAME}_${APP_NAME}.bundle"

if [[ -d "${APP_PATH}" ]]; then
    echo "→ Removing previous ${APP_PATH}"
    if command -v trash >/dev/null 2>&1; then
        trash "${APP_PATH}"
    else
        # Fallback: move out of the way instead of unconditional rm.
        mv "${APP_PATH}" "${APP_PATH}.old.$$"
    fi
fi

echo "→ Assembling ${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

cp "${BIN_PATH}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"

# Copy SPM-generated resource bundle alongside the binary; the app loads its
# Assets.xcassets from there.
if [[ -d "${RESOURCES_PATH}" ]]; then
    cp -R "${RESOURCES_PATH}" "${APP_PATH}/Contents/Resources/"
fi

# Drop the generated .icns directly into Contents/Resources/ so Finder,
# Cmd-Tab, and the About panel can resolve it via CFBundleIconFile (the
# asset-catalog copy lives in the SPM sub-bundle and Finder doesn't read
# from there).
if [[ -f ".build/AppIcon.icns" ]]; then
    cp ".build/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"
    echo "  → embedded AppIcon.icns"
fi

# Stamp Info.plist with the current version.
INFO_PLIST_SRC="Info.plist"
INFO_PLIST_DST="${APP_PATH}/Contents/Info.plist"
cp "${INFO_PLIST_SRC}" "${INFO_PLIST_DST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SHORT_VERSION}" "${INFO_PLIST_DST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${INFO_PLIST_DST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${INFO_PLIST_DST}"

# macOS 14+ stamps `com.apple.provenance` (and sometimes `quarantine`)
# on files copied via `cp` from the Downloads/Desktop tree. codesign
# rejects those with "resource fork, Finder information, or similar
# detritus not allowed". `ditto --norsrc --noextattr --noacl` is the
# only reliable strip — `xattr -cr` leaves provenance behind.
CLEAN_PATH="${APP_PATH}.clean.$$"
ditto --norsrc --noextattr --noacl "${APP_PATH}" "${CLEAN_PATH}"
if command -v trash >/dev/null 2>&1; then
    trash "${APP_PATH}"
else
    mv "${APP_PATH}" "${APP_PATH}.predetritus.$$"
fi
mv "${CLEAN_PATH}" "${APP_PATH}"

echo "→ Code signing (adhoc)"
codesign --force --deep --sign "${DRIPMETER_SIGNING:-"-"}" "${APP_PATH}"

echo "✅  Built ${APP_PATH} (v${SHORT_VERSION} build ${BUILD_NUMBER})"
echo "    Run it with:  open ${APP_PATH}"
