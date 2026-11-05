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

// Add to Playlist: pick one of the library playlists, or name a new one.
DialogShell {
    id: root

    heading: qsTr("Add to Playlist")
    cardWidth: 520
    cardHeight: 600

    acceptText: qsTr("Add")
    acceptEnabled: mediaCount > 0 && (list.currentIndex >= 0 || newName.text.trim() !== "")
    initialFocusItem: newName

    property int mediaCount: 0

    function present() {
        mediaCount = forms.takePlaylistMedias()
        list.currentIndex = -1
        newName.text = ""
        if (!visible)
            open()
        else {
            raise()
            requestActivate()
        }
    }

    onAccepted: {
        if (list.currentIndex >= 0)
            forms.addToPlaylist(list.currentIndex)
        else
            forms.addToNewPlaylist(newName.text)
        close()
    }

    DialogForms {
        id: forms
        ctx: MainCtx
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    ColorContext {
        id: itemTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Item
    }

    footerData: [
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.mediaCount > 0 ? qsTr("%1 media selected").arg(root.mediaCount) : ""
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
            rightPadding: VLCStyle.spacing_8
        }
    ]

    Column {
        id: content

        x: VLCStyle.spacing_20
        y: VLCStyle.dp(22, VLCStyle.scale)
        width: root.body.width - 2 * VLCStyle.spacing_20
        height: root.body.height - y
        spacing: VLCStyle.spacing_16

        DialogHeading {
            width: parent.width
            label: qsTr("Existing playlists")
            helper: forms.mediaLibraryAvailable ? qsTr("Choose where the media will be added.")
                                                : qsTr("Playlists need the media library.")
        }

        Rectangle {
            width: parent.width
            height: parent.height - y - newBox.height - parent.spacing
            radius: VLCStyle.radius_m
            color: theme.bg.secondary
            clip: true

            ListView {
                id: list

                anchors.fill: parent
                anchors.margins: VLCStyle.spacing_4
                model: forms.playlistModel
                currentIndex: -1
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                C.ScrollBar.vertical: Widgets.ScrollBarExt { }

                onCurrentIndexChanged: if (currentIndex >= 0) newName.text = ""

                delegate: Rectangle {
                    id: row

                    required property int index
                    required property string name
                    required property var count

                    readonly property bool selected: ListView.isCurrentItem

                    width: ListView.view.width
                    height: VLCStyle.dp(48, VLCStyle.scale)
                    radius: VLCStyle.radius_m
                    color: selected ? itemTheme.bg.highlight : (hover.hovered ? itemTheme.hoverPlate : "transparent")

                    Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }

                    HoverHandler { id: hover }
                    TapHandler {
                        onTapped: list.currentIndex = row.index
                        onDoubleTapped: { list.currentIndex = row.index; root.accept() }
                    }

                    Widgets.SvgIcon {
                        id: icon

                        x: VLCStyle.spacing_12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "playlist"
                        size: VLCStyle.icon_normal
                        color: row.selected ? itemTheme.fg.highlight : theme.fg.secondary
                    }

                    Text {
                        x: icon.x + icon.width + VLCStyle.spacing_12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - countText.width - 2 * VLCStyle.spacing_12
                        text: row.name
                        elide: Text.ElideRight
                        color: row.selected ? itemTheme.fg.highlight : theme.fg.primary
                        font.pixelSize: VLCStyle.text_body
                        textFormat: Text.PlainText
                    }

                    Text {
                        id: countText

                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.spacing_12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Number(row.count) === 1 ? qsTr("1 item") : qsTr("%1 items").arg(row.count)
                        color: row.selected ? itemTheme.fg.highlight : theme.fg.secondary
                        font.pixelSize: VLCStyle.text_body
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: qsTr("No playlists yet")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }
        }

        Column {
            id: newBox

            width: parent.width
            spacing: VLCStyle.spacing_8

            DialogHeading {
                width: parent.width
                label: qsTr("New playlist")
            }

            Widgets.TextFieldExt {
                id: newName

                width: parent.width
                height: VLCStyle.dp(41, VLCStyle.scale)
                enabled: forms.mediaLibraryAvailable
                selectByMouse: true
                placeholderText: qsTr("e.g., Favourite songs")

                onTextEdited: if (text !== "") list.currentIndex = -1
                onAccepted: root.accept()
            }
        }
    }
}
