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
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

// "Customize Player" (Figma 2107:5604): a modal box over the player with the palette of the
// items that are not in the title bar / control bar. The bars themselves are edited live:
// drag items out of the palette into them, around inside them, or back into the box.
FocusScope {
    id: root

    // Properties

    function dp(n) { return VLCStyle.dp(n, VLCStyle.scale) }

    readonly property var _entries: [
        // [control id, icon, label] in the order of the Figma palette
        [ControlListModel.WIDGET_SPACER, "", qsTr("Spacer")],
        [ControlListModel.DIVIDER_WIDGET, "divider", qsTr("Divider")],
        [ControlListModel.PLAYBACK_SPEED_BUTTON, "speed", qsTr("Playback\nSpeed")],
        [ControlListModel.JUMP_10_FWD_BUTTON, "forward-10-sec", qsTr("Forward\n10s")],
        [ControlListModel.JUMP_10_BACK_BUTTON, "backward-10-sec", qsTr("Backward\n10s")],
        [ControlListModel.JUMP_15_FWD_BUTTON, "forward-15-sec", qsTr("Forward\n15s")],
        [ControlListModel.JUMP_15_BACK_BUTTON, "backward-15-sec", qsTr("Backward\n15s")],
        [ControlListModel.STOP_BUTTON, "stop", qsTr("Stop")],
        [ControlListModel.LOOP_BUTTON, "repeat-right", qsTr("Repeat")],
        [ControlListModel.RANDOM_BUTTON, "shuffle-right", qsTr("Shuffle")],
        [ControlListModel.RECORD_BUTTON, "record", qsTr("Record")],
        [ControlListModel.SNAPSHOT_BUTTON, "snapshot", qsTr("Snapshot")],
        [ControlListModel.PIP_BUTTON, "PiP", qsTr("Picture in\nPicture")],
        [ControlListModel.HDR_BUTTON, "HDR", qsTr("HDR")],
        [ControlListModel.ZOOM_BUTTON, "zoom", qsTr("Zoom")],
        [ControlListModel.RIGHT_SIDEBAR_BUTTON, "sidebar-right", qsTr("Right\nSidebar")],
        [ControlListModel.QUIT_BUTTON, "quit", qsTr("Quit VLC")],
        [ControlListModel.SETTINGS_BUTTON, "settings", qsTr("VLC Settings")],
        [ControlListModel.HOME_BUTTON, "home", qsTr("Go Home")],
        [ControlListModel.THUMBNAIL_WIDGET, "thumbnail", qsTr("Thumbnail")],
        [ControlListModel.FILE_NAME_WIDGET, "info", qsTr("File Name")],
        [ControlListModel.ARTIST_NAME_WIDGET, "info", qsTr("Artist Name")],
        [ControlListModel.FOLDER_NAME_WIDGET, "info", qsTr("Folder Name")],
        [ControlListModel.PLAYLIST_NAME_WIDGET, "info", qsTr("Playlist\nName")],
        [ControlListModel.PROPERTIES_BUTTON, "info", qsTr("Properties")],
        [ControlListModel.REPLAY_BUTTON, "replay", qsTr("Replay")],
        [ControlListModel.CHAPTERS_BUTTON, "chapters", qsTr("Chapters")],
        [ControlListModel.FAVORITE_BUTTON, "favorite", qsTr("Favorite")],
        [ControlListModel.BOOKMARK_BUTTON, "bookmark", qsTr("Bookmark")],
        [ControlListModel.BOOKMARKS_LIST_BUTTON, "bookmarks", qsTr("Bookmarks")],
        [ControlListModel.PLAYLISTS_BUTTON, "playlist", qsTr("Playlists")]
    ]

    // Items of the default bars that are not in the Figma palette: they show up here once
    // they have been taken out of the bar so that they can be put back.
    readonly property var _restorable: [
        [ControlListModel.PREVIOUS_BUTTON, "previous", qsTr("Previous")],
        [ControlListModel.PLAY_BUTTON, "play", qsTr("Play")],
        [ControlListModel.NEXT_BUTTON, "next", qsTr("Next")],
        [ControlListModel.TIMELINE, "", qsTr("Seek bar")],
        [ControlListModel.VOLUME, "volume-high", qsTr("Volume")],
        [ControlListModel.AUDIO_TRACKS_BUTTON, "audio", qsTr("Audio")],
        [ControlListModel.SUBTITLE_TRACKS_BUTTON, "subtitles", qsTr("Subtitles")],
        [ControlListModel.EXTENDED_BUTTON, "playback-settings", qsTr("Playback Settings")],
        [ControlListModel.PLAYLIST_BUTTON, "lists", qsTr("Play Queue")],
        [ControlListModel.FULLSCREEN_BUTTON, "fullscreen", qsTr("Fullscreen")],
        [ControlListModel.TITLE_MENU_BUTTON, "more", qsTr("Menu")],
        [ControlListModel.TITLE_SIDEBAR_BUTTON, "sidebar-left", qsTr("Sidebar")],
        [ControlListModel.TITLE_BREADCRUMB_BUTTON, "folder", qsTr("Breadcrumb")],
        [ControlListModel.TITLE_TEXT_WIDGET, "", qsTr("Title")],
        [ControlListModel.WINDOW_MINIMIZE_BUTTON, "minimize", qsTr("Minimize")],
        [ControlListModel.WINDOW_MAXIMIZE_BUTTON, "maximize", qsTr("Maximize")],
        [ControlListModel.WINDOW_CLOSE_BUTTON, "close", qsTr("Close")]
    ]

    // palette content: depends on the items that are in the bars
    readonly property var paletteEntries: {
        void PlayerCustomizer.revision

        const list = []
        for (const e of _entries) {
            if (PlayerCustomizer.isRepeatable(e[0]) || !PlayerCustomizer.isPlaced(e[0]))
                list.push({ "id": e[0], "icon": e[1], "label": e[2] })
        }
        for (const e of _restorable) {
            if (!PlayerCustomizer.isPlaced(e[0]))
                list.push({ "id": e[0], "icon": e[1], "label": e[2] })
        }
        return list
    }

    // number of rows the dialog is sized for (stable while items move in and out)
    readonly property int _columns: Math.max(1, Math.min(9, Math.floor((dialog.width - dp(40)) / cellWidth)))
    readonly property int _rows: Math.ceil((_entries.length + 1) / _columns)

    readonly property real cellWidth: dp(110)
    readonly property real rowHeight: dp(119)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    readonly property ColorContext headerColorContext: ColorContext {
        id: headerTheme
        colorSet: ColorContext.View
    }

    // Settings

    focus: true

    Keys.onEscapePressed: (event) => {
        event.accepted = true
        if (PlayerCustomizer.dragging)
            PlayerCustomizer.abortDrag()
        else
            root.cancel()
    }

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Customize Player")

    // Functions

    function cancel() {
        PlayerCustomizer.cancel()
    }

    function save() {
        MainCtx.controlbarProfileModel.save()
        PlayerCustomizer.accept()
    }

    Component.onCompleted: {
        if (root.visible)
            PlayerCustomizer.paletteArea = dialog
        root.forceActiveFocus()
        Qt.callLater(PlayerCustomizer.start)
        root.shown = true
    }

    onVisibleChanged: {
        if (visible)
            PlayerCustomizer.paletteArea = dialog
        else if (PlayerCustomizer.paletteArea === dialog)
            PlayerCustomizer.paletteArea = null
    }

    Component.onDestruction: {
        if (PlayerCustomizer.paletteArea === dialog)
            PlayerCustomizer.paletteArea = null
    }

    property bool shown: false

    Connections {
        target: PlayerCustomizer

        function onSaved() { root.finished() }
        function onCancelled() { root.finished() }
    }

    function finished() {
        if (PlayerCustomizer.cameFromLibrary) {
            PlayerCustomizer.cameFromLibrary = false
            MainCtx.playerView = false
        }
    }

    // Children

    // modal: nothing behind the box is clickable (the bars stay active: they are being edited)
    MouseArea {
        anchors.fill: parent

        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onWheel: (wheel) => wheel.accepted = true
    }

    Item {
        id: dialogHost

        anchors.fill: parent

        Item {
            id: dialog

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            // Figma 2107:5604: the box sits a bit above the middle of the viewport
            anchors.verticalCenterOffset: -root.dp(16)

            width: Math.min(root.dp(1048), root.width - root.dp(40))
            height: Math.min(root.dp(654), root.height - root.dp(40))

            opacity: root.shown ? 1.0 : 0.0
            scale: root.shown ? 1.0 : 0.96

            Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.OutQuad } }

            Widgets.DefaultShadow {
                radius: VLCStyle.radius_l
            }

            Rectangle {
                id: body

                anchors.fill: parent

                radius: VLCStyle.radius_l
                color: theme.bg.primary
                clip: true

            // eat the clicks on the box
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            // Header: title and hint (B2 strip)
            Rectangle {
                id: header

                width: parent.width
                height: root.dp(93)

                color: headerTheme.bg.secondary

                Text {
                    x: root.dp(19)
                    y: root.dp(25) - height / 2 + root.dp(0)

                    text: qsTr("Customize Player")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular

                    Accessible.role: Accessible.Heading
                }

                Text {
                    x: root.dp(19)
                    y: root.dp(69) - height / 2

                    width: parent.width - root.dp(38)

                    text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular
                    elide: Text.ElideRight
                }

                Widgets.IconToolButton {
                    id: closeButton

                    x: parent.width - width - root.dp(13)
                    y: root.dp(25) - height / 2

                    width: root.dp(28)
                    height: root.dp(28)

                    iconName: "close"
                    text: VLCIcons.close
                    description: qsTr("Close")

                    onClicked: root.cancel()
                }
            }

            // Palette
            Flickable {
                id: flick

                anchors.top: header.bottom
                anchors.topMargin: root.dp(28)
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.leftMargin: root.dp(22)
                anchors.right: parent.right
                anchors.rightMargin: root.dp(22)

                clip: true
                contentWidth: width
                contentHeight: grid.height
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height && !PlayerCustomizer.dragging

                T.ScrollBar.vertical: Widgets.ScrollBarExt {}

                // cells are laid out by hand: the dragged item leaves the grid and the
                // others glide to their new place
                Item {
                    id: grid

                    width: flick.width
                    height: (root._rows - 1) * root.rowHeight + root.dp(90)

                    // centered group of columns
                    readonly property real originX: (root._columns < 9) ? Math.max(0, (width - root._columns * root.cellWidth) / 2) : 0

                    Repeater {
                        model: root.paletteEntries

                        delegate: Item {
                            id: cell

                            required property int index
                            required property var modelData

                            readonly property bool dragged: PlayerCustomizer.dragging
                                                            && PlayerCustomizer.dragFromZone === "palette"
                                                            && PlayerCustomizer.dragId === modelData.id

                            width: root.cellWidth
                            height: root.rowHeight

                            x: grid.originX + (index % root._columns) * root.cellWidth
                            y: Math.floor(index / root._columns) * root.rowHeight

                            Behavior on x { NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad } }
                            Behavior on y { NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad } }

                            opacity: dragged ? 0.35 : 1.0

                            Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }

                            activeFocusOnTab: true

                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.label
                            Accessible.description: qsTr("Press Enter to add it to the control bar")

                            Keys.onReturnPressed: root.append(cell.modelData.id)
                            Keys.onEnterPressed: root.append(cell.modelData.id)
                            Keys.onSpacePressed: root.append(cell.modelData.id)

                            readonly property ColorContext cellColorContext: ColorContext {
                                id: cellTheme
                                colorSet: ColorContext.Item
                                hovered: area.containsMouse
                                pressed: area.pressed
                            }

                            // icon box: 32x32, dashed
                            Rectangle {
                                id: box

                                anchors.horizontalCenter: parent.horizontalCenter
                                y: root.dp(5)

                                width: root.dp(32)
                                height: root.dp(32)

                                color: (area.containsMouse || cell.activeFocus) ? cellTheme.bg.primary : "transparent"

                                Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }

                                Widgets.DashedBorder {
                                    anchors.fill: parent
                                    color: cell.activeFocus ? theme.accent : (area.containsMouse ? headerTheme.fg.primary : theme.fg.secondary)
                                }

                                Widgets.SvgIcon {
                                    anchors.centerIn: parent
                                    visible: cell.modelData.icon !== ""
                                    name: cell.modelData.icon
                                    size: VLCStyle.icon_normal
                                    color: theme.fg.primary
                                    accentColor: theme.accent
                                }
                            }

                            Text {
                                anchors.top: box.bottom
                                anchors.topMargin: root.dp(17)
                                anchors.horizontalCenter: parent.horizontalCenter

                                width: root.dp(94)

                                text: cell.modelData.label
                                color: theme.fg.primary
                                font.pixelSize: VLCStyle.text_body
                                font.weight: VLCStyle.fontWeight_regular
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: area

                                anchors.fill: parent
                                anchors.margins: root.dp(4)

                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: PlayerCustomizer.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                property point pressPoint

                                onPressed: (mouse) => {
                                    pressPoint = Qt.point(mouse.x, mouse.y)
                                    PlayerCustomizer.dragAborted = false
                                    cell.forceActiveFocus(Qt.MouseFocusReason)
                                }

                                onPositionChanged: (mouse) => {
                                    const p = area.mapToItem(null, mouse.x, mouse.y)
                                    if (PlayerCustomizer.dragging) {
                                        PlayerCustomizer.updateDrag(p.x, p.y)
                                    } else if (pressed && Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) > root.dp(4)) {
                                        PlayerCustomizer.beginDrag(cell.modelData.id, "palette", -1, p.x, p.y,
                                                                   cell.modelData.id === ControlListModel.TIMELINE ? root.dp(240) : root.dp(32),
                                                                   root.dp(28))
                                    }
                                }

                                onReleased: {
                                    if (PlayerCustomizer.dragging)
                                        PlayerCustomizer.endDrag()
                                }

                                onCanceled: {
                                    if (PlayerCustomizer.dragging)
                                        PlayerCustomizer.cancelDrag()
                                }
                            }
                        }
                    }
                }
            }

            // Footer: Cancel / Save
            Item {
                id: footer

                anchors.bottom: parent.bottom
                width: parent.width
                height: root.dp(19) + root.dp(32) + root.dp(19)

                Widgets.DialogButton {
                    x: root.dp(20)
                    y: root.dp(19)

                    text: qsTr("Cancel")

                    onClicked: root.cancel()
                }

                Widgets.DialogButton {
                    x: parent.width - width - root.dp(20)
                    y: root.dp(19)

                    kind: PlayerCustomizer.dirty ? Widgets.DialogButton.Primary : Widgets.DialogButton.Secondary
                    text: qsTr("Save")
                    enabled: PlayerCustomizer.dirty

                    onClicked: root.save()
                }
            }
            }
        }
    }

    // Keyboard alternative to dragging: appends the item to the right of the control bar
    function append(id) {
        const zone = PlayerCustomizer.zones["bar.right"]
        if (!zone || !zone.controls)
            return
        zone.controls.insert(zone.controls.count, { "id": id })
    }

    // The item that is dragged
    Item {
        id: ghost

        visible: PlayerCustomizer.dragging

        readonly property point origin: root.mapFromItem(null, PlayerCustomizer.ghostX, PlayerCustomizer.ghostY)

        x: origin.x - width / 2
        y: origin.y - height / 2

        width: Math.max(root.dp(32), PlayerCustomizer.dragWidth)
        height: Math.max(root.dp(32), PlayerCustomizer.dragHeight)

        z: 10

        readonly property var entry: (PlayerCustomizer.dragId >= 0) ? PlayerControlbarControls.control(PlayerCustomizer.dragId) : null

        Rectangle {
            anchors.fill: parent
            color: theme.bg.primary
            opacity: 0.9
        }

        Widgets.DashedBorder {
            anchors.fill: parent
            color: theme.accent
        }

        Widgets.SvgIcon {
            anchors.centerIn: parent
            visible: !!ghost.entry && !!ghost.entry.icon && ghost.width < root.dp(100)
            name: (ghost.entry && ghost.entry.icon) ? ghost.entry.icon : ""
            size: VLCStyle.icon_normal
            color: theme.fg.primary
            accentColor: theme.accent
        }

        Text {
            anchors.centerIn: parent
            visible: ghost.width >= root.dp(100)
            text: ghost.entry ? ghost.entry.text : ""
            color: theme.fg.primary
            font.pixelSize: VLCStyle.text_body
        }
    }
}
