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

// Playlist Name of the playing media as text
Item {
    id: root

    // used by the control rows when they look for the next item to focus
    property int focusReason: Qt.OtherFocusReason

    property bool paintOnly: false

    readonly property string _real: (qsTr("Play Queue"))

    // the customize mode shows a placeholder when there is nothing to show
    readonly property string value: (_real !== "") ? _real : (paintOnly ? qsTr("Playlist Name") : "")

    implicitWidth: Math.min(label.implicitWidth, VLCStyle.dp(280, VLCStyle.scale))
    implicitHeight: VLCStyle.iconButton_h

    Accessible.role: Accessible.StaticText
    Accessible.name: value
    AccessibleCompat.id: "playlistNameWidget"

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton
    }

    Text {
        id: label

        anchors.fill: parent

        text: root.value
        color: theme.fg.primary
        font.pixelSize: VLCStyle.text_body
        font.weight: VLCStyle.fontWeight_regular
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
