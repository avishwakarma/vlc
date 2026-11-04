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

import VLC.Style

// The one keyboard focus ring: VLCStyle.focusRing_width stroke in the theme focus colour,
// drawn inside its parent. Usage:
//   Widgets.FocusRing { anchors.fill: parent; active: control.visualFocus; radius: VLCStyle.radius_m }
Rectangle {
    id: root

    property bool active: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
        focused: true
    }

    visible: active
    color: "transparent"
    radius: VLCStyle.radius_m

    border.width: VLCStyle.focusRing_width
    border.color: theme.visualFocus
    border.pixelAligned: false

    Accessible.ignored: true
}
