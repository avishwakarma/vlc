#!/bin/bash
# macOS (Apple Silicon) build of "VLC Redesign (unofficial)": deps -> Meson build -> .app -> verify -> DMG.
# Same steps as the GitHub Actions macOS job, runnable locally:
#
#   extras/package/redesign-ci/macos-build.sh [--install-brew-deps]
#
# Env (optional): BUILD_DIR (build-ci), OUT_DIR (dist), DEPS_PREFIX (.ci-deps; prefix with libsmb2 +
# medialibrary, built if missing), VERSION (4.0.0-dev), SUFFIX (git tag or short sha).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
cd "$REPO"

if [ "${1:-}" = "--install-brew-deps" ]; then
    # shellcheck disable=SC2046
    brew install --quiet $(grep -v '^#' "$HERE/brew-packages.txt")
fi

BREW="$(brew --prefix)"
export PATH="$BREW/opt/bison/bin:$BREW/bin:$PATH"  # meson picks up ccache by itself
export MACOSX_DEPLOYMENT_TARGET=14.0
export BUILD_DIR="${BUILD_DIR:-$REPO/build-ci}"
export OUT_DIR="${OUT_DIR:-$REPO/dist}"
export DEPS_PREFIX="${DEPS_PREFIX:-$REPO/.ci-deps}"
export VERSION="${VERSION:-4.0.0-dev}"
if [ -z "${SUFFIX:-}" ]; then
    SUFFIX="$(git describe --tags --exact-match --match 'v*' 2>/dev/null || git rev-parse --short HEAD)"
fi
export SUFFIX

echo "== toolchain: $(xcrun --show-sdk-path) | $(clang --version | head -1) | Qt $(qmake -query QT_VERSION 2>/dev/null || echo '?')"

"$HERE/macos-deps.sh" "$DEPS_PREFIX"

# Configure + build + bundle + verify.py + codesign --verify + DMG
"$REPO/extras/package/macosx/redesign/make-app.sh"

APP="$OUT_DIR/VLC Redesign (unofficial).app"
DMG="$OUT_DIR/VLC-Redesign-unofficial-arm64.dmg"
test -f "$DMG"

# Smoke test without a GUI session: the bundled binary starts, finds its plugins and the Qt interface.
"$APP/Contents/MacOS/VLC" --version | sed -n 1,2p
"$APP/Contents/MacOS/VLC" --intf dummy --list 2>/dev/null | grep -E '^ +qt +' \
    || { echo "Qt interface plugin not listed by the bundled VLC" >&2; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist"

(cd "$OUT_DIR" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG" .dmg).sha256")
