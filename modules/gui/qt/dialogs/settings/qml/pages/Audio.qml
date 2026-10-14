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


// Audio settings. Figma 3073:15879 (advanced 3180:17398).
// Stub from the settings shell: the sections are laid out, the rows are still
// to be filled in. Header of this file = Figma row -> VLC option map (see
// pages/General.qml) and the rows omitted for lack of an option.

import QtQuick

import VLC.Dialogs
import VLC.Style

SettingsPage {
    SettingSection {
        title: qsTr("Output")

        showWhenEmpty: true

        // TODO(Audio page): rows
    }

    SettingSection {
        title: qsTr("Volume")

        showWhenEmpty: true

        // TODO(Audio page): rows
    }

    SettingSection {
        title: qsTr("Loudness")

        showWhenEmpty: true

        // TODO(Audio page): rows
    }

    SettingSection {
        title: qsTr("Effects")

        showWhenEmpty: true

        // TODO(Audio page): rows
    }

    SettingSection {
        title: qsTr("Tracks")

        showWhenEmpty: true

        // TODO(Audio page): rows
    }

    SettingSection {
        title: qsTr("Visualization")

        showWhenEmpty: true

        // TODO(Audio page): rows
    }
}
