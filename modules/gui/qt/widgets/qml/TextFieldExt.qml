/*****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
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
import QtQuick.Controls.Basic


import VLC.Style

TextField {
    id: control

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.TextField

        focused: control.activeFocus
        hovered: control.hovered
        enabled: control.enabled
    }

    selectedTextColor : theme.fg.highlight
    selectionColor : theme.bg.highlight
    color : theme.fg.primary
    placeholderTextColor: theme.placeholder

    font.pixelSize: VLCStyle.text_body

    verticalAlignment: Text.AlignVCenter

    property real radius: VLCStyle.radius_m

    // well color (BG/B2); the settings search field uses `theme.bg.primary` (BG/A5)
    property color backgroundColor: theme.bg.secondary

    leftPadding: VLCStyle.spacing_12
    rightPadding: VLCStyle.spacing_12

    opacity: enabled ? 1.0 : 0.5

    background: Rectangle {
        implicitWidth: VLCStyle.size_input_w
        implicitHeight: VLCStyle.input_h
        border.width: VLCStyle.border_input
        color: control.backgroundColor
        border.color: control.enabled ? theme.border : color
        border.pixelAligned: (radius < Number.EPSILON)
        radius: control.radius

        Behavior on border.color {
            ColorAnimation { duration: VLCStyle.duration_short }
        }
    }

}
