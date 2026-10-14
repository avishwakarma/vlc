# VLC Redesign (unofficial): macOS packaging

Builds a self-contained, ad-hoc signed (unsigned for Gatekeeper purposes) `VLC Redesign (unofficial).app`
and `VLC-Redesign-unofficial-arm64.dmg` from the Meson build. Apple Silicon only.

## One command

    extras/package/macosx/redesign/make-app.sh [--no-build] [--no-dmg]

Env: `BUILD_DIR` (default `build-pkg`), `OUT_DIR` (default `build-pkg/dist`), `VERSION` (4.0.0-dev), `SUFFIX` (r1),
`DEPS_PREFIX` (prefix holding libsmb2 + medialibrary, see `.redesign/BUILD.md`).
Steps: meson setup/ninja (release, `MACOSX_DEPLOYMENT_TARGET=14.0`) -> `meson install` into `$BUILD_DIR/stage` ->
`bundle.py` -> `verify.py` -> `codesign --verify --deep --strict` -> `make-dmg.sh`.

Extra checks: `verify_runtime.py <app> <media> [secs]` launches with a sanitized env and `DYLD_PRINT_LIBRARIES=1`
and fails if any image is loaded from outside the bundle, /System or /usr/lib.

## Files
- `bundle.py`: layout, dependency relocation (copies every non-system dylib/framework into `Contents/Frameworks`,
  rewrites install names to `@rpath`, one relative LC_RPATH per file), Qt plugins + the QML imports VLC uses,
  `qt.conf`, `plugins.dat` (vlc-cache-gen), inside-out ad-hoc signing, `LSMinimumSystemVersion` = max minos found.
- `make_infoplist.py`: Info.plist (bundle id `io.github.avishwakarma.vlc-redesign`, document types and UTIs reused from
  `share/Info.plist.in`, all with `LSHandlerRank Alternate`).
- `verify.py`, `verify_runtime.py`, `make-dmg.sh`, `Read me first.txt` (shipped in the DMG).

## Layout (no env vars needed; src/darwin/dirs.m resolves via the bundle)
    Contents/MacOS/VLC, vlc-qt-check, vlc-preparser     libexec helpers live next to the binary
    Contents/Frameworks/*.dylib, Qt*.framework           libvlc, libvlccore, third-party libs, Qt
    Contents/Frameworks/plugins/<cat>/*.dylib + plugins.dat
    Contents/PlugIns/{platforms,imageformats,iconengines,styles,tls,networkinformation}
    Contents/Resources/{VLC.icns,qt.conf,qml/,share/}
VLC's own QML is compiled into `libqt_plugin.dylib`; only Qt's QML modules are on disk.
User data: `~/Library/{Preferences,Application Support,Caches}/io.github.avishwakarma.vlc-redesign` and
`~/Library/Preferences/com.io-github-avishwakarma-vlc-redesign.vlc-qt-interface.plist` (Qt mangles the domain): VLC 3 untouched.

## Gotchas
- `plugins.dat` lives in Frameworks, so codesign treats it as code: it is signed too (signature in xattrs). Copy the app
  with `ditto` or a DMG, not `cp`/zip-without-xattrs. For a zip use `ditto -c -k --keepParent --sequesterRsrc`.
- Files from Finder: `bin/darwinvlc.m` collects the launch-time `odoc` event (otherwise lost before Qt's loop exists);
  later events go through `QFileOpenEvent` in `modules/gui/qt/qt.cpp`.
- Minimum macOS = highest `minos` among bundled Homebrew bottles (14 on macos-14, 15 on macos-15, 26 on a Tahoe host).
  To really support macOS 14, build on a `macos-14` runner. `bundle.py` writes the truthful value into Info.plist.
- dbus plugins are dropped (always fail on macOS).

## For the GitHub Actions workflow (later)
- Runner `macos-14` (arm64) for a macOS 14 floor (or `macos-15` for 15+). Release asset name is stable:
  `VLC-Redesign-unofficial-arm64.dmg` (version is in Info.plist and the DMG volume name).
- `brew install meson ninja cmake automake qt spirv-tools bison pkg-config libnfs libupnp` plus VLC's other deps
  (ffmpeg, libass, ...: whatever meson resolves; see `.redesign/BUILD.md`).
- Build libsmb2 6.1 and VideoLAN medialibrary 0.13.2 from source into a prefix (BUILD.md has the recipe); cache that prefix
  (key on versions + runner image) and `~/Library/Caches/Homebrew`. ccache for the VLC build (`-Dc_launcher=ccache`).
- Run `make-app.sh`, then `verify_runtime.py` is optional on CI (no GUI session: use `--intf dummy` or skip).
- Upload the DMG with `gh release` / `softprops/action-gh-release`; publish a SHA256 next to it.
