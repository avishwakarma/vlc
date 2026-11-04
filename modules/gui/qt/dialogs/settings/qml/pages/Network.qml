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


// Network settings. Figma 6543:15649.
//
// Figma row                                  -> VLC option
//   Buffering (preset)                       -> file-caching / disc-caching / network-caching / live-caching
//                                               (Low / Normal / High write all four, Custom unlocks them)
//   Local files / Discs / Network streams / Live capture
//                                            -> file-caching / disc-caching / network-caching / live-caching
//   HTTP proxy / HTTP proxy password         -> http-proxy / http-proxy-pwd (obsolete in 4.0: hidden when unavailable)
//   Verify certificates against the system trust store -> gnutls-system-trust
//   Cipher preference                        -> gnutls-priorities (Balanced / Performance / Secure)
//   System proxy                             -> (omitted: no option)
//   Advanced                                 -> ipv4-timeout, http-user-agent, http-reconnect

import QtQuick

import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets

SettingsPage {
    id: page

    readonly property var cacheNames: ["file-caching", "disc-caching", "network-caching", "live-caching"]
    // [file, disc, network, live] in ms
    readonly property var presets: [
        { text: qsTr("Low"), values: [300, 150, 300, 150] },
        // Normal = VLC's own defaults
        { text: qsTr("Normal"), values: cacheNames.map((n) => SettingsModel.option(n).defaultValue) },
        { text: qsTr("High"), values: [2000, 600, 3000, 600] }
    ]
    // "Custom" is kept while the user is editing the fields
    property bool customMode: false

    readonly property int presetIndex: {
        if (customMode)
            return presets.length
        for (let p = 0; p < presets.length; ++p) {
            let same = true
            for (let i = 0; i < cacheNames.length; ++i)
                same = same && SettingsModel.option(cacheNames[i]).value == presets[p].values[i]
            if (same)
                return p
        }
        return presets.length
    }

    readonly property bool custom: presetIndex === presets.length

    SettingSection {
        title: qsTr("Buffering")

        SettingRow {
            id: bufferingRow

            label: qsTr("Buffering")
            info: SettingsModel.option("network-caching").longText
            needsOption: false
            kind: "custom"
            customControl: Component {
                Widgets.Dropdown {
                    implicitWidth: bufferingRow.controlWidth
                    compact: true
                    model: [page.presets[0].text, page.presets[1].text, page.presets[2].text, qsTr("Custom")]
                    currentIndex: page.presetIndex
                    onActivated: (index) => {
                        if (index < page.presets.length) {
                            page.customMode = false
                            for (let i = 0; i < page.cacheNames.length; ++i)
                                SettingsModel.option(page.cacheNames[i]).value = page.presets[index].values[i]
                        } else {
                            page.customMode = true
                        }
                    }

                    Accessible.name: bufferingRow.label
                }
            }
        }

        SettingRow {
            label: qsTr("Local files")
            info: ""
            option: SettingsModel.option("file-caching")
            kind: "number"
            suffix: "ms"
            enabled: page.custom
            opacity: page.custom ? 1.0 : 0.3
        }

        SettingRow {
            label: qsTr("Discs")
            info: ""
            option: SettingsModel.option("disc-caching")
            kind: "number"
            suffix: "ms"
            enabled: page.custom
            opacity: page.custom ? 1.0 : 0.3
        }

        SettingRow {
            label: qsTr("Network streams")
            info: ""
            option: SettingsModel.option("network-caching")
            kind: "number"
            suffix: "ms"
            enabled: page.custom
            opacity: page.custom ? 1.0 : 0.3
        }

        SettingRow {
            label: qsTr("Live capture")
            info: ""
            option: SettingsModel.option("live-caching")
            kind: "number"
            suffix: "ms"
            enabled: page.custom
            opacity: page.custom ? 1.0 : 0.3
        }
    }

    SettingSection {
        title: qsTr("Proxy")

        SettingRow {
            label: qsTr("HTTP proxy")
            option: SettingsModel.option("http-proxy")
        }

        SettingRow {
            label: qsTr("HTTP proxy password")
            option: SettingsModel.option("http-proxy-pwd")
            kind: "password"
        }
    }

    SettingSection {
        title: qsTr("Security")

        SettingRow {
            label: qsTr("Verify certificates against the system trust store")
            option: SettingsModel.option("gnutls-system-trust")
        }

        SettingRow {
            label: qsTr("Cipher preference")
            option: SettingsModel.option("gnutls-priorities")
            kind: "dropdown"
            choices: [
                { value: "NORMAL", text: qsTr("Balanced") },
                { value: "PERFORMANCE", text: qsTr("Performance") },
                { value: "SECURE128", text: qsTr("Secure (128-bit)") },
                { value: "SECURE256", text: qsTr("Secure (256-bit)") }
            ]
        }
    }

    advanced: [
        SettingSection {
            title: qsTr("Connection")

            SettingRow {
                label: qsTr("Connection timeout")
                option: SettingsModel.option("ipv4-timeout")
                suffix: "ms"
            }

            SettingRow {
                label: qsTr("User agent")
                option: SettingsModel.option("http-user-agent")
            }

            SettingRow {
                label: qsTr("Reconnect when the connection drops")
                option: SettingsModel.option("http-reconnect")
            }
        }
    ]
}
