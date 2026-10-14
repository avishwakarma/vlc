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


// Privacy settings. Figma 3062:11911.
//
// Figma row                                  -> VLC option
//   Save recently played items               -> save-recentplay
//   Remember the playback position           -> restore-playback-pos (ON = Always, OFF = Never; "Ask" shows as OFF)
//   Never remember items matching            -> (omitted: qt-recentplay-filter is gone in 4.0)
//   Clear history now                        -> (omitted: an action without an option or API)
//   Fetch titles and cover art from the internet -> metadata-network-access
//   Submit played tracks to last.fm          -> extraInterface:audioscrobbler
//   Last.fm username                         -> lastfm-username
//   (second "Last.fm username" row)          -> lastfm-password (the Figma row is labelled "username" twice)
//   Last.fm submission URL                   -> scrobbler-url

import QtQuick

import VLC.Dialogs
import VLC.Style

SettingsPage {
    SettingSection {
        title: qsTr("History")

        SettingRow {
            label: qsTr("Save recently played items")
            option: SettingsModel.option("save-recentplay")
        }

        SettingRow {
            label: qsTr("Remember the playback position")
            option: SettingsModel.option("restore-playback-pos")
            kind: "toggle"
            valueOn: 2  // VLC_PLAYER_RESTORE_PLAYBACK_POS_ALWAYS
            valueOff: 0 // VLC_PLAYER_RESTORE_PLAYBACK_POS_NEVER
        }
    }

    SettingSection {
        title: qsTr("Network")

        SettingRow {
            label: qsTr("Fetch titles and cover art from the internet")
            option: SettingsModel.option("metadata-network-access")
        }

        SettingRow {
            id: lastfm

            label: qsTr("Submit played tracks to last.fm")
            option: SettingsModel.option("extraInterface:audioscrobbler")
            info: qsTr("Sends the artist and title of the tracks you play to your last.fm account. Needs a restart.")
            keywords: qsTr("scrobbler audioscrobbler")
        }

        SettingRow {
            label: qsTr("Last.fm username")
            option: SettingsModel.option("lastfm-username")
            dependsOn: lastfm.option
        }

        SettingRow {
            label: qsTr("Last.fm password")
            option: SettingsModel.option("lastfm-password")
            dependsOn: lastfm.option
        }

        SettingRow {
            label: qsTr("Last.fm submission URL")
            option: SettingsModel.option("scrobbler-url")
            dependsOn: lastfm.option
        }
    }
}
