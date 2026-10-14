
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

// Icon + label link of the panel footer ("Open Advanced Settings").
T.Button {
    id: control

    property string iconName: ""

    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

    leftPadding: VLCStyle.spacing_12
    rightPadding: VLCStyle.spacing_12

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property ColorContext _item: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
        hovered: control.hovered
        pressed: control.down
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    contentItem: Row {
        spacing: VLCStyle.spacing_8

        Widgets.SvgIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: control.iconName !== ""
            name: control.iconName
            size: VLCStyle.dp(20, VLCStyle.scale)
            color: (control.hovered || control.visualFocus) ? theme.fg.primary : theme.fg.secondary
        }

        Widgets.LabelExt {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font.pixelSize: VLCStyle.text_body
            color: (control.hovered || control.visualFocus) ? theme.fg.primary : theme.fg.secondary
        }
    }

    background: Rectangle {
        radius: VLCStyle.radius_s
        color: itemTheme.bg.primary
        opacity: (control.hovered || control.down) ? 0.6 : 0

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus

        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
    }
}
