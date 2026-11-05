#!/bin/sh
# win64-package.sh <autotools build dir> <out dir>
# Takes the tree staged by `make package-win-common` (<build>/vlc-<version>) and produces
#   <out>/VLC-Redesign-unofficial-win64-setup.exe   (NSIS, extras/package/win32/NSIS/redesign.nsi)
#   <out>/VLC-Redesign-unofficial-win64.zip         (portable: settings stay in the folder)
set -eu
REPO="$(cd "$(dirname "$0")/../../.." && pwd -P)"
BUILD="$(cd "$1" && pwd -P)"
mkdir -p "$2"
OUT="$(cd "$2" && pwd -P)"
NAME="VLC-Redesign-unofficial-win64"
PKGVER="$(sed -n 's/^PACKAGE_VERSION = //p' "$BUILD/Makefile")"
VERSION="${REDESIGN_VERSION:-$PKGVER}"
STAGED="$BUILD/vlc-$PKGVER"
DEST="$BUILD/redesign-win64"

# Shipped tree: the staged binaries minus the libvlc SDK, stripped
rm -rf "$DEST"
cp -a "$STAGED" "$DEST"
rm -rf "$DEST/sdk"
find "$DEST" -name '*.dll' -o -name '*.exe' | xargs x86_64-w64-mingw32-strip --strip-unneeded
test -f "$DEST/vlc.exe" || { echo "vlc.exe missing in $DEST" >&2; exit 1; }
test -f "$DEST/plugins/gui/libqt_plugin.dll" || { echo "Qt interface plugin missing" >&2; exit 1; }
cp "$REPO/share/icons/vlc-redesign.ico" "$DEST/vlc-redesign.ico"

# Uninstaller file list: exactly what the installer copies (plus the generated plugins.dat).
UNINST="$BUILD/redesign-uninstall.nsh"
(
    cd "$DEST"
    find . -type f | sed 's|^\./||' | sort | while read -r f; do
        printf '  Delete "$INSTDIR\\%s"\n' "$(printf '%s' "$f" | tr '/' '\\')"
    done
    find . -mindepth 1 -type d | sed 's|^\./||' | sort -r | while read -r d; do
        printf '  RMDir "$INSTDIR\\%s"\n' "$(printf '%s' "$d" | tr '/' '\\')"
    done
) > "$UNINST"

makensis -V2 -DVERSION="$VERSION" -DSRCDIR="$DEST" -DUNINSTLIST="$UNINST" \
    -DOUTFILE="$OUT/$NAME-setup.exe" "$REPO/extras/package/win32/NSIS/redesign.nsi"

# Portable zip: a "portable" folder next to vlc.exe keeps vlcrc, the library and the Qt
# settings inside the extracted folder (src/win32/dirs.c), nothing in %APPDATA% or the registry.
STAGE="$BUILD/zip-stage"
rm -rf "$STAGE" "$OUT/$NAME.zip"
mkdir -p "$STAGE"
cp -a "$DEST" "$STAGE/$NAME"
mkdir -p "$STAGE/$NAME/portable"
(cd "$STAGE" && zip -qr -9 "$OUT/$NAME.zip" "$NAME")
rm -rf "$STAGE"

(cd "$OUT" && sha256sum "$NAME-setup.exe" "$NAME.zip" | tee "$NAME.sha256")
