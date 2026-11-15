#!/usr/bin/env bash
# Builds AppResources/Assets.car and AppResources/AppIcon.icns from the drawings in this folder.
#
#   AppIcon.svg        the 1024 master (tile, shadow, rim), used from 64 px up
#   AppIcon-small.svg  the three-segment drawing on a 32 grid, used at 16 and 32
#   AppIcon-bleed.svg  the master without shadow, clip or rim, framed on the tile (for Icon Composer)
#
# Needs rsvg-convert (brew install librsvg) and Xcode's actool.
#
# Assets.car holds the art as a full-bleed Icon Composer icon. macOS 26+ draws a bare .icns
# inside a grey container; Info.plist names CFBundleIconName = AppIcon so the system uses
# Assets.car and gets the real icon shape. AppIcon.icns (CFBundleIconFile) is the fallback.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/audio-priority-icon.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SET="$TMP/AppIcon.iconset"
mkdir -p "$SET" "$TMP/AppIcon.icon/Assets" "$TMP/car"

# name  source  pixels
while read -r name src px; do
  rsvg-convert -w "$px" -h "$px" "$HERE/$src.svg" -o "$SET/$name"
done <<'JOBS'
icon_16x16.png       AppIcon-small 16
icon_16x16@2x.png    AppIcon-small 32
icon_32x32.png       AppIcon-small 32
icon_32x32@2x.png    AppIcon       64
icon_128x128.png     AppIcon       128
icon_128x128@2x.png  AppIcon       256
icon_256x256.png     AppIcon       256
icon_256x256@2x.png  AppIcon       512
icon_512x512.png     AppIcon       512
icon_512x512@2x.png  AppIcon       1024
JOBS
iconutil -c icns "$SET" -o "$ROOT/AppResources/AppIcon.icns"
echo "Wrote $ROOT/AppResources/AppIcon.icns"

rsvg-convert -w 1024 -h 1024 "$HERE/AppIcon-bleed.svg" -o "$TMP/AppIcon.icon/Assets/art.png"
cat > "$TMP/AppIcon.icon/icon.json" <<'JSON'
{
  "fill" : "none",
  "groups" : [ {
    "name" : "Art",
    "layers" : [ { "name" : "Art", "image-name" : "art.png", "glass" : false } ],
    "lighting" : "individual",
    "shadow" : { "kind" : "none", "opacity" : 0 },
    "specular" : false,
    "translucency" : { "enabled" : false, "value" : 0 }
  } ],
  "supported-platforms" : { "squares" : [ "macOS" ] }
}
JSON
xcrun actool "$TMP/AppIcon.icon" --compile "$TMP/car" --platform macosx --minimum-deployment-target 26.0 \
  --app-icon AppIcon --output-partial-info-plist "$TMP/car/partial.plist" >/dev/null
cp "$TMP/car/Assets.car" "$ROOT/AppResources/Assets.car"
echo "Wrote $ROOT/AppResources/Assets.car"
if [[ -n "${ICONSET_OUT:-}" ]]; then mkdir -p "$ICONSET_OUT"; cp "$SET"/*.png "$TMP/AppIcon.icon/Assets/art.png" "$ICONSET_OUT"/; fi
