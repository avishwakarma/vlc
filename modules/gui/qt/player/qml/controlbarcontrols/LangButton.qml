/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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


import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: root

    // Proprerties

    readonly property var _parentItem: {
        if ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null))
            return rootPlayer
        else
            return g_mainDisplay
    }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    // Settings

    text: VLCIcons.audiosub

    // Redesign: the control bar instantiates one button for audio ("audio") and one
    // for subtitles ("subtitles"); the legacy combined button keeps the glyph.
    iconName: ""
    iconNameChecked: iconName !== "" ? (iconName + "-active") : ""

    // what the popover opens on (Figma Controls 491:1780): the tracks panel
    // on the audio / subtitles tab, or the settings panel
    property string panelMode: "tracks"
    property string panelTab: "audio"

    // the settings button opens the compact Playback menu first ("More Settings…" opens the panel)
    property bool quickMenu: false

    checked: ((menuLoader.item?.visible ?? false)
              && (panelMode === "settings" || menuLoader.item.tab === panelTab))
             || (quickLoader.item?.visible ?? false)

    enabled: menuLoader.status === Loader.Ready

    description: qsTr("Languages and tracks")

    AccessibleCompat.id: "langButton"

    // Events

    onClicked: {
        if (quickMenu) {
            const quick = quickLoader.item
            if (menuLoader.item.visible)
                menuLoader.item.close()
            else if (quick.visible)
                quick.close()
            else if (Date.now() - quick.closedAt > 250)
                quick.open()
            return
        }

        const menu = menuLoader.item
        if (menu.visible)
            menu.close()
        else if (Date.now() - menu.closedAt > 250) // a press outside just closed it
            menu.openMode(root.panelMode, root.panelTab)
    }

    // Children

    Loader {
        id: menuLoader

        sourceComponent: TracksMenu {
            id: menu

            parent: root._parentItem

            z: 1

            focus: true

            colorContext.palette: root.colorContext.palette

            onOpened: {
                root.requestLockUnlockAutoHide(true)
                root.menuOpened(menu)
            }

            onClosed: {
                root.requestLockUnlockAutoHide(false)
                root.forceActiveFocus()
                root.menuOpened(null)
            }
        }
    }

    Loader {
        id: quickLoader

        active: root.quickMenu

        sourceComponent: PlaybackQuickMenu {
            id: quick

            parent: root._parentItem

            z: 1

            focus: true

            colorContext.palette: root.colorContext.palette

            property bool _more: false

            onRequestMoreSettings: _more = true

            onOpened: {
                root.requestLockUnlockAutoHide(true)
                root.menuOpened(quick)
            }

            onClosed: {
                root.requestLockUnlockAutoHide(false)
                root.forceActiveFocus()
                root.menuOpened(null)
                if (_more) {
                    _more = false
                    menuLoader.item.openMode(root.panelMode, root.panelTab)
                }
            }
        }
    }

    function forceUnlock() {
        if ((quickLoader) && (quickLoader.item))
            quickLoader.item.close()
        if((menuLoader)&&(menuLoader.item))
            menuLoader.item.close()
    }
}
