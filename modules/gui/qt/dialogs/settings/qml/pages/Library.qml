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
//   Media library folders (first section)    -> mlFolders (virtual; hidden without a media library)

import QtQuick
import QtQuick.Layouts

import VLC.Dialogs
import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

SettingsPage {
    SettingSection {
        id: foldersSection

        title: qsTr("Media Library Folders")

        // full-width block: caption, list card, add button
        ColumnLayout {
            id: folders

            readonly property var option: SettingsModel.option("mlFolders")
            readonly property var foldersModel: option ? option.model : null
            // duck-types a SettingRow for SettingSection (it must know the block is shown
            // before the section itself is visible)
            readonly property bool isSettingRow: true
            readonly property bool shown: !!foldersModel

            // a block, not a SettingRow: takes part in the section visibility
            visible: shown

            Layout.fillWidth: true
            spacing: VLCStyle.spacing_10

            onShownChanged: foldersSection.update()
            Component.onCompleted: foldersSection.update()

            readonly property ColorContext colorContext: ColorContext {
                id: foldersTheme
                colorSet: ColorContext.Pane
            }

            readonly property real rowHeight: VLCStyle.dp(56, VLCStyle.scale)

            // name of a folder from its url
            function folderName(url) {
                const parts = String(url).replace(/\/+$/, "").split("/")
                return decodeURIComponent(parts[parts.length - 1] || String(url))
            }

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: VLCStyle.spacing_4

                text: qsTr("VLC watches these folders and adds new videos and music automatically.")
                wrapMode: Text.Wrap
                color: foldersTheme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }

            // list card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: cardColumn.implicitHeight

                radius: VLCStyle.radius_l
                color: foldersTheme.bg.secondary
                border.width: VLCStyle.border
                border.color: foldersTheme.separator

                ColumnLayout {
                    id: cardColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    // empty state
                    Item {
                        visible: foldersRepeater.count === 0

                        Layout.fillWidth: true
                        Layout.preferredHeight: folders.rowHeight * 1.5

                        Column {
                            anchors.centerIn: parent
                            spacing: VLCStyle.spacing_4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("No folders yet")
                                color: foldersTheme.fg.primary
                                font.pixelSize: VLCStyle.text_body
                                font.weight: VLCStyle.fontWeight_medium
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Add a folder to fill your library.")
                                color: foldersTheme.fg.secondary
                                font.pixelSize: VLCStyle.text_caption
                            }
                        }
                    }

                    Repeater {
                        id: foldersRepeater

                        model: folders.foldersModel

                        delegate: FocusScope {
                            id: folderRow

                            required property int index
                            required property string display_url
                            required property string url

                            readonly property bool active: rowHover.hovered || activeFocus
                            readonly property bool scanning: !!MainCtx.mediaLibrary
                                                              && MainCtx.mediaLibrary.discoveryPending
                                                              && String(MainCtx.mediaLibrary.discoveryEntryPoint).indexOf(display_url) !== -1

                            Layout.fillWidth: true
                            Layout.preferredHeight: folders.rowHeight

                            HoverHandler { id: rowHover }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: VLCStyle.border
                                radius: VLCStyle.radius_l
                                color: foldersTheme.bg.primary
                                opacity: folderRow.active ? 1 : 0

                                Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: VLCStyle.spacing_14
                                anchors.rightMargin: VLCStyle.spacing_10
                                spacing: VLCStyle.spacing_12

                                Widgets.SvgIcon {
                                    name: "folder"
                                    size: VLCStyle.icon_normal
                                    color: foldersTheme.fg.secondary
                                    accentColor: foldersTheme.accent
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: folders.folderName(folderRow.url)
                                        elide: Text.ElideRight
                                        color: foldersTheme.fg.primary
                                        font.pixelSize: VLCStyle.text_body
                                        font.weight: VLCStyle.fontWeight_medium
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: folderRow.display_url
                                        elide: Text.ElideMiddle
                                        color: foldersTheme.fg.secondary
                                        font.pixelSize: VLCStyle.text_caption
                                    }
                                }

                                Text {
                                    visible: folderRow.scanning
                                    text: qsTr("Scanning...")
                                    color: foldersTheme.fg.secondary
                                    font.pixelSize: VLCStyle.text_caption
                                }

                                // revealed on hover and focus, always reachable by keyboard
                                Widgets.DialogButton {
                                    id: rescanButton

                                    text: qsTr("Rescan")
                                    opacity: folderRow.active ? 1 : 0
                                    focus: true
                                    onClicked: folders.foldersModel.reload(folderRow.index)

                                    Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                                }

                                Widgets.DialogButton {
                                    id: removeButton

                                    text: qsTr("Remove")
                                    opacity: folderRow.active ? 1 : 0
                                    onClicked: folders.foldersModel.removeAt(folderRow.index)

                                    Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                                }
                            }

                            // divider
                            Rectangle {
                                visible: folderRow.index < foldersRepeater.count - 1
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: VLCStyle.spacing_14
                                height: VLCStyle.border
                                color: foldersTheme.separator
                            }
                        }
                    }
                }
            }

            RowLayout {
                spacing: VLCStyle.spacing_12

                Widgets.DialogButton {
                    text: qsTr("Add folder...")
                    onClicked: {
                        const path = SettingsModel.pickDirectory("")
                        if (path !== "")
                            folders.foldersModel.add("file://" + encodeURI(path))
                    }
                }

                Text {
                    visible: !!MainCtx.mediaLibrary && (!MainCtx.mediaLibrary.idle || MainCtx.mediaLibrary.discoveryPending)
                    text: MainCtx.mediaLibrary && MainCtx.mediaLibrary.discoveryPending
                          ? qsTr("Scanning %1...").arg(MainCtx.mediaLibrary.discoveryEntryPoint)
                          : qsTr("Indexing media: %1%").arg(MainCtx.mediaLibrary ? MainCtx.mediaLibrary.parsingProgress : 0)
                    elide: Text.ElideMiddle
                    color: foldersTheme.fg.secondary
                    font.pixelSize: VLCStyle.text_caption
                    Layout.fillWidth: true
                }
            }
        }
    }

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
}
