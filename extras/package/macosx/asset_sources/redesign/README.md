# Redesigned app icon

App icon and cone by Juxtopposed (https://juxtopposed.com), from the Figma Community file
"VLC Redesign (Community)"; macOS icon tile composition derived from it.

- `cone.svg`: the designer's cone, flat #D37918, viewBox 0 0 24 24 (also used as `modules/gui/qt/pixmaps/misc/cone.svg`).
- `app_icon.svg`: 1024x1024 macOS icon (824px superellipse tile, dark gradient #232323 to #0E0E0E, centered cone).
- `png/`: renders at 16..1024, plus `cone_96.png` (flat cone, used for the small in-UI holiday/april-fools slots).
- `VLC.iconset/` and **`VLC.icns`**: macOS bundle icon. Packagers should copy `VLC.icns` into
  `VLC.app/Contents/Resources/` and set `CFBundleIconFile` to `VLC`. Also copied to `extras/package/macosx/dmg/disk_image.icns`.
- `share/icons/{16x16,32x32,48x48,128x128,256x256}/vlc.png` are renders of `app_icon.svg` (Qt window icon, about dialog, systray).

Regenerate: `rsvg-convert -w N -h N app_icon.svg -o ...` then `iconutil -c icns VLC.iconset`.
