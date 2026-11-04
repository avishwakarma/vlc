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
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Dialogs

// Shared empty state of the redesign: duotone illustration on a soft disc,
// a title, a caption and an optional primary action.
//
//   illustration: library, video, music, playlist, network, search, queue
//   action:       "addFolder" (media library folder picker, falls back to
//                 "Open File" without a media library), "openFile", or ""
//                 (custom: set actionText and handle onActionTriggered)
FocusScope {
    id: root

    property string illustration: "library"
    property string title
    property string caption
    property string action
    property string actionText

    // smaller layout for narrow hosts such as the sidebar
    property bool compact: false

    // overridable: a model whose active search/filter turns this into a
    // "No results" state
    property var searchModel: null
    readonly property bool _searching: searchModel && searchModel.searchPattern
                                       && searchModel.searchPattern.length > 0

    readonly property bool _canAddFolder: MainCtx.mediaLibraryAvailable

    signal actionTriggered()

    readonly property string _actionText: {
        if (_searching)
            return ""
        if (action === "addFolder")
            return _canAddFolder ? qsTr("Add media folder") : qsTr("Open File")
        if (action === "openFile")
            return qsTr("Open File")
        return actionText
    }

    readonly property real _artSize: compact ? VLCStyle.dp(96, VLCStyle.scale)
                                             : VLCStyle.dp(160, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Empty view")
    Accessible.description: title

    implicitWidth: root.compact ? root._artSize : VLCStyle.dp(420, VLCStyle.scale)
    implicitHeight: column.implicitHeight

    function activate() {
        if (action === "addFolder" && _canAddFolder) {
            const path = SettingsModel.pickDirectory("")
            if (!path)
                return
            const folders = SettingsModel.option("mlFolders")
            if (folders && folders.model)
                folders.model.add("file://" + encodeURI(path))
        } else if (action === "addFolder" || action === "openFile") {
            DialogsProvider.simpleOpenDialog()
        } else {
            actionTriggered()
        }
    }

    Column {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.compact ? root.width : VLCStyle.dp(420, VLCStyle.scale)
        spacing: root.compact ? VLCStyle.margin_xsmall : VLCStyle.margin_small

        Item {
            id: art

            anchors.horizontalCenter: parent.horizontalCenter
            width: root._artSize
            height: root._artSize

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: theme.bg.secondary
            }

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(width * Screen.devicePixelRatio,
                                    height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true

                source: SVGColorImage.colorize("qrc:///emptystates/"
                                               + (root._searching ? "search" : root.illustration)
                                               + ".svg")
                                     .color1(theme.fg.primary)
                                     .accent(theme.accent)
                                     .color2(Qt.darker(theme.accent, 1.3))
                                     .uri()
            }
        }

        Item { width: 1; height: root.compact ? 0 : VLCStyle.margin_xsmall }

        Widgets.SubtitleLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root._searching ? qsTr("No results") : root.title
            color: theme.fg.primary
        }

        Widgets.CaptionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: text !== ""
            text: root._searching ? qsTr("Nothing matches \"%1\". Try a different search.")
                                      .arg(root.searchModel.searchPattern)
                                  : root.caption
            color: theme.fg.secondary
        }

        Item {
            width: 1
            height: VLCStyle.margin_normal
            visible: actionButton.visible
        }

        Widgets.ActionButtonPrimary {
            id: actionButton

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root._actionText !== ""
            focus: visible
            text: root._actionText

            Navigation.parentItem: root

            onClicked: root.activate()
        }
    }
}
