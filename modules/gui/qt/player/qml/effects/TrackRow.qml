
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
import QtQuick.Templates as T

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Radio style row of the tracks panels (Figma 496:2495): accent check on the
// left for the selected entry, label indented by 34, 44 px high.
T.ItemDelegate {
    id: control

    property bool selected: false

    implicitWidth: VLCStyle.popoverPanel_w
    implicitHeight: VLCStyle.popoverRow_h

    leftPadding: VLCStyle.spacing_24
    rightPadding: VLCStyle.spacing_20

    spacing: VLCStyle.spacing_14

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property ColorContext _item: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item

        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
    }

    Accessible.role: Accessible.RadioButton
    Accessible.checked: selected

    contentItem: RowLayout {
        spacing: control.spacing

        Item {
            Layout.preferredWidth: VLCStyle.icon_normal
            Layout.preferredHeight: VLCStyle.icon_normal

            Widgets.SvgIcon {
                anchors.centerIn: parent

                name: "check-active"
                size: VLCStyle.icon_normal
                color: theme.fg.primary
                accentColor: theme.accent

                opacity: control.selected ? 1 : 0
                scale: control.selected ? 1 : 0.6

                Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                Behavior on scale { NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutBack } }
            }
        }

        Widgets.LabelExt {
            Layout.fillWidth: true

            text: control.text
            elide: Text.ElideRight
            font.pixelSize: VLCStyle.text_body
            // FG/A1 of the design (#969696) is the primary text colour a notch brighter
            color: (control.hovered || control.visualFocus) ? theme.fg.highlight : Qt.lighter(theme.fg.primary, 1.05)

            Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
        }
    }

    background: Rectangle {
        anchors.fill: parent
        anchors.leftMargin: VLCStyle.spacing_6
        anchors.rightMargin: VLCStyle.spacing_6

        radius: VLCStyle.radius_m
        color: itemTheme.bg.primary
        opacity: (control.hovered || control.visualFocus || control.down) ? 0.7 : 0

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus

        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
    }
}
