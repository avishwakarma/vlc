#!/bin/sh
# Windows x86_64 build of "VLC Redesign (unofficial)", run from the repository root inside
# registry.videolan.org/vlc-debian-win64-posix (same image as upstream's win64 GitLab job).
#
#   extras/package/redesign-ci/win64-build.sh            # build + package
#
# Uses upstream's extras/package/win32/build.sh with VideoLAN's prebuilt contribs (-p, includes static
# Qt 6 + QtQuick) and autotools: that is the combination upstream's win64 GitLab job builds and tests.
# (Meson mode, -m, is only exercised upstream with the LLVM images; with this gcc image it fails in
# upstream code: medialibrary needs dlfcn.h, flac/bluray link errors, Qt private include paths.)
# The repository must be mounted at /vlc: the prebuilt Qt's qt.conf resolves its host data
# (mkspecs) to /vlc/contrib/<triplet>. Outputs go to $OUT_DIR (default: dist/):
#   VLC-Redesign-unofficial-win64-setup.exe, VLC-Redesign-unofficial-win64.zip
set -eu

REPO="$(cd "$(dirname "$0")/../../.." && pwd -P)"
cd "$REPO"
TRIPLET=x86_64-w64-mingw32
BUILD_DIR="$REPO/win64"

# Prebuilt contribs: upstream CI publishes them per "last commit that touched contrib inputs"
# (extras/ci/get-contrib-sha.sh). Our own commits touch extras/package/win32 but not contrib/,
# so walk back through those commits until a published tarball is found.
if [ -z "${VLC_PREBUILT_CONTRIBS_URL:-}" ]; then
    for sha in $(git log --format=%H -n 300 HEAD -- extras/tools contrib extras/ci extras/package/win32); do
        url="https://artifacts.videolan.org/vlc/win64/vlc-contrib-$TRIPLET-$sha.tar.zst"
        code=000
        for try in 1 2 3 4 5; do
            code="$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 60 "$url" || true)"
            case "$code" in 200|404|403) break;; esac
            sleep 5
        done
        case "$code" in
            200) VLC_PREBUILT_CONTRIBS_URL="$url"; break;;
            404|403) ;;  # not published for this commit (e.g. one of ours): try the previous one
            *) echo "cannot check $url (HTTP $code)" >&2; exit 1;;
        esac
    done
fi
if [ -n "${VLC_PREBUILT_CONTRIBS_URL:-}" ]; then
    echo "Prebuilt contribs: $VLC_PREBUILT_CONTRIBS_URL"
    export VLC_PREBUILT_CONTRIBS_URL
else
    echo "WARNING: no prebuilt contribs found, contribs (Qt included) will be built from source (hours)" >&2
fi

# Fork identity (configure.ac --enable-redesign-branding); build.sh appends its own flags after these.
export CONFIGFLAGS="${CONFIGFLAGS:-} --enable-redesign-branding"

extras/package/win32/build.sh -a x86_64 -p
# Stage the binaries like upstream's packaging does (win64/vlc-<version>/)
export PATH="$REPO/extras/tools/build/bin:$PATH"
make -C "$BUILD_DIR" package-win-common
"$REPO/extras/package/redesign-ci/win64-package.sh" "$BUILD_DIR" "${OUT_DIR:-$REPO/dist}"
