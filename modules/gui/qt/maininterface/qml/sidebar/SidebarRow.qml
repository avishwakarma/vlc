/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// A row of the library sidebar panel (Figma "media" 2404:9167 / "playlist" 2459:9352):
// 32x32 thumbnail (or icon) + 14px name. Unwatched rows use the primary text color, watched
// rows the dimmed one with a 3px accent progress bar at the bottom of the thumbnail.
T.ItemDelegate {
    id: control

    // Properties

    property string title: ""

    // appended to the title (artist of a song): "title - subtitle"
    property string subtitle: ""

    // image of the thumbnail, when empty `iconName` is drawn in the thumbnail cell
    property string thumbnail: ""

    // pixmaps/svg_icons name used when there is no thumbnail (folder, playlist, add, ...)
    property string iconName: ""

    // watched progress 0..1, negative when there is none
    property real progress: -1

    // false once the media was played
    property bool isNew: true

    // whether the model tells if the media was watched (folders and playlists do not)
    property bool newKnown: true

    // the item that is playing right now
    property bool current: false

    // location of the media, enables dragging the row to the play queue
    property string mrl: ""

    // true for entries that only have an icon (no thumbnail cell background)
    property bool actionRow: false

    readonly property real thumbSize: VLCStyle.dp(32, VLCStyle.scale)

    signal contextMenuRequested(point globalPos)

    // Settings

    implicitWidth: ListView.view ? ListView.view.width : VLCStyle.dp(337, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(42, VLCStyle.scale)

    padding: 0
    leftPadding: 0
    rightPadding: 0

    hoverEnabled: true

    Accessible.name: subtitle !== "" ? (title + " - " + subtitle) : title
    Accessible.onPressAction: control.clicked()

    // Colors

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item

        hovered: control.hovered
        pressed: control.down
        focused: control.visualFocus
    }

    // unwatched media use the primary text color (Figma FG/A1), watched media, folders and
    // playlists the dimmed one (FG/A3)
    readonly property bool unwatched: control.isNew && control.progress <= 0 && control.newKnown

    readonly property color _textColor: control.current ? theme.accent
                                       : (control.hovered || control.visualFocus) ? theme.fg.highlight
                                       : control.unwatched ? theme.fg.primary
                                       : theme.fg.secondary

    // Children

    background: Rectangle {
        radius: VLCStyle.radius_m

        color: (control.hovered || control.down || control.visualFocus || control.highlighted)
               ? itemTheme.bg.primary : "transparent"

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: itemTheme.visualFocus

        Behavior on color {
            ColorAnimation { duration: VLCStyle.duration_short }
        }
    }

    contentItem: Item {
        // thumbnail cell
        Item {
            id: thumbCell

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: control.thumbSize
            height: control.thumbSize

            Rectangle {
                anchors.fill: parent

                // the tile only backs thumbnails; icon rows are drawn without it
                visible: !control.actionRow && control.thumbnail !== ""
                radius: VLCStyle.radius_xxs
                color: itemTheme.bg.secondary
            }

            Image {
                anchors.fill: parent

                visible: control.thumbnail !== "" && status === Image.Ready

                source: control.thumbnail
                sourceSize: Qt.size(control.thumbSize * 2, control.thumbSize * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
            }

            Widgets.SvgIcon {
                anchors.centerIn: parent

                visible: control.iconName !== "" && (control.thumbnail === "" || control.actionRow)

                name: control.iconName
                size: VLCStyle.icon_normal
                color: control._textColor
            }

            // playing marker
            Rectangle {
                anchors.fill: parent

                visible: control.current && !control.actionRow
                radius: VLCStyle.radius_xxs
                color: Qt.rgba(0, 0, 0, 0.55)

                Widgets.SvgIcon {
                    anchors.centerIn: parent

                    name: "playback-twotone"
                    size: VLCStyle.icon_normal
                    color: theme.accentText
                    accentColor: theme.accent
                }
            }

            // progress bar
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom

                visible: control.progress > 0 && !control.actionRow

                width: parent.width * Math.min(control.progress, 1.0)
                height: VLCStyle.dp(3, VLCStyle.scale)
                color: theme.accent
            }
        }

        Text {
            anchors.left: thumbCell.right
            anchors.leftMargin: VLCStyle.spacing_10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: control.subtitle !== "" ? (control.title + " - " + control.subtitle) : control.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1

            color: control._textColor
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular

            Behavior on color {
                ColorAnimation { duration: VLCStyle.duration_short }
            }
        }
    }

    // right click and context menu key
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => control.contextMenuRequested(eventPoint.globalPosition)
    }

    Keys.onMenuPressed: control.contextMenuRequested(control.mapToGlobal(width / 2, height / 2))

    // dragging a media row to the play queue
    DragHandler {
        id: dragHandler

        target: null
        enabled: control.mrl !== ""
        acceptedButtons: Qt.LeftButton
    }

    Item {
        id: dragProxy

        Drag.active: dragHandler.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: control.mrl !== "" ? MainCtx.urlListToMimeData([control.mrl]) : ({})
    }
}
