/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

// Player top bar: the slim 40px title bar (Figma 247:447), optionally preceded by
// the classic menu bar (qt-menubar), plus the resume dialog.
FocusScope {
    id: root

    // Properties

    // Kept for source compatibility (the title is now centred on the window)
    property int textWidth: width

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    readonly property int reservedHeight: topMargin + (menubar.visible ? menubar.implicitHeight : 0) + titleBar.implicitHeight

    property int topMargin: 0
    property int sideMargin: 0

    property string title

    property bool showCSD: false
    property bool showToolbar: false
    property bool pinControls: false

    property bool sidebarVisible: false

    // opacity of the bar background (the video may be shown through it in fullscreen)
    property real backgroundOpacity: 1.0

    // music player: translucent bar over the cover backdrop
    property bool frosted: false

    // switches when macOS announces the transition, like the player layout (see Player.qml)
    readonly property bool fullscreen: MainCtx.fullScreenLayout

    // label of the breadcrumb link: the folder of the playing media
    readonly property string breadcrumb: {
        const url = Player.url
        if (!url || url.toString() === "")
            return qsTr("Library")

        let str = url.toString()
        try {
            str = decodeURIComponent(str)
        } catch (e) {
        }

        // drop query and fragment
        str = str.split("?")[0].split("#")[0]

        const parts = str.split("/").filter(part => part.length > 0)
        if (parts.length >= 2)
            return parts[parts.length - 2]

        return qsTr("Library")
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Aliases

    property bool playlistVisible: false

    // Signals

    signal sidebarToggleRequested()
    signal requestLockUnlockAutoHide(bool lock)
    signal backRequested()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitHeight: reservedHeight

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player topbar")
    AccessibleCompat.id: "playerTopBar"

    onForceUnlock: titleBar.forceUnlock()

    // Children

    // Reserved area for the application safe area / extended frame
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.topMargin

        visible: height > 0
        color: root.frosted ? Qt.alpha(theme.bg.primary, theme.palette.isDark ? 0.30 : 0.42)
                            : theme.bg.primary
        opacity: root.backgroundOpacity
    }

    Menus.Menubar {
        id: menubar

        anchors.top: parent.top
        anchors.topMargin: root.topMargin
        anchors.left: parent.left
        anchors.leftMargin: root.sideMargin
        anchors.right: parent.right

        visible: root.showToolbar
        enabled: root.showToolbar

        onHoveredChanged: menu => root.requestLockUnlockAutoHide(hovered)
        onMenuOpenedChanged: menu => root.requestLockUnlockAutoHide(menuOpened)
    }

    Widgets.SlimTitleBar {
        id: titleBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: menubar.visible ? menubar.bottom : parent.top
        anchors.topMargin: menubar.visible ? 0 : root.topMargin

        focus: true

        title: root.title

        breadcrumb: root.breadcrumb
        sidebarVisible: root.sidebarVisible

        showCSD: root.showCSD || (MainCtx.clientSideDecoration && root.fullscreen)
        fullscreen: root.fullscreen

        backgroundOpacity: root.backgroundOpacity
        frosted: root.frosted

        Navigation.parentItem: root

        onSidebarToggleRequested: root.sidebarToggleRequested()
        onBreadcrumbClicked: root.backRequested()
        onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
    }
}
