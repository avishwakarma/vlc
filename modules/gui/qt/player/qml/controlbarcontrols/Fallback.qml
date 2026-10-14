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
import VLC.Util
import VLC.Style

// Stands for an item that this version does not know (a profile saved by another version):
// nothing is drawn in the player, the customize mode shows a placeholder so that it can be removed.
Item {
    id: root

    property bool paintOnly: false

    property int focusReason: Qt.OtherFocusReason

    implicitWidth: paintOnly ? VLCStyle.windowButton_h : 0
    implicitHeight: VLCStyle.windowButton_h

    enabled: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Text {
        anchors.centerIn: parent
        visible: root.paintOnly
        text: "?"
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.text_body
    }
}
