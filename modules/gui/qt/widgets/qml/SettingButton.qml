/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

// Figma "Button" (360x32, radius 4): optional 20 px icon + 14 px label, centered.
//   SettingButton { text: qsTr("Show Advanced Settings"); iconName: "settings" }
// `variant2` selects the lighter inset variant (bg A4, text A2).
T.Button {
    id: control

    // SvgIcon name, empty for no icon
    property string iconName: ""

    property bool variant2: false

    implicitWidth: VLCStyle.size_button_w
    implicitHeight: VLCStyle.toggle_h

    padding: VLCStyle.spacing_8
    spacing: VLCStyle.spacing_6

    font.pixelSize: VLCStyle.text_body

    opacity: enabled ? 1.0 : 0.3

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    Accessible.onPressAction: control.clicked()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View

        enabled: control.enabled
        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
    }

    readonly property ColorContext _inset: ColorContext {
        id: inset
        colorSet: ColorContext.ComboBox
    }

    readonly property ColorContext _item: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item

        hovered: control.hovered
        pressed: control.down
    }

    readonly property color _fg: variant2 ? ((hovered || down) ? theme.fg.highlight : theme.fg.primary)
                                          : ((hovered || down) ? theme.fg.primary : theme.fg.secondary)

    background: Rectangle {
        radius: VLCStyle.radius_s

        color: control.variant2 ? ((control.hovered || control.down) ? itemTheme.bg.primary : inset.bg.primary)
                                : ((control.hovered || control.down) ? inset.bg.primary : theme.bg.secondary)

        border.width: control.visualFocus ? VLCStyle.focusRing_width : 0
        border.color: theme.visualFocus

        Behavior on color {
            ColorAnimation { duration: VLCStyle.duration_short }
        }
    }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        RowLayout {
            id: row

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)

            spacing: control.spacing

            SvgIcon {
                visible: control.iconName !== ""
                name: control.iconName
                size: VLCStyle.icon_button
                color: control._fg
            }

            Text {
                text: control.text
                color: control._fg
                font: control.font
                elide: Text.ElideRight
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter

                Layout.fillWidth: true

                Accessible.ignored: true
            }
        }
    }
}
