#!/usr/bin/env python3
"""Generate Contents/Info.plist for "VLC Redesign (unofficial).app".

Reuses VLC's comprehensive CFBundleDocumentTypes / UTImportedTypeDeclarations
from share/Info.plist.in, but forces every handler rank to Alternate (so the
app is offered in "Open With" / "Change All" without hijacking anything).
"""
import copy, plistlib, sys

BUNDLE_ID = "io.github.avishwakarma.vlc-redesign"
DISPLAY = "VLC Redesign (unofficial)"


def build(template, version, build_suffix):
    src = open(template, "rb").read()
    src = (src.replace(b"@VERSION@", b"0").replace(b"@BREAKPAD_URL@", b"")
              .replace(b"@COPYRIGHT_YEARS@", b"1996-2026"))
    old = plistlib.loads(src)

    docs = []
    for d in old["CFBundleDocumentTypes"]:
        d = copy.deepcopy(d)
        d.pop("CFBundleTypeIconFile", None)  # VLC 3 icons are not shipped
        d["LSHandlerRank"] = "Alternate"
        docs.append(d)

    full = f"{version}+{build_suffix}" if build_suffix else version
    return {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleExecutable": "VLC",
        "CFBundleIconFile": "VLC",
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "VLC Redesign",
        "CFBundleDisplayName": DISPLAY,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": full,
        "LSApplicationCategoryType": "public.app-category.video",
        "LSMinimumSystemVersion": "14.0",
        "LSArchitecturePriority": ["arm64"],
        "NSHighResolutionCapable": True,
        "NSSupportsAutomaticGraphicsSwitching": True,
        "NSHumanReadableCopyright":
            "Based on VLC media player, (c) 1996-2026 VLC authors and VideoLAN (GPLv2+). "
            "Unofficial fork, not affiliated with VideoLAN.",
        "NSAppleEventsUsageDescription": "VLC Redesign wants to pause and resume external media players.",
        "NSCameraUsageDescription": "VLC Redesign wants to access the camera as requested by the user.",
        "NSMicrophoneUsageDescription": "VLC Redesign wants to access the microphone as requested by the user.",
        "NSDesktopFolderUsageDescription": "VLC Redesign wants to access the desktop folder as requested by the user.",
        "NSDocumentsFolderUsageDescription": "VLC Redesign wants to access the documents folder as requested by the user.",
        "NSDownloadsFolderUsageDescription": "VLC Redesign wants to access the downloads folder as requested by the user.",
        "NSNetworkVolumesUsageDescription": "VLC Redesign wants to access a network volume as requested by the user.",
        "NSRemovableVolumesUsageDescription": "VLC Redesign wants to access a removable volume as requested by the user.",
        "NSAppTransportSecurity": {"NSAllowsArbitraryLoads": True},
        "CFBundleDocumentTypes": docs,
        # .vlc playlist type is re-exported under the fork's own identifier so it
        # does not clash with VLC 3's org.videolan.vlc declaration.
        "UTExportedTypeDeclarations": [{
            "UTTypeDescription": "VLC Redesign playlist file",
            "UTTypeConformsTo": ["public.text", "public.playlist"],
            "UTTypeIdentifier": BUNDLE_ID + ".playlist",
            "UTTypeTagSpecification": {
                "public.filename-extension": ["vlc"],
                "public.mime-type": ["application/x-videolan-vlc", "application/videolan-vlc"],
            },
        }],
        "UTImportedTypeDeclarations": old["UTImportedTypeDeclarations"],
    }


if __name__ == "__main__":
    template, out, version, suffix = sys.argv[1:5]
    with open(out, "wb") as f:
        plistlib.dump(build(template, version, suffix), f)
