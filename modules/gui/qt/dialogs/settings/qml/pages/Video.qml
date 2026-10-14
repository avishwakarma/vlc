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


// Video settings. Figma 3073:14187 (advanced 3073:15375).
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

        // TODO(Video page): rows
    }

    SettingSection {
        title: qsTr("Picture")

        showWhenEmpty: true

        // TODO(Video page): rows
    }

    SettingSection {
        title: qsTr("Deinterlacing")

        showWhenEmpty: true

        // TODO(Video page): rows
    }

    SettingSection {
        title: qsTr("Framing")

        showWhenEmpty: true

        // TODO(Video page): rows
    }

    SettingSection {
        title: qsTr("Snapshots")

        showWhenEmpty: true

        // TODO(Video page): rows
    }
}
