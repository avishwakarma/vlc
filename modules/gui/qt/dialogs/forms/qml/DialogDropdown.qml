/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.Widgets as Widgets
import VLC.Style

// Flat 34 px filter dropdown of the dialog title bars (Figma: BG/A5 pill, 12/8 padding, chevron).
// Same API as ComboBoxExt; the option list is the standard Dropdown popup.
Widgets.ComboBoxExt {
    id: control

    compact: true

    ColorContext {
        id: fieldTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.TextField
    }

    // BG/A5
    bgColor: fieldTheme.bg.primary

    implicitHeight: VLCStyle.dp(34, VLCStyle.scale)

    topPadding: 0
    bottomPadding: 0
    leftPadding: VLCStyle.spacing_12
    rightPadding: VLCStyle.spacing_8

    background: Rectangle {
        radius: VLCStyle.radius_m
        color: (control.hovered || control.pressed || control.popup.visible) ? control._hoverTheme.bg.primary
                                                                              : control.bgColor

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: control.colorContext.visualFocus

        Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
    }
}
