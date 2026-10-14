
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
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets

// "#FF0000" chip with a colour swatch (Figma 614:1430). `color` is 0xRRGGBB.
FocusScope {
    id: root

    property int rgb: 0xFF0000

    signal committed(int rgb)

    implicitWidth: VLCStyle.dp(116, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property ColorContext _view: ColorContext {
        id: viewTheme
        colorSet: ColorContext.View
    }

    function hex(v) {
        return "#" + ("000000" + (v & 0xFFFFFF).toString(16).toUpperCase()).slice(-6)
    }

    opacity: enabled ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.radius_m
        color: theme.bg.secondary
        border.width: VLCStyle.dp(2, VLCStyle.scale)
        border.color: root.activeFocus ? viewTheme.visualFocus : Qt.darker(theme.bg.primary, 1.0)
    }

    TextInput {
        id: input

        focus: true
        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.spacing_12
        anchors.right: swatch.left
        anchors.rightMargin: VLCStyle.spacing_8
        anchors.verticalCenter: parent.verticalCenter

        color: viewTheme.fg.primary
        font.pixelSize: VLCStyle.text_body
        selectByMouse: true
        maximumLength: 7
        validator: RegularExpressionValidator { regularExpression: /#?[0-9A-Fa-f]{0,6}/ }

        text: root.hex(root.rgb)

        onActiveFocusChanged: if (activeFocus) selectAll()
        onEditingFinished: {
            const t = text.replace("#", "")
            if (t.length === 6)
                root.committed(parseInt(t, 16))
            text = Qt.binding(() => root.hex(root.rgb))
        }
    }

    Rectangle {
        id: swatch

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.spacing_8
        anchors.verticalCenter: parent.verticalCenter

        width: VLCStyle.dp(22, VLCStyle.scale)
        height: width
        radius: VLCStyle.radius_xs

        color: "#" + ("000000" + (root.rgb & 0xFFFFFF).toString(16)).slice(-6)
        border.width: VLCStyle.dp(2, VLCStyle.scale)
        border.color: Qt.rgba(0, 0, 0, 0.5)
    }
}
