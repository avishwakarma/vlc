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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Util

// Picture in picture: this interface maps it to the minimal view kept above the other windows
Widgets.IconToolButton {
    id: root

    readonly property bool active: MainCtx.minimalView && MainCtx.interfaceAlwaysOnTop

    enabled: !paintOnly && Player.hasVideoOutput

    text: description
    iconName: "PiP"
    checkable: false
    checked: active

    description: active ? qsTr("Exit picture in picture") : qsTr("Picture in picture")

    T.ToolTip.text: PlayerAux.tip(description, "")

    AccessibleCompat.id: "pipButton"

    onClicked: {
        if (active) {
            MainCtx.minimalView = false
            MainCtx.interfaceAlwaysOnTop = false
        } else {
            MainCtx.interfaceAlwaysOnTop = true
            MainCtx.minimalView = true
        }
    }
}
