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
import QtQuick.Controls.Basic as C

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// Messages: the VLC log (level filter, search, copy, save, clear).
DialogShell {
    id: root

    heading: qsTr("Messages")
    cardWidth: 860
    cardHeight: 640

    rejectText: qsTr("Close")
    showAccept: false
    enterAccepts: false
    initialFocusItem: search

    function present() {
        if (!visible)
            open()
        else {
            raise()
            requestActivate()
        }
    }

    MessagesModel {
        id: messages

        ctx: MainCtx
        level: 1
        filter: search.text
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    headerData: [
        Row {
            anchors.fill: parent
            spacing: VLCStyle.spacing_12

            Widgets.SegmentedControl {
                id: levels

                width: VLCStyle.dp(300, VLCStyle.scale)
                height: parent.height
                compact: true
                model: [qsTr("Errors"), qsTr("Warnings"), qsTr("Debug")]
                currentIndex: messages.level
                onActivated: (index) => messages.level = index
            }

            Widgets.TextFieldExt {
                id: search

                width: parent.width - levels.width - parent.spacing
                height: parent.height
                selectByMouse: true
                placeholderText: qsTr("Filter messages")
                Accessible.name: qsTr("Filter messages")
            }
        }
    ]

    footerData: [
        Widgets.DialogButton {
            text: qsTr("Clear")
            enabled: messages.total > 0
            onClicked: messages.clear()
        },
        Widgets.DialogButton {
            text: qsTr("Copy")
            enabled: list.count > 0
            onClicked: messages.copyAll()
        },
        Widgets.DialogButton {
            text: qsTr("Save...")
            enabled: list.count > 0
            onClicked: messages.save()
        }
    ]

    ListView {
        id: list

        anchors.fill: parent
        anchors.leftMargin: VLCStyle.spacing_12
        anchors.rightMargin: VLCStyle.spacing_12
        anchors.topMargin: VLCStyle.spacing_8
        clip: true
        model: messages
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        // follow the end unless the user scrolled up
        property bool atEnd: true
        onMovementEnded: atEnd = atYEnd
        onCountChanged: if (atEnd) Qt.callLater(positionViewAtEnd)

        delegate: Item {
            id: row

            required property string time
            required property int severity
            required property string module
            required property string text

            width: ListView.view.width
            height: Math.max(VLCStyle.dp(24, VLCStyle.scale), msg.implicitHeight + VLCStyle.spacing_4)

            readonly property color severityColor: severity === 1 ? theme.fg.negative
                                                  : severity === 2 ? theme.fg.neutral
                                                  : severity === 3 ? theme.fg.secondary
                                                  : theme.fg.primary

            Rectangle {
                width: VLCStyle.dp(3, VLCStyle.scale)
                height: parent.height - VLCStyle.spacing_4
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: row.severityColor
                opacity: row.severity === 1 || row.severity === 2 ? 1 : 0
            }

            Text {
                id: timeText

                x: VLCStyle.spacing_12
                y: VLCStyle.spacing_2
                width: VLCStyle.dp(92, VLCStyle.scale)
                text: row.time
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_caption
                font.features: { "tnum": 1 }
                textFormat: Text.PlainText
            }

            Text {
                id: moduleText

                x: timeText.x + timeText.width
                y: VLCStyle.spacing_2
                width: VLCStyle.dp(130, VLCStyle.scale)
                text: row.module
                elide: Text.ElideRight
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_caption
                font.weight: VLCStyle.fontWeight_medium
                textFormat: Text.PlainText
            }

            Text {
                id: msg

                x: moduleText.x + moduleText.width + VLCStyle.spacing_8
                y: VLCStyle.spacing_2
                width: parent.width - x - VLCStyle.spacing_8
                text: row.text
                wrapMode: Text.Wrap
                color: row.severity === 1 || row.severity === 2 ? row.severityColor : theme.fg.primary
                font.pixelSize: VLCStyle.text_body
                textFormat: Text.PlainText
            }
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: messages.total === 0 ? qsTr("No messages yet") : qsTr("No message matches")
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
        }
    }
}
