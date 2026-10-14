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
import QtQuick.Shapes

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// New Playlist (Figma 6259:14954). Creates a media library playlist from a name and optional files
// (drop them on the box or click it). Open it with DialogsProvider.newPlaylistDialog().
DialogShell {
    id: root

    heading: qsTr("New Playlist")
    cardWidth: 713
    cardHeight: 589

    acceptText: qsTr("Save")
    acceptEnabled: forms.mediaLibraryAvailable && nameField.text.trim() !== ""
    initialFocusItem: nameField

    // URLs of the files to add
    property var files: []

    onAccepted: {
        if (forms.createPlaylist(nameField.text, root.files))
            close()
    }

    function addFiles(urls) {
        const list = root.files.slice()
        for (const url of urls) {
            if (list.indexOf(url) < 0)
                list.push(url)
        }
        root.files = list
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
        id: dimTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
        enabled: false
    }

    ColorContext {
        id: fieldTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.TextField
    }

    onVisibleChanged: {
        if (visible) {
            nameField.text = ""
            root.files = []
        }
    }

    // boxes of the dialog: B2 well, 2 px A4 border, r6
    component Well : Rectangle {
        radius: VLCStyle.radius_m
        color: fieldTheme.bg.secondary
        border.width: VLCStyle.dp(2, VLCStyle.scale)
        border.color: fieldTheme.border
    }

    // square "+" button (fg.highlight of the text field set is the B1 colour of the design)
    component PlusButton : Item {
        id: plus

        property bool hovered: hover.hovered
        signal clicked()

        implicitWidth: VLCStyle.icon_normal + horizontalPadding * 2
        implicitHeight: VLCStyle.icon_normal + VLCStyle.spacing_6
        property real horizontalPadding: VLCStyle.spacing_2 + VLCStyle.dp(1, VLCStyle.scale)

        Rectangle {
            anchors.fill: parent
            radius: VLCStyle.radius_s + VLCStyle.dp(1, VLCStyle.scale)
            color: fieldTheme.fg.highlight
        }

        Widgets.SvgIcon {
            anchors.centerIn: parent
            name: "add"
            size: VLCStyle.icon_normal
            color: plus.hovered ? theme.fg.highlight : theme.fg.primary
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: plus.clicked() }
    }

    Column {
        x: VLCStyle.spacing_20
        y: VLCStyle.dp(22, VLCStyle.scale)
        width: root.body.width - 2 * VLCStyle.spacing_20
        spacing: VLCStyle.spacing_20

        Item {
            width: parent.width
            height: Math.max(detailsColumn.height, coverWell.height)

            Column {
                id: detailsColumn

                anchors.left: parent.left
                anchors.right: coverWell.left
                anchors.rightMargin: VLCStyle.spacing_20
                anchors.bottom: parent.bottom
                spacing: VLCStyle.spacing_20

                DialogHeading {
                    width: parent.width
                    label: qsTr("Playlist Details")
                    helper: forms.mediaLibraryAvailable
                            ? qsTr("The playlist will be saved and displayed with this title and thumbnail.")
                            : qsTr("Playlists are stored in the media library, which is not available.")
                }

                Widgets.TextFieldExt {
                    id: nameField

                    width: parent.width
                    height: VLCStyle.dp(41, VLCStyle.scale)
                    leftPadding: VLCStyle.spacing_12
                    rightPadding: VLCStyle.spacing_16
                    selectByMouse: true
                    placeholderText: qsTr("e.g., Favorite Videos")
                    enabled: forms.mediaLibraryAvailable

                    onAccepted: root.accept()
                }
            }

            // thumbnail well. The media library can not store a cover for a playlist yet, so it is
            // only displayed
            Well {
                id: coverWell

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: VLCStyle.dp(112, VLCStyle.scale)
                height: width

                PlusButton {
                    anchors.centerIn: parent
                    enabled: false
                }
            }
        }

        Rectangle {
            width: parent.width
            height: VLCStyle.dp(1, VLCStyle.scale)
            color: theme.separator
        }

        DialogHeading {
            width: parent.width
            label: qsTr("Select Files")
            helper: qsTr("These files will be added to the playlist.")
        }

        // drop zone
        Rectangle {
            id: dropZone

            width: parent.width
            height: VLCStyle.dp(186, VLCStyle.scale)
            radius: VLCStyle.radius_m
            color: fieldTheme.bg.secondary

            readonly property real stroke: VLCStyle.dp(2, VLCStyle.scale)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: (dropArea.containsDrag || hoverZone.hovered)
                                 ? theme.fg.secondary : Qt.lighter(theme.separator, 1.35)
                    strokeWidth: dropZone.stroke
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    capStyle: ShapePath.FlatCap

                    Behavior on strokeColor { ColorAnimation { duration: VLCStyle.duration_short } }

                    PathRectangle {
                        x: dropZone.stroke / 2
                        y: dropZone.stroke / 2
                        width: dropZone.width - dropZone.stroke
                        height: dropZone.height - dropZone.stroke
                        radius: dropZone.radius - dropZone.stroke / 2
                    }
                }
            }

            HoverHandler { id: hoverZone; cursorShape: Qt.PointingHandCursor }

            TapHandler {
                onTapped: root.addFiles(forms.pickMediaFiles(qsTr("Select Files")))
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: (drop) => {
                    if (drop.hasUrls)
                        root.addFiles(drop.urls.map(u => u.toString()))
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: VLCStyle.spacing_20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.files.length > 0
                          ? qsTr("%1 file(s) selected, drag more files or click here to add more.").arg(root.files.length)
                          : qsTr("Drag files into the box or click here to select files.")
                    color: root.files.length > 0 ? theme.fg.primary : dimTheme.fg.primary
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular
                }

                PlusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalPadding: VLCStyle.dp(30, VLCStyle.scale)
                    hovered: hoverZone.hovered
                }
            }
        }
    }
}
