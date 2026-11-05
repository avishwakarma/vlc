#!/bin/bash
# One-command local packaging of "VLC Redesign (unofficial).app" + DMG (arm64, macOS 14+, ad-hoc signed).
#
#   extras/package/macosx/redesign/make-app.sh [--no-build] [--no-dmg]
#
# Environment (all optional):
#   BUILD_DIR   meson build dir            (default: <repo>/build-pkg)
#   OUT_DIR     where app + dmg are written (default: <repo>/build-pkg/dist)
#   VERSION     marketing version           (default: 4.0.0-dev)
#   SUFFIX      fork build suffix           (default: r1)  -> volume name "... 4.0.0-dev+r1"
#   DEPS_PREFIX extra prefix with libsmb2/medialibrary (default: ~/WebRoot/personal/vlc-deps/prefix)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO/build-pkg}"
OUT_DIR="${OUT_DIR:-$BUILD_DIR/dist}"
VERSION="${VERSION:-4.0.0-dev}"
SUFFIX="${SUFFIX:-r1}"
DEPS_PREFIX="${DEPS_PREFIX:-$HOME/WebRoot/personal/vlc-deps/prefix}"
BREW="$(brew --prefix)"
STAGE="$BUILD_DIR/stage"
DO_BUILD=1; DO_DMG=1
for a in "$@"; do case "$a" in --no-build) DO_BUILD=0;; --no-dmg) DO_DMG=0;; *) echo "unknown arg $a"; exit 2;; esac; done

export PATH="$BREW/opt/bison/bin:$BREW/bin:$PATH"
export MACOSX_DEPLOYMENT_TARGET=14.0
export CMAKE_PREFIX_PATH="$BREW/opt/qt"

if [ "$DO_BUILD" = 1 ]; then
  if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    SDK="$(xcrun --show-sdk-path)"
    CXXFLAGS=""
    # Stale Command Line Tools libc++ (no <type_traits>) shadows the SDK's: see .redesign/BUILD.md
    if [ "$(xcode-select -p)" = /Library/Developer/CommandLineTools ] && [ -d /Library/Developer/CommandLineTools/usr/include/c++/v1 ] && [ ! -f /Library/Developer/CommandLineTools/usr/include/c++/v1/type_traits ]; then
      CXXFLAGS="-nostdinc++ -isystem $SDK/usr/include/c++/v1"
    fi
    meson setup "$BUILD_DIR" --buildtype=release --prefix=/opt/vlc-redesign \
      -Dqt=enabled -Drust=disabled -Dlua=disabled -Dtests=disabled -Dnls=disabled \
      -Dadaptive=disabled -Dskins2=disabled \
      "-Dpkg_config_path=$DEPS_PREFIX/lib/pkgconfig,$BREW/lib/pkgconfig,$BREW/share/pkgconfig" \
      "-Dcpp_args=$CXXFLAGS -I$BREW/opt/libupnp/include" "-Dobjcpp_args=$CXXFLAGS"
  fi
  ninja -C "$BUILD_DIR"
fi

rm -rf "$STAGE"
DESTDIR="$STAGE" meson install -C "$BUILD_DIR" --no-rebuild >/dev/null
mkdir -p "$OUT_DIR"
python3 "$HERE/bundle.py" --stage "$STAGE" --out "$OUT_DIR" --version "$VERSION" --suffix "$SUFFIX"
APP="$OUT_DIR/VLC Redesign (unofficial).app"
python3 "$HERE/verify.py" "$APP"
codesign --verify --deep --strict "$APP" && echo "codesign verify: OK"
if [ "$DO_DMG" = 1 ]; then
  VERSION="$VERSION" SUFFIX="$SUFFIX" "$HERE/make-dmg.sh" "$APP" "$OUT_DIR"
fi
