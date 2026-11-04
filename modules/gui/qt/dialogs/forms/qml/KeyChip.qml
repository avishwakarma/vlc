/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.MainInterface
import VLC.Style

// Compact key cap of the Keyboard Shortcuts sheet (one per key: modifiers use the
// macOS glyphs, e.g. [⌥] [⌘] [S]). The big onboarding variant is onboarding/KeyCap.qml.
Item {
    id: root

    property string text

    implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + VLCStyle.spacing_8 * 2)

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.radius_xs
        color: theme.bg.primary
        border.width: VLCStyle.border
        border.color: theme.border
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        color: theme.fg.heading
        font.pixelSize: VLCStyle.text_caption
        font.weight: VLCStyle.fontWeight_medium
    }
}
