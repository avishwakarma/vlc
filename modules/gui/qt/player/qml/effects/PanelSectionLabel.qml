
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

// Section label of the tracks panels ("Embedded Tracks", "Output Device") with
// optional tool buttons on the right. A 1 px divider is drawn above when
// `divider` is set.
ColumnLayout {
    id: root

    property string text: ""
    property bool divider: false

    default property alias tools: toolRow.data

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    spacing: 0

    Rectangle {
        visible: root.divider

        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.spacing_12
        implicitHeight: VLCStyle.dp(1, VLCStyle.scale)

        color: theme.bg.secondary
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.topMargin: VLCStyle.dp(22, VLCStyle.scale)
        Layout.bottomMargin: VLCStyle.spacing_16

        Widgets.LabelExt {
            Layout.fillWidth: true

            text: root.text
            font.pixelSize: VLCStyle.text_body
            color: theme.fg.secondary
            elide: Text.ElideRight
        }

        Row {
            id: toolRow

            spacing: VLCStyle.spacing_12
        }
    }
}
