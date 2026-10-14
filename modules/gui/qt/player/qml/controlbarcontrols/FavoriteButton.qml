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

// Adds the playing media to the favorites of the media library (needs the media library).
// The look-up of the media library entry lives in FavoriteLookup.qml so that this item
// does not depend on the media library module when it is not available.
Widgets.IconToolButton {
    id: root

    readonly property bool _available: MainCtx.mediaLibraryAvailable && !!lookupLoader.item
    readonly property bool isFavorite: _available && lookupLoader.item.isFavorite

    enabled: !paintOnly && Player.isStarted && _available

    text: VLCIcons.info
    iconName: isFavorite ? "favorite-active" : "favorite"

    description: isFavorite ? qsTr("Remove from favorites") : qsTr("Add to favorites")

    AccessibleCompat.id: "favoriteButton"

    onClicked: lookupLoader.item.toggle()

    Loader {
        id: lookupLoader

        active: MainCtx.mediaLibraryAvailable && !root.paintOnly
        source: "qrc:///qt/qml/VLC/PlayerControls/FavoriteLookup.qml"
    }
}
