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


// Performance settings. Figma 6571:15958.
//
// Figma row                                  -> VLC option
//   Hardware-accelerated decoding            -> hw-dec (Disabled) + dec-dev (Automatic / device); avcodec-hw is obsolete
//   Video post-processing                    -> postproc-q (0 / 2 / 4 / 6 = Off / Low / Medium / High)
//   Skip the H.264 loop filter               -> avcodec-skiploopfilter
//   Decoding threads                         -> avcodec-threads
//   Drop frames when the system can't keep up -> drop-late-frames
//   Give VLC real-time priority              -> high-priority (hidden where the option does not exist)
//   Process priority                         -> rt-offset
//   Rescan plugins                           -> reset-plugins-cache (button, applied at next start)
//   Developer: Encoder                       -> (omitted: encoder option obsolete)
//   Decoder                                  -> codec
//   Clock synchronisation / jitter / averaging -> clock-synchro / clock-jitter / cr-average

import QtQuick

import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets

SettingsPage {
    SettingSection {
        title: qsTr("Decoding")

        SettingRow {
            id: hwRow

            readonly property ConfigOption hwOpt: SettingsModel.option("hw-dec")
            readonly property ConfigOption devOpt: SettingsModel.option("dec-dev")

            // Automatic / Disabled / the decoder devices of this build
            readonly property var devices: {
                const out = [{ value: "any", text: qsTr("Automatic") }, { value: "", text: qsTr("Disabled") }]
                for (const c of devOpt.choices) {
                    if (c.value !== "any" && c.value !== "none")
                        out.push(c)
                }
                return out
            }

            label: qsTr("Hardware-accelerated decoding")
            info: hwOpt.longText
            option: hwOpt
            kind: "custom"
            customControl: Component {
                Widgets.Dropdown {
                    implicitWidth: hwRow.controlWidth
                    compact: true
                    model: hwRow.devices
                    textRole: "text"
                    currentIndex: {
                        if (!hwRow.hwOpt.value)
                            return 1
                        for (let i = 0; i < hwRow.devices.length; ++i) {
                            if (hwRow.devices[i].value === hwRow.devOpt.value)
                                return i
                        }
                        return 0
                    }
                    onActivated: (index) => {
                        const v = hwRow.devices[index].value
                        hwRow.hwOpt.value = (v !== "")
                        if (v !== "")
                            hwRow.devOpt.value = v
                    }

                    Accessible.name: hwRow.label
                }
            }
        }

        SettingRow {
            label: qsTr("Video post-processing")
            option: SettingsModel.option("postproc-q")
            kind: "dropdown"
            choices: [
                { value: 0, text: qsTr("Off") },
                { value: 2, text: qsTr("Low") },
                { value: 4, text: qsTr("Medium") },
                { value: 6, text: qsTr("High") }
            ]
        }

        SettingRow {
            label: qsTr("Skip the H.264 loop filter")
            option: SettingsModel.option("avcodec-skiploopfilter")
        }

        SettingRow {
            label: qsTr("Decoding threads")
            option: SettingsModel.option("avcodec-threads")
            kind: "number"
        }
    }

    SettingSection {
        title: qsTr("Smooth Playback")

        SettingRow {
            label: qsTr("Drop frames when the system can't keep up")
            info: ""
            option: SettingsModel.option("drop-late-frames")
        }

        SettingRow {
            label: qsTr("Give VLC real-time priority")
            info: ""
            option: SettingsModel.option("high-priority")
        }

        SettingRow {
            label: qsTr("Process priority")
            option: SettingsModel.option("rt-offset")
            kind: "number"
        }

        SettingRow {
            label: qsTr("Rescan plugins")
            info: ""
            option: SettingsModel.option("reset-plugins-cache")
            kind: "button"
            buttonText: qsTr("Rescan")
            buttonWidth: VLCStyle.dp(320, VLCStyle.scale)
            onActivated: option.value = true
        }
    }

    advanced: [
        SettingSection {
            title: qsTr("Developer")

            SettingRow {
                label: qsTr("Decoder")
                option: SettingsModel.option("codec")
            }

            SettingRow {
                label: qsTr("Clock synchronisation")
                option: SettingsModel.option("clock-synchro")
            }

            SettingRow {
                label: qsTr("Clock jitter")
                option: SettingsModel.option("clock-jitter")
                kind: "number"
                suffix: "ms"
            }

            SettingRow {
                label: qsTr("Clock reference averaging")
                option: SettingsModel.option("cr-average")
                kind: "number"
            }
        }
    ]
}
