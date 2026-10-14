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


// General settings. Figma 999:5047 (collapsed) and 3046:9282 (advanced shown).
//
// Figma row                                  -> VLC option
//   Interface language                       -> (omitted: VLC has no language option, `language` is unavailable)
//   Theme (Dark / Light / System)            -> theme (virtual, MainCtx.colorScheme; System = Auto)
//   Accent color                             -> accent (virtual, MainCtx.accentColor)
//   Show confirmation and error dialogs      -> qt-error-dialogs
//   Check for updates automatically          -> qt-updates-notif (only on builds with update checking)
//   Developer mode                           -> (omitted: no option)
//   Save a log / Log file / Log details      -> file-logging / logfile / log-verbose
//   Show minor warnings                      -> verbose (ON = 1, OFF = 0)
//   Additional command line options          -> (omitted: no option)
//   Log format                               -> logmode
//   Collect playback statistics              -> stats
//   Open configurations folder               -> SettingsModel.openConfigFolder()
//   Reset all settings                       -> SettingsModel.resetAll() (after confirmation)
//   Write to the system log and the rest     -> syslog, syslog-debug, syslog-ident, syslog-facility

import QtQuick

import VLC.Dialogs
import VLC.Style

SettingsPage {
    SettingSection {
        title: qsTr("Appearance")

        SettingRow {
            label: qsTr("Theme")
            info: ""
            option: SettingsModel.option("theme")
            kind: "segmented"
            // Figma order: Dark, Light, System
            choices: [
                { value: ColorSchemeModel.Night, text: qsTr("Dark") },
                { value: ColorSchemeModel.Day, text: qsTr("Light") },
                { value: ColorSchemeModel.Auto, text: qsTr("System") }
            ]
        }

        SettingRow {
            label: qsTr("Accent color")
            info: ""
            option: SettingsModel.option("accent")
            keywords: qsTr("color colour")
        }
    }

    SettingSection {
        title: qsTr("Startup")

        SettingRow {
            label: qsTr("Show confirmation and error dialogs")
            option: SettingsModel.option("qt-error-dialogs")
        }

        SettingRow {
            label: qsTr("Check for updates automatically")
            option: SettingsModel.option("qt-updates-notif")
        }
    }

    SettingSection {
        title: qsTr("Diagnostics")

        SettingRow {
            id: saveLog

            label: qsTr("Save a log")
            option: SettingsModel.option("file-logging")
        }

        SettingRow {
            label: qsTr("Log file")
            option: SettingsModel.option("logfile")
            dependsOn: saveLog.option
        }

        SettingRow {
            label: qsTr("Log details")
            option: SettingsModel.option("log-verbose")
            dependsOn: saveLog.option
        }
    }

    advanced: [
        SettingSection {
            SettingRow {
                label: qsTr("Show minor warnings")
                option: SettingsModel.option("verbose")
                kind: "toggle"
                valueOn: 1
                valueOff: 0
            }

            SettingRow {
                label: qsTr("Log format")
                option: SettingsModel.option("logmode")
                dependsOn: saveLog.option
            }

            SettingRow {
                label: qsTr("Collect playback statistics")
                option: SettingsModel.option("stats")
            }

            SettingRow {
                label: qsTr("Open configurations folder")
                info: SettingsModel.configFolder
                needsOption: false
                kind: "button"
                buttonText: qsTr("Open")
                keywords: qsTr("config folder directory vlcrc")
                onActivated: SettingsModel.openConfigFolder()
            }

            SettingRow {
                label: qsTr("Reset all settings")
                info: qsTr("Resets every VLC option and interface setting to its default value.")
                needsOption: false
                kind: "button"
                buttonText: qsTr("Reset")
                confirmText: qsTr("Every setting returns to its default value. VLC needs a restart to apply all of them.")
                confirmAction: qsTr("Reset")
                keywords: qsTr("defaults preferences")
                onActivated: SettingsModel.resetAll()
            }
        },

        SettingSection {
            title: qsTr("Developer Options")

            SettingRow {
                id: syslog

                label: qsTr("Write to the system log")
                option: SettingsModel.option("syslog")
            }

            SettingRow {
                label: qsTr("Include debug messages in the system log")
                option: SettingsModel.option("syslog-debug")
                dependsOn: syslog.option
            }

            SettingRow {
                label: qsTr("System log identity")
                option: SettingsModel.option("syslog-ident")
                dependsOn: syslog.option
            }

            SettingRow {
                label: qsTr("System log facility")
                option: SettingsModel.option("syslog-facility")
                dependsOn: syslog.option
            }
        }
    ]
}
