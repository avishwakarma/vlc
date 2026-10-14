
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

import VLC.Style
import VLC.Util

// Accent tonal button (Figma "Test", 536:1059): accent text on the accent
// bright fill, 32 px high.
T.Button {
    id: control

    implicitWidth: VLCStyle.dp(70, VLCStyle.scale)
    implicitHeight: VLCStyle.toggle_h

    font.pixelSize: VLCStyle.text_body
    opacity: enabled ? 1.0 : 0.4

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ButtonTonal

        enabled: control.enabled
        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: theme.fg.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: VLCStyle.radius_s
        color: theme.bg.primary
        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus
    }
}
