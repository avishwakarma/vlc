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

// Vertical hairline between two groups of items (Figma: 24 wide cell, 1.5 px line)
Item {
    id: root

    // used by the control rows when they look for the next item to focus
    property int focusReason: Qt.OtherFocusReason

    property bool paintOnly: false

    implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
    implicitHeight: VLCStyle.windowButton_h

    enabled: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.centerIn: parent
        width: VLCStyle.dp(1.5, VLCStyle.scale)
        height: VLCStyle.dp(18, VLCStyle.scale)
        radius: width / 2
        color: theme.border
    }
}
