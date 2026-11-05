**VLC Redesign (unofficial) @TAG@**, built from `@SHA@`.

An unofficial build of VLC 4 (development version) with a redesigned Qt/QML interface.
The redesign is by **[Juxtopposed](https://juxtopposed.com)** ("VLC Redesign (Community)" on Figma).
Based on [VLC media player](https://www.videolan.org/vlc/) by VideoLAN, licensed GPLv2 or later.
This is a personal project, not affiliated with or endorsed by VideoLAN.

| File | For |
| --- | --- |
| `VLC-Redesign-unofficial-arm64.dmg` | macOS 14 Sonoma or later, Apple Silicon |
| `VLC-Redesign-unofficial-win64-setup.exe` | Windows 10 or later, 64-bit (installer) |
| `VLC-Redesign-unofficial-win64.zip` | Windows 10 or later, 64-bit (portable, no install) |

It keeps its own settings and library, so it can sit next to an official VLC without touching it.

### Install

The builds are **not signed**, so your system warns you the first time.

- **macOS:** open the DMG and drag the app to Applications. Open it once; when macOS blocks it, go to
  **System Settings → Privacy & Security** and click **Open Anyway**.
- **Windows installer:** run the setup. If SmartScreen shows "Windows protected your PC", click
  **More info → Run anyway**.
- **Windows portable:** unzip anywhere and run `vlc.exe`. Settings are stored in the `portable` folder next to it.

SHA-256 checksums are attached (`*.sha256`).

Report problems with the redesign on [this fork's issue tracker](https://github.com/avishwakarma/vlc/issues), not to VideoLAN.
