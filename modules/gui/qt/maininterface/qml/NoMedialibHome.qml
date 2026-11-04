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
        implicitWidth: visible ? emptyState.implicitWidth : 0
        implicitHeight: visible ? emptyState.implicitHeight : 0

        Widgets.EmptyState {
            id: emptyState

            anchors.centerIn: parent
            focus: true

            illustration: "library"
            title: coneNButtons._canAddFolder ? qsTr("Your library is empty")
                                              : qsTr("Nothing to show yet")
            caption: coneNButtons._canAddFolder
                     ? qsTr("Add a folder with your videos and music to get started.")
                     : qsTr("Open a file to start playing.")
            action: "addFolder"

            Navigation.parentItem: coneNButtons
        }
    }


    ConeNButtons {
        focus: true

        anchors.centerIn: root

        Navigation.parentItem: root
    }
}
