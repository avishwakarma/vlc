/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Menus as Menus

// "..." button of the title bar: the main menu (Figma 247:447)
Widgets.IconToolButton {
    id: root

    signal requestLockUnlockAutoHide(bool lock)

    // title bar cell: 28x28
    readonly property bool keepSize: true
    implicitWidth: VLCStyle.windowButton_h
    implicitHeight: VLCStyle.windowButton_h

    iconName: "more"
    text: VLCIcons.more
    description: qsTr("Menu")

    AccessibleCompat.id: "topBarMenuButton"

    checked: contextMenu.shown
    enabled: !paintOnly

    onClicked: contextMenu.popup(this.mapToGlobal(0, height))

    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

    function forceUnlock() {
        contextMenu?.close()
    }

    Menus.QmlGlobalMenu {
        id: contextMenu

        ctx: MainCtx

        onAboutToShow: root.requestLockUnlockAutoHide(true)
        onAboutToHide: root.requestLockUnlockAutoHide(false)
    }
}
