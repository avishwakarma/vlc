#!/bin/bash
# macos-deps.sh <prefix>
# Builds the two VLC dependencies that Homebrew does not ship, at the versions pinned by
# VLC's contribs (sha512 checked against contrib/src/*/SHA512SUMS, contrib patches applied):
#   libsmb2 6.1 (SMB2/3 network shares), VideoLAN medialibrary 0.13.2 (Media Library).
# Recipe: .redesign/BUILD.md. Idempotent: does nothing if <prefix> already has both.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
PREFIX="$1"
SMB2_VERSION=6.1
ML_VERSION=0.13.2

if [ -f "$PREFIX/lib/pkgconfig/libsmb2.pc" ] && [ -f "$PREFIX/lib/pkgconfig/medialibrary.pc" ]; then
    echo "deps already in $PREFIX"; exit 0
fi

export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"
SDK="$(xcrun --show-sdk-path)"
CXXFLAGS_FIX=""
# Stale Command Line Tools libc++ headers (no <type_traits>) shadow the SDK's on some hosts.
if [ "$(xcode-select -p)" = /Library/Developer/CommandLineTools ] && [ -d /Library/Developer/CommandLineTools/usr/include/c++/v1 ] && [ ! -f /Library/Developer/CommandLineTools/usr/include/c++/v1/type_traits ]; then
    CXXFLAGS_FIX="-nostdinc++ -isystem $SDK/usr/include/c++/v1"
fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
fetch() { # url file contrib-dir
    curl -fsSL --retry 3 -o "$WORK/$2" "$1"
    want="$(awk -v f="$2" '$2==f {print $1}' "$REPO/contrib/src/$3/SHA512SUMS")"
    got="$(shasum -a 512 "$WORK/$2" | cut -d' ' -f1)"
    [ -n "$want" ] && [ "$want" = "$got" ] || { echo "sha512 mismatch for $2" >&2; exit 1; }
}

# libsmb2
fetch "https://github.com/sahlberg/libsmb2/archive/refs/tags/libsmb2-$SMB2_VERSION.tar.gz" "libsmb2-$SMB2_VERSION.tar.gz" smb2
tar -C "$WORK" -xf "$WORK/libsmb2-$SMB2_VERSION.tar.gz"
( cd "$WORK/libsmb2-libsmb2-$SMB2_VERSION"
  for p in "$REPO"/contrib/src/smb2/*.patch; do patch -p1 < "$p"; done
  cmake -S . -B b -G Ninja -DCMAKE_BUILD_TYPE=Release -DENABLE_LIBKRB5=OFF -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
  cmake --build b && cmake --install b )

# medialibrary (libvlc disabled, as in contrib; system sqlite3)
fetch "https://code.videolan.org/videolan/medialibrary/-/archive/$ML_VERSION/medialibrary-$ML_VERSION.tar.bz2" "medialibrary-$ML_VERSION.tar.bz2" medialibrary
tar -C "$WORK" -xf "$WORK/medialibrary-$ML_VERSION.tar.bz2"
( cd "$WORK/medialibrary-$ML_VERSION"
  meson setup b --prefix "$PREFIX" --libdir lib --buildtype=release -Dlibvlc=disabled -Dtests=disabled -Dlibtool_workaround=true \
        "-Dcpp_args=$CXXFLAGS_FIX" "-Dobjcpp_args=$CXXFLAGS_FIX"
  ninja -C b && meson install -C b )

ls "$PREFIX/lib"
