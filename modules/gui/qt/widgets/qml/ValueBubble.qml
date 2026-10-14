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
import VLC.Style
import VLC.Util

// Small floating value bubble used by the player control bar (seek time, volume value).
// Figma 2245:9805: radius 6, padding 10, surface rgba(.95), shadow 0 8 15 rgba(0,0,0,.46).
// This is a plain item (not a popup) so it follows its anchor item.
Item {
    id: root

    property bool shown: false

    // main text, and an optional dimmed suffix (e.g. "%")
    property string text
    property string suffix

    property int colorSet: ColorContext.Pane

    property real radius: VLCStyle.radius_m
    property real padding: VLCStyle.spacing_10

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: root.colorSet
    }

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: row.implicitHeight + padding * 2

    width: implicitWidth
    height: implicitHeight

    opacity: shown ? 1.0 : 0.0
    visible: opacity > 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: VLCStyle.duration_short
            easing.type: Easing.InOutSine
        }
    }

    Accessible.role: Accessible.ToolTip
    Accessible.name: text + suffix

    Rectangle {
        id: surface

        anchors.fill: parent

        radius: root.radius
        color: theme.bg.primary

        RoundedRectangleShadow {
            blurRadius: VLCStyle.shadow_floating.blur
            yOffset: VLCStyle.shadow_floating.y
            color: Qt.rgba(0, 0, 0, VLCStyle.shadow_floating.alpha)
        }
    }

    Row {
        id: row

        anchors.centerIn: parent

        Text {
            text: root.text
            color: theme.fg.primary
            font.pixelSize: (root.colorSet === ColorContext.Menu) ? VLCStyle.text_time : VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
        }

        Text {
            visible: root.suffix !== ""
            text: root.suffix
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
        }
    }
}
