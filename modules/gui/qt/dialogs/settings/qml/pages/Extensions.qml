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


// Extensions settings. Figma 6575:17137.
//
// Figma row                                  -> VLC option
//   Add-ons list, Search, Remove             -> (no QML add-ons model yet: the list shows an empty state and
//                                               Remove stays disabled, see the report)
//   Find more extensions                     -> opens the add-ons website
//   Add                                      -> (disabled: needs the add-ons manager)
//   Load add-ons on startup                  -> qt-autoload-extensions (needs the lua module)
//   Advanced                                 -> lua-intf, lua-config (lua module only)

import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets

SettingsPage {
    id: page

    readonly property bool luaAvailable: SettingsModel.option("qt-autoload-extensions").available

    SettingSection {
        title: qsTr("Add-ons")

        // list well, 784 x 192 in the Figma frame
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(192, VLCStyle.scale)
            Layout.topMargin: VLCStyle.spacing_6

            radius: VLCStyle.radius_m
            color: wellTheme.bg.secondary
            border.width: VLCStyle.dp(2, VLCStyle.scale)
            border.color: wellTheme.border

            readonly property ColorContext colorContext: ColorContext {
                id: wellTheme
                colorSet: ColorContext.TextField
            }

            Text {
                anchors.centerIn: parent
                visible: !page.luaAvailable
                text: qsTr("Extensions are not available in this build of VLC.")
                color: wellTheme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.spacing_6
            spacing: VLCStyle.spacing_10

            Widgets.TextFieldExt {
                Layout.preferredWidth: VLCStyle.dp(210, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.input_h
                placeholderText: qsTr("Search")
                enabled: page.luaAvailable
                Accessible.name: placeholderText
            }

            Item { Layout.fillWidth: true }

            Widgets.DialogButton {
                text: qsTr("Find more extensions")
                onClicked: Qt.openUrlExternally("https://addons.videolan.org/")
            }

            Widgets.DialogButton {
                text: qsTr("Add")
                implicitWidth: VLCStyle.dp(100, VLCStyle.scale)
                enabled: false
            }

            Widgets.DialogButton {
                text: qsTr("Remove")
                implicitWidth: VLCStyle.dp(100, VLCStyle.scale)
                enabled: false
            }
        }

        SettingRow {
            label: qsTr("Load add-ons on startup")
            option: SettingsModel.option("qt-autoload-extensions")
        }
    }

    advanced: [
        SettingSection {
            SettingRow {
                label: qsTr("Lua interface script")
                option: SettingsModel.option("lua-intf")
            }

            SettingRow {
                label: qsTr("Lua interface configuration")
                option: SettingsModel.option("lua-config")
            }
        }
    ]
}
