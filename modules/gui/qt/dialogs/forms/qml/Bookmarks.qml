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
import VLC.Player
import VLC.MediaLibrary

// Chapters of the playing media and the user's bookmarks (jump / add / rename / delete).
DialogShell {
    id: root

    heading: qsTr("Chapters and Bookmarks")
    cardWidth: 560
    cardHeight: 640

    rejectText: qsTr("Close")
    showAccept: false
    enterAccepts: false

    // tab: 0 chapters, 1 bookmarks, -1 chapters if the media has some
    function present(tab) {
        tabs.currentIndex = tab >= 0 ? tab : (Player.hasChapters ? 0 : 1)
        if (!visible)
            open()
        else {
            raise()
            requestActivate()
        }
    }

    function formatTime(ms) {
        const total = Math.round(ms / 1000)
        const h = Math.floor(total / 3600)
        const m = Math.floor(total / 60) % 60
        const s = total % 60
        const two = v => (v < 10 ? "0" : "") + v
        return (h > 0 ? h + ":" + two(m) : m) + ":" + two(s)
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

    MLBookmarkModel {
        id: bookmarks

        player: Player
        ml: MediaLib
    }

    headerData: [
        Widgets.SegmentedControl {
            id: tabs

            anchors.verticalCenter: parent.verticalCenter
            compact: true
            width: parent.width
            height: parent.height
            model: [qsTr("Chapters"), qsTr("Bookmarks")]
            onActivated: (index) => currentIndex = index
        }
    ]

    footerData: [
        Widgets.DialogButton {
            visible: tabs.currentIndex === 1
            text: qsTr("Clear All")
            enabled: list.count > 0
            onClicked: bookmarks.clear()
        },
        Widgets.DialogButton {
            visible: tabs.currentIndex === 1
            kind: Widgets.DialogButton.Primary
            text: qsTr("Add Bookmark")
            enabled: bookmarks.available && Player.playingState !== Player.PLAYING_STATE_STOPPED
            onClicked: bookmarks.add()
        }
    ]

    // time at the right of a row
    component TimeLabel : Text {
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.text_body
        font.features: { "tnum": 1 }
        textFormat: Text.PlainText
    }

    // one row: plate with hover / current state
    component RowPlate : Rectangle {
        id: plate

        property bool current: false
        property bool hovered: hover.hovered

        height: VLCStyle.dp(48, VLCStyle.scale)
        radius: VLCStyle.radius_m
        color: current ? itemTheme.bg.highlight : (hovered ? itemTheme.hoverPlate : "transparent")

        Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }

        HoverHandler { id: hover }
    }

    // --- chapters
    ListView {
        id: chapterList

        anchors.fill: parent
        anchors.margins: VLCStyle.spacing_12
        visible: tabs.currentIndex === 0 && Player.hasChapters
        model: Player.chapters
        clip: true
        spacing: VLCStyle.spacing_2
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        delegate: RowPlate {
            id: chapterRow

            required property int index
            required property string display
            required property bool checked
            required property var time

            width: ListView.view.width
            current: checked

            TapHandler { onTapped: Player.chapters.selectChapter(chapterRow.index) }

            Text {
                x: VLCStyle.spacing_12
                width: VLCStyle.dp(28, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: chapterRow.index + 1
                color: chapterRow.current ? itemTheme.fg.highlight : theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
                font.features: { "tnum": 1 }
            }

            Text {
                x: VLCStyle.spacing_12 + VLCStyle.dp(36, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - timeText.width - 2 * VLCStyle.spacing_12
                text: chapterRow.display
                elide: Text.ElideRight
                color: chapterRow.current ? itemTheme.fg.highlight : theme.fg.primary
                font.pixelSize: VLCStyle.text_body
                font.weight: chapterRow.current ? VLCStyle.fontWeight_medium : VLCStyle.fontWeight_regular
                textFormat: Text.PlainText
            }

            TimeLabel {
                id: timeText

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.spacing_12
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatTime(chapterRow.time.toSeconds() * 1000)
                color: chapterRow.current ? itemTheme.fg.highlight : theme.fg.secondary
            }
        }
    }

    // --- bookmarks
    ListView {
        id: list

        anchors.fill: parent
        anchors.margins: VLCStyle.spacing_12
        visible: tabs.currentIndex === 1 && count > 0
        model: bookmarks
        clip: true
        spacing: VLCStyle.spacing_2
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        delegate: RowPlate {
            id: row

            required property int index
            required property var model

            property bool editing: false

            width: ListView.view.width

            TapHandler {
                enabled: !row.editing
                onTapped: bookmarks.selectRow(row.index)
                onDoubleTapped: row.editing = true
            }

            Widgets.SvgIcon {
                id: icon

                x: VLCStyle.spacing_12
                anchors.verticalCenter: parent.verticalCenter
                name: "bookmarks"
                size: VLCStyle.icon_normal
                color: theme.fg.secondary
            }

            Text {
                visible: !row.editing
                x: icon.x + icon.width + VLCStyle.spacing_12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - buttons.width - timeLabel.width - 3 * VLCStyle.spacing_12
                text: row.model.name
                elide: Text.ElideRight
                color: theme.fg.primary
                font.pixelSize: VLCStyle.text_body
                textFormat: Text.PlainText
            }

            Widgets.TextFieldExt {
                id: nameEdit

                visible: row.editing
                x: icon.x + icon.width + VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - buttons.width - timeLabel.width - 3 * VLCStyle.spacing_12
                height: VLCStyle.dp(34, VLCStyle.scale)
                selectByMouse: true

                onVisibleChanged: if (visible) { text = row.model.name; forceActiveFocus(); selectAll() }
                onAccepted: { row.model.name = text; row.editing = false }
                Keys.onEscapePressed: row.editing = false
                onActiveFocusChanged: if (!activeFocus && row.editing) { row.model.name = text; row.editing = false }
            }

            TimeLabel {
                id: timeLabel

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.spacing_12
                anchors.verticalCenter: parent.verticalCenter
                text: row.model.time
            }

            Row {
                id: buttons

                anchors.right: timeLabel.left
                anchors.rightMargin: VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.spacing_2
                opacity: row.hovered || row.editing ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }

                Widgets.IconToolButton {
                    description: qsTr("Rename")
                    iconName: "edit"
                    onClicked: row.editing = true
                }

                Widgets.IconToolButton {
                    description: qsTr("Delete")
                    iconName: "remove"
                    onClicked: bookmarks.removeBookmark(row.index)
                }
            }
        }
    }

    // --- empty states
    Column {
        anchors.centerIn: parent
        width: parent.width - 4 * VLCStyle.spacing_20
        spacing: VLCStyle.spacing_8
        visible: (tabs.currentIndex === 0 && !Player.hasChapters) || (tabs.currentIndex === 1 && list.count === 0)

        Widgets.SvgIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tabs.currentIndex === 0 ? "chapters" : "bookmarks"
            size: VLCStyle.icon_large
            color: theme.fg.secondary
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tabs.currentIndex === 0 ? qsTr("No chapters")
                  : !MainCtx.mediaLibraryAvailable ? qsTr("Bookmarks need the media library")
                  : Player.playingState === Player.PLAYING_STATE_STOPPED ? qsTr("Nothing is playing")
                  : qsTr("No bookmarks")
            color: theme.fg.heading
            font.pixelSize: VLCStyle.text_heading
            font.weight: VLCStyle.fontWeight_medium
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: tabs.currentIndex === 0 ? qsTr("This media does not define chapters.")
                  : qsTr("Play a media and use Add Bookmark to remember a moment.")
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
        }
    }
}
