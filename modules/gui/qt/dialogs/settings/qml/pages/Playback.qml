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


// Playback settings. Figma 3062:12552 (advanced 3072:13408).
// Stub from the settings shell: the sections are laid out, the rows are still
// to be filled in. Header of this file = Figma row -> VLC option map (see
// pages/General.qml) and the rows omitted for lack of an option.

import QtQuick

import VLC.Dialogs
import VLC.Style

SettingsPage {
    SettingSection {
        title: qsTr("Startup")

        showWhenEmpty: true

        // TODO(Playback page): rows
    }

    SettingSection {
        title: qsTr("Tracks")

        showWhenEmpty: true

        // TODO(Playback page): rows
    }

    SettingSection {
        title: qsTr("Order")

        showWhenEmpty: true

        // TODO(Playback page): rows
    }

    SettingSection {
        title: qsTr("Seeking")

        showWhenEmpty: true

        // TODO(Playback page): rows
    }

    SettingSection {
        title: qsTr("Files & Discs")

        showWhenEmpty: true

        // TODO(Playback page): rows
    }
}
