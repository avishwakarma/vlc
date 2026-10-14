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


// Mouse, keyboard and remote controls. Figma 6536:14482.
//
// Figma row                                  -> VLC option
//   Defaults / Edit Keyboard Shortcuts       -> opens the in-window HotkeysEditor (HotkeysModel)
//   Reset all shortcuts                      -> SettingsModel.hotkeys.resetAll() (after confirmation)
//   Very short / Short / Medium / Long skip  -> extrashort-jump-size / short-jump-size / medium-jump-size / long-jump-size
//   Single click on the video                -> (omitted: no option)
//   Double click on the video                -> (omitted: no option)
//   Scroll wheel                             -> hotkeys-y-wheel-mode
//   Horizontal scroll                        -> hotkeys-x-wheel-mode
//   Reverse scroll direction                 -> (omitted: "Position control reversed" is a choice of the wheel rows)
//   Web remote control / Port                -> extraInterface:http / http-port (needs the lua module)

import QtQuick

import VLC.Dialogs
import VLC.Style

SettingsPage {
    id: page

    function openEditor() {
        hotkeys.open()
    }

    SettingSection {
        title: qsTr("Keyboard Shortcuts")

        SettingRow {
            label: qsTr("Defaults")
            info: ""
            needsOption: false
            kind: "button"
            buttonText: qsTr("Edit Keyboard Shortcuts")
            buttonWidth: VLCStyle.dp(320, VLCStyle.scale)
            keywords: qsTr("hotkeys keys bindings")
            onActivated: hotkeys.open()
        }

        SettingRow {
            label: qsTr("Reset all shortcuts")
            info: ""
            needsOption: false
            kind: "button"
            buttonText: qsTr("Reset")
            buttonWidth: VLCStyle.dp(320, VLCStyle.scale)
            confirmText: qsTr("All keyboard shortcuts return to their defaults. VLC needs a restart to apply them.")
            confirmAction: qsTr("Reset")
            onActivated: SettingsModel.hotkeys.resetAll()
        }
    }

    SettingSection {
        title: qsTr("Skip Amounts")

        SettingRow {
            label: qsTr("Very short skip")
            info: ""
            option: SettingsModel.option("extrashort-jump-size")
            kind: "number"
            suffix: "s"
        }

        SettingRow {
            label: qsTr("Short skip")
            info: ""
            option: SettingsModel.option("short-jump-size")
            kind: "number"
            suffix: "s"
        }

        SettingRow {
            label: qsTr("Medium skip")
            info: ""
            option: SettingsModel.option("medium-jump-size")
            kind: "number"
            suffix: "s"
        }

        SettingRow {
            label: qsTr("Long skip")
            info: ""
            option: SettingsModel.option("long-jump-size")
            kind: "number"
            suffix: "s"
        }
    }

    SettingSection {
        title: qsTr("Mouse")

        SettingRow {
            label: qsTr("Scroll wheel")
            info: ""
            option: SettingsModel.option("hotkeys-y-wheel-mode")
        }

        SettingRow {
            label: qsTr("Horizontal scroll")
            info: ""
            option: SettingsModel.option("hotkeys-x-wheel-mode")
        }
    }

    SettingSection {
        title: qsTr("Remotes")

        SettingRow {
            id: web

            label: qsTr("Web remote control")
            info: ""
            option: SettingsModel.option("extraInterface:http")
        }

        SettingRow {
            label: qsTr("Port")
            info: ""
            option: SettingsModel.option("http-port")
            kind: "number"
            dependsOn: web.option
        }
    }

    HotkeysEditor {
        id: hotkeys
    }
}
