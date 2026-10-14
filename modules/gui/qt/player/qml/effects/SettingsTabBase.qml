
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

// Scrolling body of a Settings tab. Long tabs scroll, the footer stays pinned.
Flickable {
    id: root

    default property alias content: column.data

    // space above the first row
    property real topPad: VLCStyle.spacing_20

    contentWidth: width
    contentHeight: column.implicitHeight + topPad + VLCStyle.spacing_20
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    clip: true

    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    ColumnLayout {
        id: column

        y: root.topPad
        width: root.width
        spacing: 0
    }
}
