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


// Library settings. Figma 6542:15251.
//
// Figma row                                  -> VLC option
//   Only allow one VLC window                -> one-instance
//   Apply to files opened from the file manager -> one-instance-when-started-from-file
//   Add to the playlist instead of replacing it -> playlist-enqueue
//   When opening a folder                    -> recursive (None / Collapse / Include subfolders)
//   Show hidden files                        -> show-hiddenfiles
//   Fetch titles and artwork                 -> metadata-network-access (From the file only / online too)
//   Use the media library                    -> media-library
//   Advanced: Media library folders          -> mlFolders (virtual; hidden without a media library)

import QtQuick
import QtQuick.Layouts

import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets

SettingsPage {
    SettingSection {
        title: qsTr("Opening Files")

        SettingRow {
            id: oneInstance

            label: qsTr("Only allow one VLC window")
            option: SettingsModel.option("one-instance")
        }

        SettingRow {
            label: qsTr("Apply to files opened from the file manager")
            option: SettingsModel.option("one-instance-when-started-from-file")
            dependsOn: oneInstance.option
        }

        SettingRow {
            label: qsTr("Add to the playlist instead of replacing it")
            option: SettingsModel.option("playlist-enqueue")
            dependsOn: oneInstance.option
        }

        SettingRow {
            label: qsTr("When opening a folder")
            option: SettingsModel.option("recursive")
            kind: "dropdown"
            choices: [
                { value: "none", text: qsTr("Don't include subfolders") },
                { value: "collapse", text: qsTr("Include subfolders when played") },
                { value: "expand", text: qsTr("Include subfolders") }
            ]
        }

        SettingRow {
            label: qsTr("Show hidden files")
            option: SettingsModel.option("show-hiddenfiles")
        }
    }

    SettingSection {
        title: qsTr("Metadata & Artwork")

        SettingRow {
            label: qsTr("Fetch titles and artwork")
            option: SettingsModel.option("metadata-network-access")
            kind: "dropdown"
            choices: [
                { value: false, text: qsTr("From the file only") },
                { value: true, text: qsTr("From the file and online") }
            ]
        }

        SettingRow {
            label: qsTr("Use the media library")
            option: SettingsModel.option("media-library")
        }
    }

    advanced: [
        SettingSection {
            title: qsTr("Media Library Folders")

            SettingRow {
                id: foldersRow

                label: qsTr("Folders to scan")
                option: SettingsModel.option("mlFolders")
                kind: "custom"
                customControl: Component {
                    ColumnLayout {
                        spacing: VLCStyle.spacing_6

                        Repeater {
                            model: foldersRow.option.model

                            delegate: RowLayout {
                                required property int index
                                required property string display

                                Layout.preferredWidth: foldersRow.controlWidth
                                spacing: VLCStyle.spacing_10

                                Text {
                                    Layout.fillWidth: true
                                    text: display
                                    elide: Text.ElideMiddle
                                    color: VLCStyle.colors.text
                                    font.pixelSize: VLCStyle.text_body
                                }

                                Widgets.DialogButton {
                                    text: qsTr("Remove")
                                    onClicked: foldersRow.option.model.removeAt(index)
                                }
                            }
                        }

                        Widgets.DialogButton {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Add folder")
                            onClicked: {
                                const path = SettingsModel.pickDirectory("")
                                if (path !== "")
                                    foldersRow.option.model.add("file://" + path)
                            }
                        }
                    }
                }
            }
        }
    ]
}
