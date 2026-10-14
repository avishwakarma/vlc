
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

// B2 well with a label on the left and an editable number with a unit on the
// right ("Top  0 px", Figma 543:990).
FocusScope {
    id: root

    property string label: ""
    property real value: 0
    property string unit: ""
    property int decimals: 0
    property real from: 0
    property real to: 100000

    signal committed(real value)

    implicitWidth: VLCStyle.dp(141, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(33, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property ColorContext _view: ColorContext {
        id: viewTheme
        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.fill: parent

        radius: VLCStyle.radius_m
        color: theme.bg.secondary
        border.width: root.activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: viewTheme.visualFocus
    }

    Widgets.LabelExt {
        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.spacing_12
        anchors.verticalCenter: parent.verticalCenter

        text: root.label
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.text_body
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.spacing_12
        anchors.verticalCenter: parent.verticalCenter

        spacing: VLCStyle.spacing_4

        TextInput {
            id: input

            focus: true
            width: Math.max(VLCStyle.dp(14, VLCStyle.scale), contentWidth)
            horizontalAlignment: TextInput.AlignRight
            color: viewTheme.fg.primary
            font.pixelSize: VLCStyle.text_body
            selectByMouse: true
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: root.from; top: root.to }

            text: root.value.toFixed(root.decimals)

            onActiveFocusChanged: if (activeFocus) selectAll()
            onEditingFinished: {
                const v = Number(text)
                if (!isNaN(v))
                    root.committed(Math.max(root.from, Math.min(root.to, v)))
                text = Qt.binding(() => root.value.toFixed(root.decimals))
            }
        }

        Widgets.LabelExt {
            anchors.baseline: input.baseline

            text: root.unit
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor
    }
}
