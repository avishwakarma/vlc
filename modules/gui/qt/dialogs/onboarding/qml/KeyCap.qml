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

// Key cap of the shortcuts step: window bg, 3 px bright divider border, r12 and a 6 px
// flat shadow under it.
Item {
    id: root

    property string text
    // horizontal padding inside the border (20 for letters/words, 12 for single symbols)
    property real hPadding: VLCStyle.spacing_20

    function dp(v) { return v * VLCStyle.scale }

    implicitWidth: label.implicitWidth + hPadding * 2 + border * 2
    implicitHeight: label.implicitHeight + VLCStyle.spacing_4 * 2 + border * 2

    readonly property real border: dp(3)

    ColorContext {
        id: windowTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    ColorContext {
        id: viewTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    // flat 0 6 0 shadow
    Rectangle {
        y: dp(6)
        width: parent.width
        height: parent.height
        radius: dp(12)
        color: Qt.alpha(viewTheme.fg.secondary, 0.25)
    }

    Rectangle {
        anchors.fill: parent
        radius: dp(12)
        color: windowTheme.bg.primary
        border.width: root.border
        border.color: viewTheme.border
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: viewTheme.fg.highlight
        font.pixelSize: VLCStyle.text_heading
        font.weight: VLCStyle.fontWeight_light
        lineHeightMode: Text.FixedHeight
        lineHeight: font.pixelSize * 1.75
        // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
        transform: Translate { y: VLCStyle.text_heading * 0.27 }
    }
}
