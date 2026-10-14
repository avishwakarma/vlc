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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Util

// HDR toggle. There is no player API for tone mapping (the vout reads gl-tone-mapping-* /
// pl-* options only when it opens), so the button is shown but inactive for now.
Widgets.IconToolButton {
    id: root

    text: VLCIcons.info
    iconName: "HDR"

    description: qsTr("HDR")

    AccessibleCompat.id: "hdrButton"

    opacity: paintOnly ? 1.0 : 0.4

    T.ToolTip.text: qsTr("Not available yet")

    Accessible.description: qsTr("Not available yet")

    // inactive: swallow the click
    onClicked: {}
}
