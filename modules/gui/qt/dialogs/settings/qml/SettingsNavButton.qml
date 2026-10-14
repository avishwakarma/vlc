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
import VLC.Style
import VLC.Widgets as Widgets

// Figma "setting category" row: 188x40, 32 px icon cell, 14 px label.
// Selected: highlight fill, FG/1 label and the accent icon.
T.AbstractButton {
    id: control

    property string iconName
    property string selectedIconName: iconName + "-active"

    property bool selected: false

    implicitWidth: VLCStyle.dp(188, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(40, VLCStyle.scale)

    padding: VLCStyle.spacing_4
    spacing: VLCStyle.spacing_8

    hoverEnabled: true

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selected: selected
    Accessible.onPressAction: control.clicked()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    readonly property ColorContext _hover: ColorContext {
        id: hoverTheme
        colorSet: ColorContext.Item
        hovered: !control.down
        pressed: control.down
    }

    background: Rectangle {
        radius: VLCStyle.radius_xxs

        color: control.selected ? theme.bg.highlight
                                : ((control.hovered || control.down) ? hoverTheme.bg.primary : "transparent")

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus

        Behavior on color {
            ColorAnimation { duration: VLCStyle.duration_short }
        }
    }

    contentItem: Row {
        spacing: control.spacing

        Item {
            width: VLCStyle.dp(32, VLCStyle.scale)
            height: parent.height

            Widgets.SvgIcon {
                anchors.centerIn: parent
                name: control.selected ? control.selectedIconName : control.iconName
                size: VLCStyle.icon_normal
                color: (control.hovered || control.down) ? theme.fg.highlight : theme.fg.primary
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: control.text
            color: (control.selected || control.hovered || control.down) ? theme.fg.highlight : theme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
            elide: Text.ElideRight
            textFormat: Text.PlainText

            Behavior on color {
                ColorAnimation { duration: VLCStyle.duration_short }
            }
        }
    }
}
