/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQuick
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style
import VLC.Dialogs

FocusScope {
    id: root

    property var pagePrefix: [] // behave like a Page

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Home View")


    // Empty library state of the redesign. The horizontal orientation is
    // used above the media rows of a populated home page, where the design
    // shows nothing, so it collapses there.
    component ConeNButtons: FocusScope {
        id: coneNButtons

        property int orientation: Qt.Vertical

        readonly property bool _canAddFolder: MainCtx.mediaLibraryAvailable

        visible: orientation === Qt.Vertical
        implicitWidth: visible ? column.implicitWidth : 0
        implicitHeight: visible ? column.implicitHeight : 0

        readonly property ColorContext colorContext: ColorContext {
            id: emptyTheme
            colorSet: ColorContext.View
        }

        Column {
            id: column

            anchors.centerIn: parent
            spacing: VLCStyle.margin_small

            Widgets.SvgIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "folder"
                size: VLCStyle.icon_large
                color: emptyTheme.fg.secondary
            }

            Item { width: 1; height: VLCStyle.margin_xsmall }

            Widgets.SubtitleLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: coneNButtons._canAddFolder ? qsTr("Your library is empty")
                                                 : qsTr("Nothing to show yet")
                color: emptyTheme.fg.primary
            }

            Widgets.CaptionLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: coneNButtons._canAddFolder
                      ? qsTr("Add a folder with your videos and music to get started.")
                      : qsTr("Open a file to start playing.")
                color: emptyTheme.fg.secondary
            }

            Item { width: 1; height: VLCStyle.margin_normal }

            Widgets.ActionButtonPrimary {
                id: addButton

                anchors.horizontalCenter: parent.horizontalCenter
                focus: true

                AccessibleCompat.id: "addMediaFolderButton"

                text: coneNButtons._canAddFolder ? qsTr("Add media folder")
                                                 : qsTr("Open File")

                Navigation.parentItem: coneNButtons

                onClicked: {
                    if (!coneNButtons._canAddFolder) {
                        DialogsProvider.simpleOpenDialog()
                        return
                    }
                    const path = SettingsModel.pickDirectory("")
                    if (!path)
                        return
                    const folders = SettingsModel.option("mlFolders")
                    if (folders && folders.model)
                        folders.model.add("file://" + encodeURI(path))
                }
            }
        }
    }


    ConeNButtons {
        focus: true

        anchors.centerIn: root

        Navigation.parentItem: root
    }
}
