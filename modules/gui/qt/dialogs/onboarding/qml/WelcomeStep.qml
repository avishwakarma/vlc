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

// Step 1: welcome + media folder (Figma 1899:3055)
Item {
    id: root

    required property OnboardingController controller
    property bool active: false

    // answer to the privacy question (not in the Figma design: one extra line + toggle)
    readonly property bool metadataAccess: metadataToggle.checked

    function dp(v) { return v * VLCStyle.scale }

    ColorContext {
        id: viewTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    Widgets.SvgIcon {
        id: cone
        x: (root.width - width) / 2 + root.dp(0.5)
        y: root.dp(116)
        size: root.dp(141)
        name: "vlc"
    }

    Text {
        x: (root.width - width) / 2
        y: root.dp(286)
        text: qsTr("Welcome to VLC!")
        color: viewTheme.fg.highlight
        font.pixelSize: VLCStyle.text_display
        font.weight: VLCStyle.fontWeight_light
        // Figma's Inter Light is wider than the bundled Inter 4 Light; match the tracking
        font.letterSpacing: font.pixelSize * 0.027
    }

    Text {
        x: root.dp(248)
        y: root.dp(362)
        width: root.dp(595)
        wrapMode: Text.WordWrap
        lineHeightMode: Text.FixedHeight
        lineHeight: font.pixelSize * 1.75
        // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
        transform: Translate { y: VLCStyle.text_heading * 0.27 }
        color: viewTheme.fg.primary
        font.pixelSize: VLCStyle.text_heading
        font.weight: VLCStyle.fontWeight_light
        font.letterSpacing: font.pixelSize * 0.0075
        text: qsTr("VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and various streaming protocols.")
    }

    Column {
        x: root.dp(248)
        y: root.dp(500)
        width: root.dp(595)
        spacing: VLCStyle.spacing_16

        Text {
            text: qsTr("Choose a Media Folder to get started with")
            color: viewTheme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
        }

        Row {
            width: parent.width
            spacing: VLCStyle.spacing_10

            Widgets.TextFieldExt {
                id: folderField
                width: parent.width - browseButton.width - parent.spacing
                height: VLCStyle.input_h

                text: root.controller.folderText
                color: viewTheme.fg.heading
                font.pixelSize: VLCStyle.text_heading
                leftPadding: VLCStyle.spacing_12
                rightPadding: VLCStyle.spacing_16
                selectByMouse: true
                onEditingFinished: root.controller.setFolderText(text)
                onAccepted: root.controller.setFolderText(text)
                Keys.onReturnPressed: (event) => { root.controller.setFolderText(text); event.accepted = false }
            }

            Widgets.DialogButton {
                id: browseButton
                width: root.dp(114)
                height: VLCStyle.input_h
                text: qsTr("Browse")
                font.pixelSize: VLCStyle.text_heading
                font.weight: VLCStyle.fontWeight_regular
                onClicked: root.controller.browse()
            }
        }
    }

    // Privacy consent (kept from the legacy first-run wizard, "metadata-network-access")
    Item {
        x: root.dp(248)
        y: root.dp(590)
        width: root.dp(595)
        height: VLCStyle.toggle_h

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: metadataToggle.left
            anchors.rightMargin: VLCStyle.spacing_16
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: viewTheme.fg.secondary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
            text: qsTr("Allow network access to fetch cover art and track names")
        }

        Widgets.CheckButton {
            id: metadataToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: false
            text: qsTr("Allow network access for metadata")
        }
    }
}
