/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.MainInterface
import VLC.Dialogs

Item {
    readonly property bool mac: Qt.platform.os === "osx"

    // macOS map (the same entries are in the menu bar, which owns them there: menuBarOwned):
    //   Cmd+O Open File, Cmd+Shift+O Open Folder, Cmd+N Open Location, Cmd+, Settings, Cmd+/ Shortcuts,
    //   Cmd+W Close Window, Cmd+M Minimize, Cmd+H Hide (system), Cmd+Q Quit, Cmd+K reserved for the
    //   command palette (bound to nothing else), Cmd+F is fullscreen (VLC hotkey), not Open Folder.
    ShortcutExt{ context: Qt.WindowShortcut; menuBarOwned: true; sequence:"Ctrl+O"; onActivated: DialogsProvider.simpleOpenDialog(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+Shift+O"; onActivated: mac ? DialogsProvider.PLOpenDir() : DialogsProvider.openFileDialog(); }
    ShortcutExt{ context: Qt.WindowShortcut; enabled: !mac; sequence:"Ctrl+F"; onActivated: DialogsProvider.PLOpenDir(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+D"; onActivated: DialogsProvider.openDiscDialog(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+N"; onActivated: DialogsProvider.openNetDialog(); }
    ShortcutExt{ enabled: !mac; sequence:"Ctrl+C"; onActivated: DialogsProvider.openCaptureDialog(); }
    ShortcutExt{ sequences: [StandardKey.Paste]; onActivated: MainCtx.pasteFromClipboard(); }
    ShortcutExt{ context: Qt.WindowShortcut; menuBarOwned: true; sequence:"Ctrl+Y"; onActivated: DialogsProvider.savePlayingToPlaylist(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+R"; onActivated: DialogsProvider.openAndTranscodingDialogs(); }
    ShortcutExt{ menuBarOwned: true; sequence: mac ? "Ctrl+Shift+S" : "Ctrl+S"; onActivated: DialogsProvider.openAndStreamingDialogs(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+Q"; onActivated: DialogsProvider.quit(); }
    ShortcutExt{ menuBarOwned: true; sequence: mac ? "Ctrl+Alt+E" : "Ctrl+E"; onActivated: DialogsProvider.extendedDialog(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+I"; onActivated: DialogsProvider.mediaInfoDialog(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+J"; onActivated: DialogsProvider.mediaCodecDialog(); }
    ShortcutExt{ menuBarOwned: true; sequence: mac ? "Ctrl+Shift+M" : "Ctrl+M"; onActivated: DialogsProvider.messagesDialog(); }
    ShortcutExt{ enabled: !mac; sequence:"Ctrl+P"; onActivated: DialogsProvider.prefsDialog(); }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+T"; onActivated: DialogsProvider.gotoTimeDialog(); }

    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+L"; onActivated: MainCtx.playqueuePanel.visible = !MainCtx.playqueuePanel.visible; }

    ShortcutExt{ enabled: !mac; sequence:"F1"; onActivated: DialogsProvider.helpDialog() }
    ShortcutExt{ enabled: mac; menuBarOwned: true; sequence:"Ctrl+?"; onActivated: DialogsProvider.helpDialog() }
    ShortcutExt{ menuBarOwned: true; sequence:"Ctrl+/"; onActivated: DialogsProvider.keyboardShortcutsDialog() }
    ShortcutExt{ sequence:"F10"; onActivated: MainCtx.toggleToolbarMenu() }
    ShortcutExt{ sequence:"F11"; onActivated: MainCtx.toggleInterfaceFullScreen() }
    ShortcutExt{ menuBarOwned: true; sequence: mac ? "Ctrl+Shift+H" : "Ctrl+H"; onActivated: MainCtx.minimalView = !MainCtx.minimalView; }

    ShortcutExt{ sequences: [StandardKey.ZoomIn, "Ctrl+="]; onActivated: MainCtx.incrementIntfUserScaleFactor(true) }
    ShortcutExt{ sequences: [StandardKey.ZoomOut, "Ctrl+Shift+-"]; onActivated: MainCtx.incrementIntfUserScaleFactor(false) }

    Loader {
        active: MainCtx.mediaLibraryAvailable
        source: "qrc:///qt/qml/VLC/MediaLibrary/MLGlobalShortcuts.qml"
    }
}
