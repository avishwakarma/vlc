/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// Fields of the Open Network Stream form (Figma 6216:13614): one location per line and an optional
// name. Used by OpenNetworkStream.qml and by the Network tab of OpenAdvanced.qml.
Column {
    id: root

    property alias text: urlField.text
    property alias name: nameField.text
    readonly property int count: forms.countLocations(urlField.text)
    readonly property Item initialFocusItem: urlField.textArea

    // Enter in a field (Shift+Enter adds a line in the location box)
    signal submitRequested()

    function reset(text) {
        urlField.text = text
        urlField.textArea.selectAll()
        nameField.text = ""
    }

    spacing: VLCStyle.spacing_20

    DialogForms {
        id: forms
        ctx: MainCtx
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    DialogHeading {
        width: parent.width
        label: qsTr("Network URL")
        helper: qsTr("You can enter multiple links to load.")
    }

    DialogTextArea {
        id: urlField

        width: parent.width
        placeholderText: qsTr("e.g., https://www.example.com/stream.avi")

        textArea.Keys.onPressed: (event) => {
            // Enter plays, Shift+Enter inserts a new line for the next location
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    && !(event.modifiers & Qt.ShiftModifier)) {
                root.submitRequested()
                event.accepted = true
            }
        }
        textArea.Keys.priority: Keys.BeforeItem
    }

    Rectangle {
        width: parent.width
        height: VLCStyle.dp(1, VLCStyle.scale)
        color: theme.separator
    }

    DialogHeading {
        width: parent.width
        label: qsTr("Playlist Name")
        labelSuffix: qsTr("(optional)")
        helper: qsTr("The playlist will be saved and displayed with this title.")
    }

    Widgets.TextFieldExt {
        id: nameField

        width: parent.width
        height: VLCStyle.dp(41, VLCStyle.scale)
        leftPadding: VLCStyle.spacing_12
        rightPadding: VLCStyle.spacing_16
        selectByMouse: true
        placeholderText: qsTr("e.g., Favorite TV Channels")

        onAccepted: root.submitRequested()
    }
}
