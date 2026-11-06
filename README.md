# VLC media player

> **About this fork:** this is an unofficial fork of VLC that implements a full redesign of
> the Qt/QML desktop interface. It is not affiliated with or endorsed by VideoLAN.
>
> **Design credit:** the redesign, including the layout, color system and icon set, is by
> **[Juxtopposed](https://juxtopposed.com)**, from the Figma Community file "VLC Redesign (Community)".
> All credit for the design goes to them; any implementation mistakes are ours.
>
> This fork was inspired by Juxtopposed's video about the redesign:
> https://www.youtube.com/watch?v=ERFeOgqk324

## Why this fork exists

It started with a YouTube video.

[Juxtopposed](https://juxtopposed.com) put a lot of effort into redesigning VLC, to make our
beloved media player look modern and become easier to use. You can watch it
[here](https://www.youtube.com/watch?v=ERFeOgqk324).

After watching it, I had one thought.

Wait, I am a software engineer. This is what I do for a living.

And now we have Claude Code as well. So it does not hurt to try.

This fork is that try. The design is hers. The implementation is built on top of the
Qt interface of VLC 4.0, with Claude Code doing a lot of the heavy lifting.

It is unofficial and unsigned, and it will have rough edges. Issues are welcome.

## Download VLC Redesign (unofficial)

[![Build](https://github.com/avishwakarma/vlc/actions/workflows/build.yml/badge.svg?branch=redesign)](https://github.com/avishwakarma/vlc/actions/workflows/build.yml?query=branch%3Aredesign)

| Platform | Download | Requirements |
| --- | --- | --- |
| macOS | [VLC-Redesign-unofficial-arm64.dmg](https://github.com/avishwakarma/vlc/releases/latest/download/VLC-Redesign-unofficial-arm64.dmg) | macOS 14 Sonoma or later, Apple Silicon |
| Windows | [VLC-Redesign-unofficial-win64-setup.exe](https://github.com/avishwakarma/vlc/releases/latest/download/VLC-Redesign-unofficial-win64-setup.exe) | Windows 10 or later, 64-bit |
| Windows (portable) | [VLC-Redesign-unofficial-win64.zip](https://github.com/avishwakarma/vlc/releases/latest/download/VLC-Redesign-unofficial-win64.zip) | Windows 10 or later, 64-bit |

Older versions and release notes are on the [Releases page](https://github.com/avishwakarma/vlc/releases).

The app is called **VLC Redesign (unofficial)**. It keeps its own settings and library, so it can be
installed next to the official VLC without touching it.

The builds are **not signed**, so your system will warn you the first time you open them:

- **macOS:** open the DMG and drag the app to Applications. Open it once; when macOS blocks it, go to
  **System Settings → Privacy & Security** and click **Open Anyway**.
- **Windows:** run the installer. If SmartScreen shows "Windows protected your PC", click
  **More info → Run anyway**. For the portable version, unzip the folder anywhere and run `vlc.exe`;
  its settings stay in the `portable` folder next to it.

**How releases are made:** pushing a tag named `v*` (for example `v0.1.0`) on `redesign` builds
the app with [GitHub Actions](.github/workflows/build.yml) and publishes a release with the three
files above. Test builds of the branch can be started by hand from the Actions tab.

This is a personal project, not a VideoLAN release. Please report problems with the redesign on
[this fork's issue tracker](https://github.com/avishwakarma/vlc/issues), not to VideoLAN.
The redesign's source code is on the `redesign` branch of this repository.

**VLC** is a libre and open source **media player** and **multimedia engine**,
focused on **playing everything**, and **running everywhere**.

**VLC** can play most multimedia files, discs, streams, devices and is also able to
convert, encode, **stream** and manipulate streams into numerous formats.

VLC is used by many over the world, on numerous platforms, for very different use cases.

The **engine of VLC** can be embedded into 3rd party applications, and is called _libVLC_.

**VLC** is part of the [VideoLAN project](https://videolan.org) and
is developed and supported by a community of volunteers.

The VideoLAN project was started at the university [École Centrale Paris](https://www.centralesupelec.fr/) who
relicensed VLC under the GPLv2 license in February 2001. Since then, VLC has
been downloaded **billions** of times.

## License

**VLC** is released under the GPLv2 _(or later)_ license.
_On some platforms, it is de facto GPLv3, because of the licenses of dependencies_.

**libVLC**, the engine is released under the LGPLv2 _(or later)_ license. \
This allows embedding the engine in 3rd party applications, while letting them to be licensed under other licenses.

# Platforms

VLC is available for the following platforms:

- [Windows] _(from 7 and later, including UWP platforms and all versions of Windows 10)_
- [macOS] _(10.10 and later)_
- [GNU/Linux] and affiliated
- [BSD] and affiliated
- [Android] _(4.2 and later)_, including Android TV and Android Auto
- [iOS] _(9 and later)_, including AppleTV and iPadOS
- Haiku, OS/2 and a few others.

[Windows]: https://www.videolan.org/vlc/download-windows.html
[macOS]: https://www.videolan.org/vlc/download-macosx.html
[GNU/Linux]: https://www.videolan.org/vlc/#download
[BSD]: https://www.videolan.org/vlc/download-freebsd.html
[Android]: https://www.videolan.org/vlc/download-android.html
[iOS]: https://www.videolan.org/vlc/download-ios.html

Not all platforms receive the same amount of care, due to our limited resources.

**Nota Bene**: The [Android app](https://code.videolan.org/videolan/vlc-android/) and
the [iOS app](https://code.videolan.org/videolan/vlc-ios/) are located in different repositories
than the main one.

# Contributing & Community

**VLC** is maintained by a community of people, and VideoLAN is not paying any of them.\
The community is composed of developers, helpers, maintainers, designers and writers that want
this open source project to thrive.

The main development of VLC is done in the C language, but this repository also contains
plenty of C++, Obj-C, asm and Rust.

Other repositories linked to vlc are done in languages including Kotlin/Java [(Android)](https://code.videolan.org/videolan/vlc-android/),
Swift [(iOS)](https://code.videolan.org/videolan/vlc-ios/), and C# [(libVLCSharp)](https://code.videolan.org/videolan/libvlcsharp/).

We need help with the following tasks:

- Coding
- Packaging for Windows, macOS and Linux distributions
- Technical writing for the documentation
- Design
- Support
- Community management and communication.

Please contribute :)

We are on IRC. You can find us on the **#videolan** channel on _[Libera.chat]_.

[Libera.chat]: https://libera.chat

## Contributions

Contributions are now done through Merge Requests on our [GitLab repository](https://code.videolan.org/videolan/vlc/).

CI and discussions should be resolved before a Merge Request can be merged.

# libVLC

**libVLC** is an embeddable engine for 3rd party applications and frameworks.

It runs on the same platforms as VLC _(and sometimes on more)_ and can provide playback,
streaming and conversion of multimedia files and streams.

**libVLC** has numerous bindings for other languages, such as C++, Python and C#.

# Support

## Links

Some useful links that might help you:

- [VLC web site](https://www.videolan.org/vlc/)
- [Support](https://www.videolan.org/support/)
- [Forums](https://forum.videolan.org/)
- [Wiki](https://wiki.videolan.org/)
- [Developer's Corner](https://wiki.videolan.org/Developers_Corner)
- [VLC hacking guide](https://wiki.videolan.org/Hacker_Guide)
- [Bugtracker](https://code.videolan.org/videolan/vlc/-/issues)
- [VideoLAN web site](https://www.videolan.org/)

## Source Code sitemap

```
ABOUT-NLS          - Notes on the Free Translation Project.
AUTHORS            - VLC authors.
COPYING            - The GPL license.
COPYING.LIB        - The LGPL license.
INSTALL            - Installation and building instructions.
NEWS               - Important modifications between the releases.
README             - Project summary.
THANKS             - VLC contributors.

bin/               - VLC binaries.
bindings/          - libVLC bindings to other languages.
compat/            - compatibility library for operating systems missing
                     essential functionalities.
contrib/           - Facilities for retrieving external libraries and building
                     them for systems that don't have the right versions.
doc/               - Miscellaneous documentation.
extras/analyser    - Code analyser and editor specific files.
extras/buildsystem - Different build system specific files.
extras/misc        - Files that don't fit in the other extras/ categories.
extras/package     - VLC packaging specific files such as spec files.
extras/tools/      - Facilities for retrieving external building tools needed
                     for systems that don't have the right versions.
include/           - Header files.
lib/               - libVLC source code.
modules/           - VLC plugins and modules. Most of the code is here.
po/                - VLC translations.
share/             - Common resource files.
src/               - libvlccore source code.
test/              - Testing system.
```
