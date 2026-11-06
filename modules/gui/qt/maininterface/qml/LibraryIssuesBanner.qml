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

// Tells the user about media library folders that cannot be scanned (deleted, moved,
// unreadable, or whose scan failed) and lets them retry, remove the folder from the
// library, or dismiss the notice. Data: MediaLib.libraryIssues.

import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Widgets as Widgets
import VLC.Style

Rectangle {
    id: root

    readonly property var issues: (MainCtx.mediaLibraryAvailable ? MediaLib.libraryIssues : null) ?? []

    visible: issues.length > 0
    implicitHeight: column.implicitHeight + 2 * VLCStyle.margin_normal

    radius: VLCStyle.radius_l
    color: theme.bg.secondary
    border.color: theme.border
    border.width: VLCStyle.border

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    function reasonText(reason) {
        switch (reason) {
        case "missing":
            return qsTr("This folder was deleted or moved. Its media can no longer be found.")
        case "unreadable":
            return qsTr("This folder can't be read. Check its permissions.")
        case "unavailable":
            return qsTr("This folder isn't available. Connect the drive or network share it is on.")
        case "error":
            return qsTr("The media library ran into an error and stopped scanning. Restart the player to resume.")
        default:
            return qsTr("This folder couldn't be scanned. If it is on a drive or network share, check that it is connected.")
        }
    }

    // swallow clicks so they don't reach the view underneath
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: VLCStyle.margin_normal
        spacing: VLCStyle.margin_normal

        RowLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.margin_small

            Widgets.SvgIcon {
                name: "info-twotone"
                size: VLCStyle.icon_normal
                color: theme.fg.primary
            }

            Widgets.SubtitleLabel {
                Layout.fillWidth: true
                text: root.issues.length === 1
                      ? qsTr("A folder in your library needs attention")
                      : qsTr("%1 folders in your library need attention").arg(root.issues.length)
                color: theme.fg.primary
                elide: Text.ElideRight
            }
        }

        Repeater {
            model: root.issues

            delegate: RowLayout {
                id: issueRow

                required property var modelData

                Layout.fillWidth: true
                spacing: VLCStyle.margin_normal

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: VLCStyle.margin_xxxsmall

                    Widgets.ListLabel {
                        Layout.fillWidth: true
                        text: issueRow.modelData.path
                        color: theme.fg.primary
                        elide: Text.ElideMiddle
                    }

                    Widgets.CaptionLabel {
                        Layout.fillWidth: true
                        text: root.reasonText(issueRow.modelData.reason)
                        color: theme.fg.secondary
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }

                    Widgets.CaptionLabel {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: issueRow.modelData.details ?? ""
                        color: theme.fg.secondary
                        font.family: "Menlo"
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                Widgets.DialogButton {
                    text: qsTr("Dismiss")
                    onClicked: MediaLib.dismissLibraryIssue(issueRow.modelData.key)
                }

                Widgets.DialogButton {
                    visible: issueRow.modelData.mrl !== ""
                    text: qsTr("Remove from Library")
                    onClicked: MediaLib.removeLibraryFolder(issueRow.modelData.mrl)
                }

                Widgets.DialogButton {
                    visible: issueRow.modelData.reason !== "error"
                    kind: Widgets.DialogButton.Primary
                    text: qsTr("Retry")
                    onClicked: MediaLib.retryLibraryFolder(issueRow.modelData.mrl)
                }
            }
        }
    }
}
