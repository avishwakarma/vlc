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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

// Slim 40px title bar of the redesigned player window (Figma 247:447).
//
//  [cone][...][sidebar] | [folder  breadcrumb]      title      [_][□][⛶][x]
//
// The items after the cone are the ones of the "Topbar" model of the current control bar
// profile (see PlayerControlbarModel) and can be moved around in the customize mode.
// With client side decoration it also acts as the window drag area.
FocusScope {
    id: root

    // Properties

    property string title: ""

    // label of the breadcrumb link (folder of the playing media / library location)
    property string breadcrumb: ""

    // state of the sidebar toggle
    property bool sidebarVisible: false

    // draw window buttons and handle window dragging
    property bool showCSD: false

    // true when the window is fullscreen: only the fullscreen toggle is kept
    property bool fullscreen: false

    // draw the background (the player turns it off while overlaying video)
    property bool showBackground: true

    property alias backgroundOpacity: background.opacity

    // music player: translucent tinted surface over the blurred cover backdrop
    property bool frosted: false

    readonly property var model: {
        const profile = MainCtx.controlbarProfileModel.currentModel
        return profile ? profile.ensureModel(PlayerControlbarModel.Topbar) : null
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Signals

    signal sidebarToggleRequested()
    signal breadcrumbClicked()
    signal requestLockUnlockAutoHide(bool lock)

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitHeight: VLCStyle.titleBar_height
    implicitWidth: row.implicitWidth + VLCStyle.spacing_12

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Title bar")

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)

    onForceUnlock: row.forceUnlock()

    // The items of the bar get their state from here

    Binding { target: PlayerHost; property: "title"; value: root.title }
    Binding { target: PlayerHost; property: "breadcrumb"; value: root.breadcrumb }
    Binding { target: PlayerHost; property: "sidebarVisible"; value: root.sidebarVisible }
    Binding { target: PlayerHost; property: "showCSD"; value: root.showCSD }
    Binding { target: PlayerHost; property: "windowFullscreen"; value: root.fullscreen }

    Connections {
        target: PlayerHost

        function onToggleSidebar() { root.sidebarToggleRequested() }
        function onBreadcrumbClicked() { root.breadcrumbClicked() }
        function onRequestLockUnlockAutoHide(lock) { root.requestLockUnlockAutoHide(lock) }
    }

    // Children

    Rectangle {
        id: background

        anchors.fill: parent

        visible: root.showBackground

        color: root.frosted ? Qt.alpha(theme.bg.primary, theme.palette.isDark ? 0.30 : 0.42)
                            : theme.bg.primary

        Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }

        Rectangle {
            visible: root.frosted

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: VLCStyle.dp(1, VLCStyle.scale)

            color: theme.border
        }
    }

    // drag and double click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD && !root.fullscreen && !PlayerCustomizer.editing
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    // cone: 38x28 box (padding 7/2), 24px icon, then a 7px gap before the items
    Item {
        id: cone

        x: VLCStyle.spacing_6
        anchors.verticalCenter: parent.verticalCenter

        width: VLCStyle.dp(38, VLCStyle.scale)
        height: VLCStyle.windowButton_h

        Widgets.SvgIcon {
            anchors.centerIn: parent
            name: "vlc"
            size: VLCStyle.icon_normal
            accentColor: theme.accent
        }
    }

    BarRow {
        id: row

        x: VLCStyle.spacing_6
        width: parent.width - VLCStyle.spacing_6 * 2
        height: VLCStyle.windowButton_h
        anchors.verticalCenter: parent.verticalCenter

        keyPrefix: "top"
        model: root.model

        leftInset: cone.width + VLCStyle.dp(7, VLCStyle.scale)
        zoneSpacing: VLCStyle.spacing_16

        focus: true

        Navigation.parentItem: root

        onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
    }
}
