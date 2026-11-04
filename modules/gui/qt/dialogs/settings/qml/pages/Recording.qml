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


// Recording settings. Figma 6571:16429.
//
// Figma row                                  -> VLC option
//   Save recordings to                       -> input-record-path
//   Record without re-encoding when possible -> input-record-native
//   Discover cast devices                    -> (omitted: no option, discovery is the renderer service)
//   Cast quality                             -> sout-chromecast-conversion-quality (hidden without chromecast)
//   Play locally while streaming             -> sout-display
//   Include audio / video / subtitles        -> sout-audio / sout-video / sout-spu
//   Encoding preset / Tuning                 -> sout-x264-preset / sout-x264-tune (hidden without x264)
//   Advanced: Keep stream output open        -> sout-keep, sout-all

import QtQuick

import VLC.Dialogs
import VLC.Style

SettingsPage {
    SettingSection {
        title: qsTr("Recording")

        SettingRow {
            label: qsTr("Save recordings to")
            option: SettingsModel.option("input-record-path")
        }

        SettingRow {
            label: qsTr("Record without re-encoding when possible")
            info: ""
            option: SettingsModel.option("input-record-native")
        }
    }

    SettingSection {
        title: qsTr("Casting")

        SettingRow {
            label: qsTr("Cast quality")
            option: SettingsModel.option("sout-chromecast-conversion-quality")
        }
    }

    SettingSection {
        title: qsTr("Streaming")

        SettingRow {
            label: qsTr("Play locally while streaming")
            info: ""
            option: SettingsModel.option("sout-display")
        }

        SettingRow {
            label: qsTr("Include audio")
            info: ""
            option: SettingsModel.option("sout-audio")
        }

        SettingRow {
            label: qsTr("Include video")
            info: ""
            option: SettingsModel.option("sout-video")
        }

        SettingRow {
            label: qsTr("Include subtitles")
            info: ""
            option: SettingsModel.option("sout-spu")
        }

        SettingRow {
            label: qsTr("Encoding preset")
            option: SettingsModel.option("sout-x264-preset")
        }

        SettingRow {
            label: qsTr("Tuning")
            option: SettingsModel.option("sout-x264-tune")
        }
    }

    advanced: [
        SettingSection {
            title: qsTr("Stream Output")

            SettingRow {
                label: qsTr("Stream all elementary streams")
                option: SettingsModel.option("sout-all")
            }

            SettingRow {
                label: qsTr("Keep stream output open")
                option: SettingsModel.option("sout-keep")
            }
        }
    ]
}
