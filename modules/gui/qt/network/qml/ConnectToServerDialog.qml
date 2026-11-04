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
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// "Connect to Server…": address of a share (smb://, nfs://, sftp://, ftp://, http://) and an
// optional user name. The password is never stored here, VLC asks for it when the server needs one.
T.Popup {
    id: root

    // emitted with the final mrl and a display name, `save` = keep in the sidebar
    signal connectRequested(string url, string name, bool save)

    // normalised address typed by the user, "" when it is not usable
    readonly property string address: {
        let text = urlField.text.trim()
        if (text === "")
            return ""
        if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(text))
            text = "smb://" + text
        const m = /^([a-z][a-z0-9+.-]*):\/\/(.*)$/i.exec(text)
        const scheme = m[1].toLowerCase()
        let rest = m[2]
        if (rest === "" || rest[0] === "/")
            return ""
        const user = userField.text.trim()
        const slash = rest.indexOf("/")
        const authority = (slash < 0) ? rest : rest.substring(0, slash)
        if (user !== "" && authority.indexOf("@") < 0)
            rest = encodeURIComponent(user) + "@" + rest
        return scheme + "://" + rest
    }

    readonly property bool valid: address !== ""

    function openDialog() {
        urlField.text = ""
        userField.text = ""
        nameField.text = ""
        saveBox.checked = true
        open()
    }

    function _accept() {
        if (!valid)
            return
        const url = address
        const name = nameField.text.trim()
        close()
        connectRequested(url, name, saveBox.checked)
    }

    parent: T.Overlay.overlay
    anchors.centerIn: parent

    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    width: Math.min(VLCStyle.dp(520, VLCStyle.scale), (parent?.width ?? 600) - VLCStyle.spacing_20 * 2)
    padding: VLCStyle.spacing_20

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    T.Overlay.modal: Rectangle {
        color: theme.scrim
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_short }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_short }
    }

    background: Rectangle {
        radius: VLCStyle.radius_dialog
        color: theme.bg.primary
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: theme.separator
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.spacing_12

        Text {
            Layout.fillWidth: true

            text: qsTr("Connect to Server")
            color: theme.fg.primary
            font.pixelSize: VLCStyle.text_subtitle
            font.weight: VLCStyle.fontWeight_medium
        }

        Text {
            Layout.fillWidth: true

            text: qsTr("Enter the address of a network share, for example smb://nas.local/Movies, nfs://192.168.1.10/media or sftp://host/path.")
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
            wrapMode: Text.WordWrap
        }

        Text {
            text: qsTr("Server Address")
            color: theme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_medium
        }

        Widgets.TextFieldExt {
            id: urlField

            Layout.fillWidth: true

            focus: true
            placeholderText: qsTr("smb://server/share")
            selectByMouse: true

            Accessible.name: qsTr("Server Address")

            onAccepted: root._accept()
        }

        Text {
            text: qsTr("User Name (optional)")
            color: theme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_medium
        }

        Widgets.TextFieldExt {
            id: userField

            Layout.fillWidth: true

            placeholderText: qsTr("Guest")
            selectByMouse: true

            Accessible.name: qsTr("User Name")

            onAccepted: root._accept()
        }

        Text {
            text: qsTr("Name (optional)")
            color: theme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_medium
        }

        Widgets.TextFieldExt {
            id: nameField

            Layout.fillWidth: true

            placeholderText: qsTr("Shown in the sidebar")
            selectByMouse: true

            Accessible.name: qsTr("Name")

            onAccepted: root._accept()
        }

        Widgets.CheckBoxExt {
            id: saveBox

            text: qsTr("Keep in Sidebar")
            checked: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.spacing_8

            spacing: VLCStyle.spacing_10

            Item { Layout.fillWidth: true }

            Widgets.DialogButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }

            Widgets.DialogButton {
                text: qsTr("Connect")
                kind: Widgets.DialogButton.Accent
                enabled: root.valid
                onClicked: root._accept()
            }
        }
    }

    onOpened: urlField.forceActiveFocus()
}
