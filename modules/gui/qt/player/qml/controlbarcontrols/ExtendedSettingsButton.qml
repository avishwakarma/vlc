/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import VLC.Util

// Playback / video / audio / subtitle settings with the effect panels
// (Figma 498:2937): a popover above the bar, the button turns orange while it
// is open. The QWidget extended dialog stays reachable from the main menu.
LangButton {
    id: extdSettingsBtn

    iconName: "playback-settings"
    panelMode: "settings"
    panelTab: "playback"

    description: qsTr("Playback settings")

    AccessibleCompat.id: "extendedSettingsButton"
}
