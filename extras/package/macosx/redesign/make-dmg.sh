#!/bin/bash
# make-dmg.sh <App.app> <out dir>  -> <out dir>/VLC-Redesign-unofficial-arm64.dmg
# Stable file name (release asset URL must not change); version lives in the volume name.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
APP="$1"; OUT="$2"
VERSION="${VERSION:-4.0.0-dev}"; SUFFIX="${SUFFIX:-r1}"
VOL="VLC Redesign (unofficial) $VERSION+$SUFFIX"
DMG="$OUT/VLC-Redesign-unofficial-arm64.dmg"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"; mkdir -p "$ROOT"
ditto "$APP" "$ROOT/$(basename "$APP")"          # ditto keeps the xattr-based signature of plugins.dat
ln -s /Applications "$ROOT/Applications"
cp "$HERE/Read me first.txt" "$ROOT/Read me first.txt"
ICON="$REPO/extras/package/macosx/asset_sources/redesign/VLC.icns"  # redesigned cone, unless a dedicated disk image icon exists
[ -f "$REPO/extras/package/macosx/asset_sources/redesign/dmg/disk_image.icns" ] && ICON="$REPO/extras/package/macosx/asset_sources/redesign/dmg/disk_image.icns"
if [ -f "$ICON" ]; then cp "$ICON" "$ROOT/.VolumeIcon.icns"; fi
rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$ROOT" -fs HFS+ -format UDRW -ov "$TMP/rw.dmg" >/dev/null
if [ -f "$ICON" ]; then
  MNT="$TMP/mnt"; mkdir -p "$MNT"
  hdiutil attach "$TMP/rw.dmg" -mountpoint "$MNT" -nobrowse -quiet
  SetFile -a C "$MNT" 2>/dev/null || true
  hdiutil detach "$MNT" -quiet
fi
hdiutil convert "$TMP/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
echo "$DMG ($(du -h "$DMG" | cut -f1))"
