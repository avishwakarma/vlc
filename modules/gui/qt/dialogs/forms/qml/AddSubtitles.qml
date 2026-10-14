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
import QtQuick.Controls.Basic as C

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// Add Subtitles (Figma 1911:7545 "To This Folder", 1919:8707 "To This File").
//
//  - To This File: pick subtitle files of a folder (default: the folder of the playing media), they are
//    added to the playing media.
//  - To This Folder: the items of the play queue that are in the chosen folder are paired with the subtitle
//    file of the folder that has the same name; Save adds it to each item as a `sub-file` option, so it is
//    loaded whenever the item plays. This lasts as long as the queue entry, VLC has no storage for it.
//
// "From OpenSubtitles" (1919:9278) is not offered: it is the vlsub Lua extension, which is not part of the
// interface.
DialogShell {
    id: root

    heading: qsTr("Add Subtitles")
    cardWidth: 1048
    cardHeight: 800
    darkPane: true

    // 0: to the playing media, 1: to the queue items of the folder
    readonly property int mode: targetBox.currentIndex
    readonly property bool toFile: mode === 0

    property url folder
    // [{ name, url }]
    property var subtitles: []
    // [{ index, name, subName, subUrl }]
    property var matches: []
    // urls of the checked subtitles (To This File)
    property var checkedUrls: []

    readonly property bool playing: forms.hasCurrentMedia()
    readonly property int matchCount: {
        let n = 0
        for (const m of matches) {
            if (m.subName !== "")
                n++
        }
        return n
    }

    acceptText: qsTr("Save")
    acceptEnabled: toFile ? (checkedUrls.length > 0 && playing) : matchCount > 0
    initialFocusItem: toFile ? fileList : folderList

    onAccepted: {
        if (toFile) {
            forms.attachSubtitles(checkedUrls.map(u => u.toString()))
        } else {
            forms.assignToQueue(matches.filter(m => m.subName !== "")
                                       .map(m => ({ index: m.index, subUrl: m.subUrl })))
        }
        close()
    }

    function refresh() {
        subtitles = forms.subtitleFiles(folder)
        matches = forms.queueMatches(folder)
        checkedUrls = []
    }

    function toggle(url) {
        const list = checkedUrls.slice()
        const i = list.findIndex(u => u.toString() === url.toString())
        if (i >= 0)
            list.splice(i, 1)
        else
            list.push(url)
        checkedUrls = list
    }

    function isChecked(url) {
        return checkedUrls.some(u => u.toString() === url.toString())
    }

    onVisibleChanged: {
        if (visible) {
            targetBox.currentIndex = 0
            folder = forms.defaultSubtitleFolder()
            refresh()
        }
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
        hovered: true
    }

    ColorContext {
        id: fieldTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.TextField
    }

    // --- header row

    headerData: [
        DialogDropdown {
            id: targetBox

            width: VLCStyle.dp(200, VLCStyle.scale)
            model: [qsTr("To This File"), qsTr("To This Folder")]

            Keys.priority: Keys.AfterItem
            KeyNavigation.right: sourceBox
        },

        DialogDropdown {
            id: sourceBox

            x: targetBox.width + VLCStyle.spacing_10
            width: VLCStyle.dp(200, VLCStyle.scale)
            // OpenSubtitles needs the vlsub extension (Lua), which the interface does not provide
            model: [qsTr("From Computer")]
        },

        // folder to look into
        T_Button {
            id: folderButton

            x: sourceBox.x + sourceBox.width + VLCStyle.spacing_10
            width: parent.width - x
            height: parent.height

            onClicked: {
                root.folder = forms.pickFolder(root.folder)
                root.refresh()
            }
        }
    ]

    component T_Button : C.AbstractButton {
        id: button

        hoverEnabled: true
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Folder: %1").arg(forms.folderText(root.folder))

        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

        background: Rectangle {
            radius: VLCStyle.radius_m
            color: (button.hovered || button.down) ? itemTheme.bg.primary : fieldTheme.bg.primary
            border.width: button.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: theme.visualFocus

            Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
        }

        contentItem: Item {
            Widgets.SvgIcon {
                x: VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                name: "folder"
                size: VLCStyle.icon_normal
                color: theme.fg.primary
            }

            Text {
                x: VLCStyle.spacing_8 + VLCStyle.icon_normal + VLCStyle.spacing_10
                width: parent.width - x - VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                text: forms.folderText(root.folder)
                color: theme.fg.primary
                elide: Text.ElideLeft
                font.pixelSize: VLCStyle.text_body
                font.weight: VLCStyle.fontWeight_regular
                textFormat: Text.PlainText
            }
        }
    }

    // --- body

    component FileIcon : Widgets.SvgIcon {
        size: VLCStyle.icon_normal
        color: theme.fg.secondary
    }

    component EmptyText : Text {
        anchors.centerIn: parent
        width: parent.width - 2 * VLCStyle.spacing_20
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.text_body
        font.weight: VLCStyle.fontWeight_regular
    }

    // To This File: one row per subtitle file of the folder, checked rows are added
    ListView {
        id: fileList

        anchors.fill: parent
        anchors.topMargin: VLCStyle.dp(22, VLCStyle.scale)
        anchors.leftMargin: VLCStyle.spacing_20
        anchors.rightMargin: VLCStyle.spacing_20
        anchors.bottomMargin: VLCStyle.spacing_20

        visible: root.toFile
        clip: true
        spacing: VLCStyle.spacing_4
        model: root.subtitles
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: 0
        keyNavigationEnabled: true
        activeFocusOnTab: true

        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Keys.onPressed: (event) => {
            if ((event.key === Qt.Key_Space) && currentIndex >= 0 && currentIndex < root.subtitles.length) {
                root.toggle(root.subtitles[currentIndex].url)
                event.accepted = true
            } else {
                Navigation.defaultKeyAction(event)
            }
        }

        delegate: Item {
            id: fileRow

            required property int index
            required property var modelData

            readonly property bool checked: root.isChecked(modelData.url)

            width: ListView.view.width
            height: VLCStyle.dp(36, VLCStyle.scale)

            Rectangle {
                anchors.fill: parent
                radius: VLCStyle.radius_m
                // checked rows sit in a B2 well, hovered ones in the item hover colour
                color: fileRow.checked ? theme.bg.secondary
                                       : (hover.hovered ? itemTheme.bg.primary : "transparent")
                border.width: (fileList.activeFocus && fileRow.ListView.isCurrentItem) ? VLCStyle.dp(1, VLCStyle.scale) : 0
                border.color: theme.visualFocus

                Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
            }

            FileIcon {
                x: VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                name: "subtitle-file"
            }

            Text {
                x: VLCStyle.spacing_8 + VLCStyle.icon_normal + VLCStyle.spacing_14
                width: parent.width - x - VLCStyle.spacing_8 * 2 - VLCStyle.icon_normal
                anchors.verticalCenter: parent.verticalCenter
                text: fileRow.modelData.name
                color: theme.fg.primary
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.text_body
                font.weight: VLCStyle.fontWeight_regular
                textFormat: Text.PlainText
            }

            Widgets.SvgIcon {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                name: "check-active"
                size: VLCStyle.icon_normal
                color: theme.fg.primary
                accentColor: theme.accent
                opacity: fileRow.checked ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
            }

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    fileList.currentIndex = fileRow.index
                    fileList.forceActiveFocus(Qt.MouseFocusReason)
                    root.toggle(fileRow.modelData.url)
                }
            }

            Accessible.role: Accessible.CheckBox
            Accessible.name: fileRow.modelData.name
            Accessible.checked: fileRow.checked
        }

        EmptyText {
            visible: root.subtitles.length === 0
            text: qsTr("There is no subtitle file in this folder.")
        }
    }

    EmptyText {
        parent: root.body
        visible: root.toFile && root.subtitles.length > 0 && !root.playing
        anchors.centerIn: undefined
        y: root.body.height - height - VLCStyle.spacing_20 * 2
        text: qsTr("Nothing is playing, there is no media to add the subtitles to.")
    }

    // To This Folder: queue items of the folder (left) and the subtitle file that goes with each (right)
    ListView {
        id: folderList

        anchors.fill: parent
        anchors.topMargin: VLCStyle.dp(30, VLCStyle.scale)
        anchors.bottomMargin: VLCStyle.spacing_20

        visible: !root.toFile
        clip: true
        spacing: VLCStyle.spacing_16
        model: root.matches
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: true

        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

        delegate: Item {
            id: pairRow

            required property var modelData
            readonly property bool matched: modelData.subName !== ""
            readonly property real columnWidth: ListView.view.width / 2

            width: ListView.view.width
            height: VLCStyle.dp(24, VLCStyle.scale)

            // video, dashed link
            Item {
                id: videoSide

                x: VLCStyle.dp(30, VLCStyle.scale)
                width: pairRow.columnWidth - x
                height: parent.height

                FileIcon {
                    id: videoIcon
                    name: "clapperboard"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: videoName

                    x: videoIcon.width + VLCStyle.spacing_14
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, videoSide.width - x - VLCStyle.dp(60, VLCStyle.scale))
                    text: pairRow.modelData.name
                    color: theme.fg.primary
                    elide: Text.ElideRight
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular
                    textFormat: Text.PlainText
                }

                Item {
                    id: dash

                    x: videoName.x + videoName.width + VLCStyle.spacing_14
                    width: videoSide.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    height: VLCStyle.dp(1, VLCStyle.scale)
                    visible: pairRow.matched

                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: theme.border
                            strokeWidth: VLCStyle.dp(1, VLCStyle.scale)
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [6, 6]
                            fillColor: "transparent"
                            startX: 0
                            startY: 0
                            PathLine { x: dash.width; y: 0 }
                        }
                    }
                }
            }

            // subtitle
            Item {
                x: pairRow.columnWidth + VLCStyle.spacing_20 + VLCStyle.spacing_8
                y: -VLCStyle.dp(2, VLCStyle.scale)
                width: pairRow.width - x - VLCStyle.spacing_20
                height: parent.height
                visible: pairRow.matched

                FileIcon {
                    id: subIcon
                    name: "subtitle-file"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    x: subIcon.width + VLCStyle.spacing_14
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    text: pairRow.modelData.subName
                    color: theme.fg.primary
                    elide: Text.ElideRight
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular
                    textFormat: Text.PlainText
                }
            }

            // no subtitle file with the name of this item
            Text {
                x: pairRow.columnWidth + VLCStyle.spacing_20 + VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                visible: !pairRow.matched
                text: qsTr("No matching subtitle file")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
                font.weight: VLCStyle.fontWeight_regular
            }
        }

        EmptyText {
            visible: root.matches.length === 0
            text: qsTr("No file of the play queue is in this folder.")
        }
    }
}
