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
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Sidebar panel listing the items of a model as rows (or tiles in grid view).
SidebarPage {
    id: root

    // Properties

    property var model: null

    // role names of the model
    property string titleRole: "title"
    property string subtitleRole: ""
    property string thumbRole: ""
    property string progressRole: ""
    property string newRole: ""
    property string mrlRole: ""

    // draw the rows with the primary text color (playlists) instead of the dimmed one
    property bool rowsBright: false

    // icon of rows without thumbnail, or the role holding the icon name of each row
    property string placeholderIcon: "folder"
    property string iconRole: ""

    // rows drawn before the items: [{text, icon, action}] ("Add", "Create playlist", ...)
    property var leadingActions: []

    // context menu (MLContextMenu); popup(indexes, globalPos)
    property var contextMenu: null

    // media url of the item that is playing
    readonly property string currentUrl: Player.url ? Player.url.toString() : ""

    // label shown when the list is empty
    property string emptyText: qsTr("Nothing here yet")
    property string emptyIllustration: "library"

    signal activated(int index, var row)

    // Settings

    readonly property bool _grid: viewOptions && (nav ? nav.gridView : false)

    itemCount: root.model ? (root.model.count ?? root.model.rowCount?.() ?? -1) : -1

    function _row(index, delegateModel) {
        return {
            "index": index,
            "id": delegateModel.id,
            "type": delegateModel.type,
            "tree": delegateModel.tree,
            "mrl": delegateModel.mrl,
            "name": delegateModel.name,
            "title": delegateModel[root.titleRole],
            "sd_source": delegateModel.sd_source
        }
    }

    function _popupContext(index, pos) {
        if (root.contextMenu && root.model)
            root.contextMenu.popup([root.model.index(index, 0)], pos)
        else
            root.popupMore(pos)
    }

    function setCurrentItemFocus(reason) {
        loader.forceActiveFocus(reason)
    }

    Loader {
        id: loader

        parent: root.contentArea
        anchors.fill: parent

        focus: true

        sourceComponent: root._grid ? gridComponent : listComponent

        Navigation.parentItem: root.contentArea
    }

    // empty state
    Widgets.EmptyState {
        parent: root.contentArea
        anchors.horizontalCenter: parent.horizontalCenter
        y: VLCStyle.dp(40, VLCStyle.scale) + (root.leadingActions.length * VLCStyle.dp(42, VLCStyle.scale))
        width: Math.min(parent.width, VLCStyle.dp(240, VLCStyle.scale))
        height: implicitHeight

        compact: true
        enabled: false
        visible: root.itemCount === 0 && !root._grid

        illustration: root.emptyIllustration
        title: root.emptyText
    }

    Component {
        id: listComponent

        ListView {
            id: list

            focus: true
            clip: true

            model: root.model

            keyNavigationEnabled: false
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            T.ScrollBar.vertical: Widgets.ScrollBarExt {}

            Navigation.parentItem: root.contentArea
            Navigation.upAction: function() {
                if (list.currentIndex > 0)
                    list.currentIndex--
                else
                    root.Navigation.upItem?.forceActiveFocus(Qt.BacktabFocusReason)
            }
            Navigation.downAction: function() {
                if (list.currentIndex < list.count - 1)
                    list.currentIndex++
            }
            Navigation.leftAction: function() { root.nav?.goBack() }

            onActiveFocusChanged: {
                if (activeFocus && currentIndex < 0 && count > 0)
                    currentIndex = 0
            }

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event) && currentItem) {
                    event.accepted = true
                    currentItem.clicked()
                } else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) {
                    event.accepted = true
                    root.nav?.goBack()
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            // leading action rows ("Add", "Create playlist", ...)
            header: Column {
                width: list.width

                Repeater {
                    model: root.leadingActions

                    delegate: SidebarRow {
                        required property var modelData

                        width: list.width

                        title: modelData.text
                        iconName: modelData.icon
                        actionRow: true
                        newKnown: false

                        onClicked: modelData.action()
                    }
                }
            }

            delegate: SidebarRow {
                id: row

                required property int index
                required property var model

                width: list.width

                readonly property string _mrl: root.mrlRole !== "" ? (model[root.mrlRole] ?? "") : ""

                title: model[root.titleRole] ?? ""
                subtitle: root.subtitleRole !== "" ? (model[root.subtitleRole] ?? "") : ""
                thumbnail: root.thumbRole !== "" ? ((model[root.thumbRole] ?? "").toString()) : ""
                iconName: (root.iconRole !== "" ? model[root.iconRole] : "") || root.placeholderIcon
                progress: root.progressRole !== "" ? (model[root.progressRole] ?? -1) : -1
                isNew: root.newRole !== "" ? (model[root.newRole] ?? true) : true
                newKnown: root.newRole !== "" || root.rowsBright
                mrl: _mrl.toString()
                current: _mrl !== "" && _mrl.toString() === root.currentUrl

                highlighted: ListView.isCurrentItem && list.activeFocus

                onClicked: {
                    list.currentIndex = index
                    root.activated(index, root._row(index, model))
                }
                onContextMenuRequested: (pos) => root._popupContext(index, pos)
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_short }
            }
        }
    }

    Component {
        id: gridComponent

        GridView {
            id: grid

            readonly property int columns: 3
            readonly property real spacing: VLCStyle.spacing_10

            focus: true
            clip: true

            model: root.model

            cellWidth: Math.floor(width / columns)
            cellHeight: cellWidth + VLCStyle.dp(30, VLCStyle.scale)
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt {}

            Navigation.parentItem: root.contentArea
            Navigation.leftAction: function() { root.nav?.goBack() }

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event) && currentItem) {
                    event.accepted = true
                    currentItem.clicked()
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            delegate: T.ItemDelegate {
                id: tile

                required property int index
                required property var model

                readonly property string _mrl: root.mrlRole !== "" ? (model[root.mrlRole] ?? "").toString() : ""

                width: grid.cellWidth
                height: grid.cellHeight

                padding: grid.spacing / 2
                hoverEnabled: true

                ColorContext {
                    id: tileTheme
                    colorSet: ColorContext.Item
                    hovered: tile.hovered
                    pressed: tile.down
                }

                ColorContext {
                    id: paneTheme
                    colorSet: ColorContext.Pane
                }

                background: Rectangle {
                    radius: VLCStyle.radius_m
                    color: (tile.hovered || tile.down) ? tileTheme.bg.primary : "transparent"
                }

                contentItem: Column {
                    spacing: VLCStyle.spacing_4

                    Item {
                        width: parent.width
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: VLCStyle.radius_xxs
                            color: tileTheme.bg.secondary
                        }

                        Image {
                            anchors.fill: parent
                            visible: source != "" && status === Image.Ready
                            source: root.thumbRole !== "" ? ((model[root.thumbRole] ?? "").toString()) : ""
                            sourceSize: Qt.size(width * 2, height * 2)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Widgets.SvgIcon {
                            anchors.centerIn: parent
                            visible: root.thumbRole === "" || !(model[root.thumbRole] ?? "").toString()
                            name: root.placeholderIcon
                            color: paneTheme.fg.primary
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            visible: root.progressRole !== "" && (model[root.progressRole] ?? 0) > 0
                            width: parent.width * Math.min(model[root.progressRole] ?? 0, 1)
                            height: VLCStyle.dp(3, VLCStyle.scale)
                            color: paneTheme.accent
                        }
                    }

                    Text {
                        width: parent.width
                        text: model[root.titleRole] ?? ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: (root.newRole !== "" && model[root.newRole] === false) ? paneTheme.fg.secondary
                                                                                         : paneTheme.fg.primary
                        font.pixelSize: VLCStyle.text_caption
                    }
                }

                onClicked: {
                    grid.currentIndex = index
                    root.activated(index, root._row(index, model))
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: (eventPoint) => root._popupContext(index, eventPoint.globalPosition)
                }
            }
        }
    }
}
