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
import VLC.Dialogs
import VLC.Style

// Figma accent color picker: a well holding one cell per preset. The selected
// cell has the tonal accent fill, the other swatches are drawn dimmed.
// `option` is the virtual "accent" ConfigOption (choices = presets).
T.Control {
    id: control

    property ConfigOption option: null

    readonly property var presets: option ? option.choices : []

    readonly property int currentIndex: {
        const v = option ? String(option.value).toLowerCase() : ""
        for (let i = 0; i < presets.length; ++i) {
            if (String(presets[i].value).toLowerCase() === v)
                return i
        }
        return -1
    }

    implicitWidth: VLCStyle.dp(320, VLCStyle.scale)
    implicitHeight: VLCStyle.input_h

    padding: VLCStyle.spacing_2

    focusPolicy: Qt.StrongFocus

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            const next = currentIndex + ((event.key === Qt.Key_Right) === !mirrored ? 1 : -1)
            if (next >= 0 && next < presets.length) {
                option.value = presets[next].value
                event.accepted = true
                return
            }
        }
        Navigation.defaultKeyAction(event)
    }

    Accessible.role: Accessible.RadioButton

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ComboBox
        focused: control.visualFocus
    }

    readonly property ColorContext _tonal: ColorContext {
        id: tonal
        colorSet: ColorContext.ButtonTonal
    }

    readonly property ColorContext _item: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
        hovered: true
    }

    background: Rectangle {
        radius: VLCStyle.radius_m
        color: theme.bg.secondary

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus
    }

    contentItem: Row {
        spacing: VLCStyle.spacing_4

        Repeater {
            model: control.presets

            delegate: T.AbstractButton {
                id: cell

                required property int index
                required property var modelData

                readonly property bool selected: control.currentIndex === index

                width: (control.availableWidth - (control.presets.length - 1) * VLCStyle.spacing_4)
                       / Math.max(1, control.presets.length)
                height: control.availableHeight

                focusPolicy: Qt.NoFocus
                hoverEnabled: true
                text: modelData.text

                onClicked: control.option.value = modelData.value

                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.text
                Accessible.checked: selected

                background: Rectangle {
                    radius: VLCStyle.radius_s
                    color: cell.selected ? tonal.bg.primary
                                         : (cell.hovered ? itemTheme.bg.primary : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: VLCStyle.duration_short }
                    }
                }

                contentItem: Item {
                    Rectangle {
                        anchors.centerIn: parent

                        width: VLCStyle.dp(19.56, VLCStyle.scale)
                        height: VLCStyle.dp(20, VLCStyle.scale)
                        radius: VLCStyle.radius_xxs

                        color: cell.modelData.value
                        opacity: cell.selected ? 1.0 : (cell.hovered || cell.down ? 0.95 : 0.75)

                        border.width: VLCStyle.dp(1, VLCStyle.scale)
                        border.color: Qt.darker(color, 1.4)

                        scale: cell.down ? 0.92 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: VLCStyle.duration_short }
                        }

                        Behavior on scale {
                            NumberAnimation { duration: VLCStyle.duration_veryShort }
                        }
                    }
                }

                T.ToolTip.visible: hovered
                T.ToolTip.text: modelData.text
                T.ToolTip.delay: VLCStyle.delayToolTipAppear
            }
        }
    }
}
