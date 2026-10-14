# Redesigned app icon

Logos by Juxtopposed (https://juxtopposed.com), from the Figma Community file "VLC Redesign (Community)"
(file key jf8IwqZrI8Q0bWCTounVPx); macOS icon tile composition derived from them.

- `logo.svg`: Figma node 10004:14787 "logo", orange cone (#D37918, the accent), viewBox 0 0 105.75 123.38.
- `logo-white.svg`: Figma node 10004:14788 "logo-white", same shapes in white (monochrome; used for the macOS menu bar template icon).
- `make_logo_assets.py` derives every in-app asset from these two files (see its header).

- `cone.svg`: `logo.svg` centred in a 24x24 box (21px tall), flat #D37918 (also used as `modules/gui/qt/pixmaps/misc/cone.svg`).
- `app_icon.svg`: 1024x1024 macOS icon (824px superellipse tile, dark gradient #232323 to #0E0E0E, centered logo).
- `png/`: renders at 16..1024, plus `cone_96.png` (flat cone, used for the small in-UI holiday/april-fools slots).
- `VLC.iconset/` and **`VLC.icns`**: macOS bundle icon. Packagers should copy `VLC.icns` into
  `VLC.app/Contents/Resources/` and set `CFBundleIconFile` to `VLC`. Also copied to `extras/package/macosx/dmg/disk_image.icns`.
- `share/icons/{16x16,32x32,48x48,128x128,256x256}/vlc.png` are renders of `app_icon.svg` (Qt window icon, about dialog, systray).

Regenerate: `rsvg-convert -w N -h N app_icon.svg -o ...` then `iconutil -c icns VLC.iconset`.

macOS menu bar: `modules/gui/qt/pixmaps/misc/tray{.svg,.png,@2x.png}` are `logo-white` at 18pt (36px @2x); the Qt systray
loads them with `QIcon::setIsMask(true)` so macOS treats them as a template image.
