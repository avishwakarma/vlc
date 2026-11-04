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
import VLC.Dialogs
import VLC.Menus as Menus
import VLC.Widgets as Widgets
import VLC.Util

// Icon rail of the library sidebar (Figma 848:1995): 50 px wide, Pane secondary surface,
// 34x34 icon buttons every 46 px. The current library section uses the "-active" icon.
FocusScope {
    id: root

    // key of the current section
    property string currentKey: "home"

    readonly property var entries: [
        { key: "home", icon: "home", activeIcon: "home-active", text: qsTr("Home") },
        { key: "videos", icon: "videos", activeIcon: "videos-active", text: qsTr("Videos") },
        { key: "music", icon: "songs", activeIcon: "songs-active", text: qsTr("Music") },
        { key: "network", icon: "streaming", activeIcon: "streaming-active", text: qsTr("Network") },
        { key: "playlists", icon: "playlist", activeIcon: "playlist-active", text: qsTr("Playlists") },
        { key: "recent", icon: "recent", activeIcon: "recent", text: qsTr("Recent") },
        { key: "add", icon: "add", activeIcon: "add", text: qsTr("Add Item"), action: true }
    ]

    // pinned to the bottom of the rail
    readonly property var bottomEntries: [
        { key: "settings", icon: "settings", activeIcon: "settings", text: qsTr("Settings"), action: true, bottom: true },
        { key: "more", icon: "more", activeIcon: "more", text: qsTr("More"), action: true, bottom: true }
    ]

    signal sectionRequested(string key)
    signal addRequested()

    implicitWidth: VLCStyle.sidebarRail_w

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("Library sections")

    Rectangle {
        anchors.fill: parent
        color: theme.bg.secondary
    }

    // the entries scroll when the window is too short to show them above the bottom group
    Flickable {
        anchors.top: parent.top
        anchors.bottom: bottomGroup.top
        anchors.left: parent.left
        anchors.right: parent.right

        clip: true
        contentWidth: width
        contentHeight: column.height + column.y
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

    Column {
        id: column

        y: VLCStyle.spacing_8 - VLCStyle.dp(1, VLCStyle.scale)
        anchors.horizontalCenter: parent.horizontalCenter

        spacing: VLCStyle.dp(12, VLCStyle.scale)

        focus: true

        Repeater {
            id: repeater

            model: root.entries

            delegate: T.AbstractButton {
                id: button

                required property int index
                required property var modelData

                readonly property bool isCurrent: !modelData.action && modelData.key === root.currentKey

                width: VLCStyle.dp(34, VLCStyle.scale)
                height: VLCStyle.dp(34, VLCStyle.scale)

                focus: index === 0
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus

                text: modelData.text

                Accessible.name: modelData.text
                Accessible.role: Accessible.PageTab
                Accessible.checked: isCurrent

                T.ToolTip.visible: hovered || visualFocus
                T.ToolTip.delay: VLCStyle.delayToolTipAppear
                T.ToolTip.text: modelData.text

                Navigation.parentItem: root
                readonly property Repeater group: modelData.bottom ? bottomRepeater : repeater

                Navigation.upItem: index > 0 ? group.itemAt(index - 1)
                                             : (modelData.bottom ? repeater.itemAt(repeater.count - 1) : null)
                Navigation.downItem: index < group.count - 1 ? group.itemAt(index + 1)
                                                            : (modelData.bottom ? null : bottomRepeater.itemAt(0))

                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => {
                    if (KeyHelper.matchOk(event)) {
                        event.accepted = true
                        button.clicked()
                    } else {
                        Navigation.defaultKeyAction(event)
                    }
                }

                onClicked: {
                    if (modelData.key === "settings")
                        DialogsProvider.prefsDialog()
                    else if (modelData.key === "more")
                        mainMenu.popup(button.mapToGlobal(button.width, 0))
                    else if (modelData.action)
                        root.addRequested()
                    else
                        root.sectionRequested(modelData.key)
                }

                ColorContext {
                    id: itemTheme
                    colorSet: ColorContext.Item

                    hovered: button.hovered
                    pressed: button.down
                    focused: button.visualFocus
                }

                background: Rectangle {
                    radius: VLCStyle.radius_m

                    color: (button.hovered || button.down) ? itemTheme.bg.primary : "transparent"

                    border.width: button.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                    border.color: itemTheme.visualFocus

                    Behavior on color {
                        ColorAnimation { duration: VLCStyle.duration_short }
                    }
                }

                contentItem: Item {
                    Widgets.SvgIcon {
                        anchors.centerIn: parent

                        name: button.isCurrent ? button.modelData.activeIcon : button.modelData.icon
                        size: VLCStyle.icon_normal
                        color: (button.hovered || button.visualFocus) ? theme.fg.highlight : theme.fg.primary
                        accentColor: theme.accent
                    }
                }
            }
        }
    }

    }

    Column {
        id: bottomGroup

        anchors.bottom: parent.bottom
        anchors.bottomMargin: VLCStyle.spacing_8
        anchors.horizontalCenter: parent.horizontalCenter

        spacing: column.spacing

        Repeater {
            id: bottomRepeater

            model: root.bottomEntries
            delegate: repeater.delegate
        }
    }

    // the main menu of the title bar ("...")
    Menus.QmlGlobalMenu {
        id: mainMenu

        ctx: MainCtx
    }
}
