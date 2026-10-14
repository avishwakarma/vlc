
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

// Label on the left, Figma toggle (68x32) on the right.
RowLayout {
    id: root

    property string label: ""
    property alias checked: toggle.checked
    property alias toggleEnabled: toggle.enabled

    // the application of a change is left to the owner
    signal toggled(bool checked)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Layout.fillWidth: true
    spacing: VLCStyle.spacing_10

    Widgets.LabelExt {
        Layout.fillWidth: true

        text: root.label
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.text_body
        elide: Text.ElideRight
    }

    Widgets.CheckButton {
        id: toggle

        text: ""
        Accessible.name: root.label
        onToggled: root.toggled(checked)
    }
}
