#!/bin/bash
# Generates DripMeter's full AppIcon.appiconset from a single 1024×1024
# source PNG at Branding/AppIcon.png.
#
# Idempotent: re-running with an unchanged source produces identical output.
# If the source is missing the script exits 0 cleanly (so package_app.sh
# can call it unconditionally without breaking the build).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${ROOT}/Branding/AppIcon.png"
TARGET_DIR="${ROOT}/Sources/DripMeter/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "${SOURCE}" ]]; then
    echo "ℹ️   No Branding/AppIcon.png — skipping icon regeneration."
    echo "    Drop a 1024×1024 PNG there to set the macOS app icon."
    exit 0
fi

if ! command -v sips >/dev/null 2>&1; then
    echo "❌  'sips' not found (it ships with macOS — are you on Linux?)" >&2
    exit 1
fi

# Verify the source resolution. macOS will accept anything but icons look
# crunchy when upscaled; we warn and continue.
SRC_W=$(sips -g pixelWidth "${SOURCE}" | awk '/pixelWidth/ {print $2}')
SRC_H=$(sips -g pixelHeight "${SOURCE}" | awk '/pixelHeight/ {print $2}')
if [[ "${SRC_W}" != "1024" || "${SRC_H}" != "1024" ]]; then
    echo "⚠️   Source is ${SRC_W}×${SRC_H}; expected 1024×1024."
    echo "    Continuing — macOS will scale, but quality may suffer."
fi

mkdir -p "${TARGET_DIR}"

# Apple's required sizes (logical pt × scale factor):
declare -a SIZES=(
    "16:icon_16.png"
    "32:icon_32.png"
    "64:icon_64.png"
    "128:icon_128.png"
    "256:icon_256.png"
    "512:icon_512.png"
    "1024:icon_1024.png"
)

for entry in "${SIZES[@]}"; do
    px="${entry%%:*}"
    name="${entry##*:}"
    sips -s format png -z "${px}" "${px}" "${SOURCE}" \
        --out "${TARGET_DIR}/${name}" >/dev/null
    echo "  ${px}×${px} → ${name}"
done

cat > "${TARGET_DIR}/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16.png",   "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_64.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png",  "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

# Build a standalone .icns too — useful if the user wants to drop it into a
# DMG or the bundle's Contents/Resources directly.
ICONSET="${ROOT}/.build/AppIcon.iconset"
mkdir -p "${ICONSET}"
sips -z   16   16 "${SOURCE}" --out "${ICONSET}/icon_16x16.png"      >/dev/null
sips -z   32   32 "${SOURCE}" --out "${ICONSET}/icon_16x16@2x.png"   >/dev/null
sips -z   32   32 "${SOURCE}" --out "${ICONSET}/icon_32x32.png"      >/dev/null
sips -z   64   64 "${SOURCE}" --out "${ICONSET}/icon_32x32@2x.png"   >/dev/null
sips -z  128  128 "${SOURCE}" --out "${ICONSET}/icon_128x128.png"    >/dev/null
sips -z  256  256 "${SOURCE}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z  256  256 "${SOURCE}" --out "${ICONSET}/icon_256x256.png"    >/dev/null
sips -z  512  512 "${SOURCE}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z  512  512 "${SOURCE}" --out "${ICONSET}/icon_512x512.png"    >/dev/null
sips -z 1024 1024 "${SOURCE}" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "${ICONSET}" -o "${ROOT}/.build/AppIcon.icns"
echo "✅  AppIcon regenerated (.appiconset + .icns)"
