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


// Interface settings. Figma 3046:10057 and 3062:11379 (advanced shown).
//
// Figma row                                  -> VLC option
//   Use a custom skin                        -> (omitted: no option; the skin file below is `skins2-last`)
//   Skin file                                -> skins2-last (hidden unless skins2 is built)
//   Play video inside main window            -> embedded-video
//   Resize window to fit video               -> qt-video-autoresize (Never = off, Always = on)
//   Remember window size and position        -> (omitted: QSettings only, no option)
//   Keep window above other windows          -> video-on-top
//   Show window decorations                  -> qt-titlebar
//   Show the file name in the title bar      -> qt-name-in-title
//   Open fullscreen on                       -> qt-fullscreen-screennumber (Current screen + one entry per screen)
//   Start in compact mode                    -> qt-minimal-view
//   Auto-hide the controls                   -> (omitted: only mouse-hide-timeout and qt-fs-controller exist)
//   Hide after                               -> mouse-hide-timeout (ms, shown in seconds)
//   Show controls in fullscreen              -> qt-fs-controller
//   Show a system tray icon                  -> qt-system-tray
//   Start minimized to the tray              -> qt-start-minimized
//   Show a popup when the track changes      -> qt-notification
//   Popup duration                           -> (omitted: no option)
//   Show the playlist as a tree              -> (omitted: no option; section left out)
//   Window opacity                           -> qt-opacity
//   Pause video when window is minimized     -> qt-pause-minimized
//   Bring VLC to the front when playback starts -> qt-auto-raise
//   Show cover art in the window when playing audio -> (omitted: no option)
//   Show the file browser inside the open dialog -> qt-embedded-open
//   Allow the app icon to change             -> qt-icon-change
//   Fullscreen controls opacity              -> qt-fs-opacity
//   Fullscreen controls sensitivity          -> qt-fs-sensitivity (Low = 3, Medium = 50, High = 200 px)

import QtQuick

import VLC.Dialogs
import VLC.Style

SettingsPage {
    SettingSection {
        title: qsTr("Skin")

        SettingRow {
            label: qsTr("Skin file")
            option: SettingsModel.option("skins2-last")
            kind: "file"
        }
    }

    SettingSection {
        title: qsTr("Window")

        SettingRow {
            label: qsTr("Play video inside main window")
            option: SettingsModel.option("embedded-video")
        }

        SettingRow {
            label: qsTr("Resize window to fit video")
            option: SettingsModel.option("qt-video-autoresize")
            kind: "dropdown"
            choices: [
                { value: false, text: qsTr("Never") },
                { value: true, text: qsTr("Always") }
            ]
        }

        SettingRow {
            label: qsTr("Keep window above other windows")
            option: SettingsModel.option("video-on-top")
        }

        SettingRow {
            label: qsTr("Show window decorations")
            option: SettingsModel.option("qt-titlebar")
        }

        SettingRow {
            label: qsTr("Show the file name in the title bar")
            option: SettingsModel.option("qt-name-in-title")
        }

        SettingRow {
            label: qsTr("Open fullscreen on")
            option: SettingsModel.option("qt-fullscreen-screennumber")
            kind: "dropdown"
            choices: {
                const list = [{ value: -1, text: qsTr("Current screen") }]
                const screens = Qt.application.screens
                for (let i = 0; i < screens.length; ++i)
                    list.push({ value: i, text: qsTr("Screen %1 (%2)").arg(i + 1).arg(screens[i].name) })
                return list
            }
        }
    }

    SettingSection {
        title: qsTr("Playback Controls")

        SettingRow {
            label: qsTr("Start in compact mode")
            option: SettingsModel.option("qt-minimal-view")
        }

        SettingRow {
            label: qsTr("Hide after")
            info: ""
            option: SettingsModel.option("mouse-hide-timeout")
            kind: "slider"
            valueScale: 0.001
            from: 0
            to: 10
            stepSize: 0.5
            ticks: true
            suffix: " s"
        }

        SettingRow {
            label: qsTr("Show controls in fullscreen")
            option: SettingsModel.option("qt-fs-controller")
        }

        SettingRow {
            label: qsTr("Show waveform in the music seek bar")
            option: SettingsModel.option("qt-music-waveform")
        }
    }

    SettingSection {
        title: qsTr("Notifications and System Tray")

        SettingRow {
            id: tray

            label: qsTr("Show a system tray icon")
            option: SettingsModel.option("qt-system-tray")
        }

        SettingRow {
            label: qsTr("Start minimized to the tray")
            option: SettingsModel.option("qt-start-minimized")
            dependsOn: tray.option
        }

        SettingRow {
            label: qsTr("Show a popup when the track changes")
            option: SettingsModel.option("qt-notification")
        }
    }

    advanced: [
        SettingSection {
            SettingRow {
                label: qsTr("Window opacity")
                info: ""
                option: SettingsModel.option("qt-opacity")
                kind: "slider"
                valueScale: 100
                from: 10
                to: 100
                stepSize: 10
                ticks: true
                suffix: "%"
            }

            SettingRow {
                label: qsTr("Pause video when window is minimized")
                info: ""
                option: SettingsModel.option("qt-pause-minimized")
            }

            SettingRow {
                label: qsTr("Bring VLC to the front when playback starts")
                option: SettingsModel.option("qt-auto-raise")
            }

            SettingRow {
                label: qsTr("Show the file browser inside the open dialog")
                info: ""
                option: SettingsModel.option("qt-embedded-open")
            }

            SettingRow {
                label: qsTr("Allow the app icon to change")
                info: ""
                option: SettingsModel.option("qt-icon-change")
            }

            SettingRow {
                label: qsTr("Fullscreen controls opacity")
                info: ""
                option: SettingsModel.option("qt-fs-opacity")
                kind: "slider"
                valueScale: 100
                from: 10
                to: 100
                stepSize: 10
                ticks: true
                suffix: "%"
            }

            SettingRow {
                label: qsTr("Fullscreen controls sensitivity")
                info: ""
                option: SettingsModel.option("qt-fs-sensitivity")
                kind: "slider"
                // pixels from the screen edge that reveal the controls
                choices: [
                    { value: 3, text: qsTr("Low") },
                    { value: 50, text: qsTr("Medium") },
                    { value: 200, text: qsTr("High") }
                ]
            }
        }
    ]
}
