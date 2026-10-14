
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

// Section heading of the settings panel ("Defaults", "Filters"): 16 px, medium.
// With `divider` a 1 px separator is drawn above it.
ColumnLayout {
    id: root

    property string text: ""
    property bool divider: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        visible: root.divider

        Layout.fillWidth: true
        Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(1, VLCStyle.scale)

        color: theme.separator
    }

    Widgets.LabelExt {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.spacing_24
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_8

        text: root.text
        font.pixelSize: VLCStyle.text_heading
        font.weight: VLCStyle.fontWeight_medium
        color: theme.fg.heading
    }
}
