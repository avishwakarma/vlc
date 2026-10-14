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

pragma Singleton

import QtQuick

// Bridge between the player window and the items shown in its title bar / control bar.
// The player (Player.qml) publishes its state here and handles the requests, the
// control bar items (player/qml/controlbarcontrols) are loaded dynamically and use it
// instead of relying on ids of the creation context.
QtObject {
    id: root

    // state published by the player
    property bool playlistVisible: false
    property bool sidebarVisible: false
    property bool windowFullscreen: false
    property bool showCSD: false
    property string breadcrumb: ""
    property string title: ""
    // for d&d functionality of the queue button
    property Item plListView

    // requests handled by the player
    signal toggleQueue()
    signal toggleSidebar()
    signal breadcrumbClicked()
    signal requestLockUnlockAutoHide(bool lock)
}
