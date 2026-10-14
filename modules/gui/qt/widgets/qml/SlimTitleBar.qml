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
import VLC.Menus as Menus

// Slim 40px title bar of the redesigned player window (Figma 247:447).
//
//  [cone][...][sidebar] | [folder  breadcrumb]      title      [_][□][⛶][x]
//
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

    // when true the window buttons are drawn on the left (macOS convention),
    // default follows the Figma design (right)
    property bool buttonsOnLeft: false

    // draw the background (the player turns it off while overlaying video)
    property bool showBackground: true

    property alias backgroundOpacity: background.opacity

    readonly property real leftClusterWidth: leftCluster.width
    readonly property real rightClusterWidth: rightCluster.width

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property ColorContext toolColorContext: ColorContext {
        id: toolTheme
        colorSet: ColorContext.ToolButton
    }

    readonly property ColorContext viewColorContext: ColorContext {
        id: viewTheme
        colorSet: ColorContext.View
    }

    readonly property ColorContext itemColorContext: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
        hovered: breadcrumbButton.hovered
        pressed: breadcrumbButton.down
    }

    // Signals

    signal sidebarToggleRequested()
    signal breadcrumbClicked()
    signal requestLockUnlockAutoHide(bool lock)

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitHeight: VLCStyle.titleBar_height
    implicitWidth: leftCluster.implicitWidth + rightCluster.implicitWidth + VLCStyle.spacing_12 * 2

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Title bar")

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)

    onForceUnlock: contextMenu.close()

    // Children

    Rectangle {
        id: background

        anchors.fill: parent

        visible: root.showBackground

        color: theme.bg.primary
    }

    // drag and double click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD && !root.fullscreen
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    // Left cluster: cone, menu, sidebar toggle, divider, breadcrumb
    Row {
        id: leftCluster

        // window buttons on the left (macOS convention) push the cluster right
        x: (root.buttonsOnLeft && root.showCSD) ? (windowButtonsLeft.width + VLCStyle.spacing_6)
                                                 : VLCStyle.spacing_6
        anchors.verticalCenter: parent.verticalCenter

        height: VLCStyle.windowButton_h

        spacing: 0

        // cone: 38x28 box (padding 7/2), 24px icon
        Item {
            width: VLCStyle.dp(38, VLCStyle.scale)
            height: VLCStyle.windowButton_h

            Widgets.SvgIcon {
                anchors.centerIn: parent
                name: "vlc"
                size: VLCStyle.icon_normal
                accentColor: theme.accent
            }
        }

        // 7px gap between the cone and the button group
        Item { width: VLCStyle.dp(7, VLCStyle.scale); height: 1 }

        Widgets.IconToolButton {
            id: moreButton

            width: VLCStyle.windowButton_h
            height: VLCStyle.windowButton_h

            focus: true

            iconName: "more"
            text: VLCIcons.more
            description: qsTr("Menu")

            AccessibleCompat.id: "topBarMenuButton"

            checked: contextMenu.shown
            Navigation.parentItem: root
            Navigation.rightItem: sidebarButton

            onClicked: contextMenu.popup(this.mapToGlobal(0, height))

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

            Menus.QmlGlobalMenu {
                id: contextMenu

                ctx: MainCtx

                onAboutToShow: root.requestLockUnlockAutoHide(true)
                onAboutToHide: root.requestLockUnlockAutoHide(false)
            }
        }

        // 10px gap
        Item { width: VLCStyle.spacing_10; height: 1 }

        Widgets.IconToolButton {
            id: sidebarButton

            width: VLCStyle.windowButton_h
            height: VLCStyle.windowButton_h

            iconName: "sidebar-left"
            text: VLCIcons.menu
            iconNameChecked: "sidebar-active"
            checkable: true
            checked: root.sidebarVisible
            description: root.sidebarVisible ? qsTr("Hide sidebar") : qsTr("Show sidebar")

            AccessibleCompat.id: "topBarSidebarButton"

            Navigation.parentItem: root
            Navigation.leftItem: moreButton
            Navigation.rightItem: breadcrumbButton

            // the state is owned by the parent
            onToggled: root.sidebarToggleRequested()
            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }

        // divider: 24 wide cell, 1.5px hairline
        Item {
            width: VLCStyle.dp(24, VLCStyle.scale)
            height: VLCStyle.windowButton_h

            Rectangle {
                anchors.centerIn: parent
                width: VLCStyle.dp(1.5, VLCStyle.scale)
                height: VLCStyle.dp(18, VLCStyle.scale)
                radius: width / 2
                color: viewTheme.border
            }
        }

        // breadcrumb link: folder icon + label, radius 6
        T.Button {
            id: breadcrumbButton

            height: VLCStyle.windowButton_h
            implicitWidth: VLCStyle.windowButton_h + VLCStyle.spacing_4 + crumbLabel.width + rightPadding
            width: implicitWidth

            visible: root.breadcrumb !== ""

            padding: 0
            rightPadding: VLCStyle.spacing_4
            hoverEnabled: true

            Accessible.name: qsTr("Back to %1").arg(root.breadcrumb)
            AccessibleCompat.id: "topBarBreadcrumb"

            T.ToolTip.visible: (hovered || visualFocus)
            T.ToolTip.delay: VLCStyle.delayToolTipAppear
            T.ToolTip.text: qsTr("Back to %1").arg(root.breadcrumb)

            Navigation.parentItem: root
            Navigation.leftItem: sidebarButton

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event)) {
                    event.accepted = true
                    breadcrumbButton.clicked()
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            onClicked: root.breadcrumbClicked()

            background: Widgets.AnimatedBackground {
                radius: VLCStyle.radius_m
                enabled: toolTheme.initialized

                color: (breadcrumbButton.hovered || breadcrumbButton.down) ? itemTheme.bg.primary
                                                                           : "transparent"

                border.color: breadcrumbButton.visualFocus ? toolTheme.visualFocus : "transparent"
            }

            contentItem: Row {
                spacing: VLCStyle.spacing_4

                // folder icon cell: 28x28, 24px glyph
                Item {
                    width: VLCStyle.windowButton_h
                    height: VLCStyle.windowButton_h

                    Widgets.SvgIcon {
                        anchors.centerIn: parent
                        name: "folder"
                        size: VLCStyle.icon_normal
                        color: toolTheme.fg.primary
                    }
                }

                Text {
                    id: crumbLabel

                    height: VLCStyle.windowButton_h
                    // stay clear of the centred title
                    width: Math.min(implicitWidth, Math.max(VLCStyle.dp(40, VLCStyle.scale),
                                                            root.width / 2 - VLCStyle.dp(80, VLCStyle.scale)
                                                            - leftCluster.x - breadcrumbButton.x
                                                            - VLCStyle.windowButton_h - VLCStyle.spacing_8))

                    text: root.breadcrumb
                    color: toolTheme.fg.primary
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Centre title: centred on the window, kept clear of both clusters
    Text {
        id: titleText

        readonly property real _leftLimit: leftCluster.x + leftCluster.width + VLCStyle.spacing_16
        readonly property real _rightLimit: (rightCluster.active ? rightCluster.x
                                             : (fullscreenToggle.visible ? fullscreenToggle.x : root.width)) - VLCStyle.spacing_16
        readonly property real _available: Math.max(0, _rightLimit - _leftLimit)

        width: Math.min(implicitWidth, _available)
        height: parent.height

        x: Helpers.clamp((root.width - width) / 2, _leftLimit, Math.max(_leftLimit, _rightLimit - width))

        text: root.title
        color: toolTheme.fg.primary
        font.pixelSize: VLCStyle.text_body
        font.weight: VLCStyle.fontWeight_regular
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Accessible.role: Accessible.Heading
        Accessible.name: text
    }

    // Window buttons, right (Figma) ...
    Loader {
        id: rightCluster

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.spacing_6
        anchors.verticalCenter: parent.verticalCenter

        height: VLCStyle.windowButton_h

        active: root.showCSD && !root.buttonsOnLeft
        visible: active

        sourceComponent: buttonsComponent
    }

    // ... or left (macOS convention, optional)
    Loader {
        id: windowButtonsLeft

        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.spacing_6
        anchors.verticalCenter: parent.verticalCenter

        height: VLCStyle.windowButton_h

        active: root.showCSD && root.buttonsOnLeft
        visible: active

        sourceComponent: buttonsComponent
    }

    Component {
        id: buttonsComponent

        CSDWindowButtonSet {
            height: VLCStyle.windowButton_h

            fullscreenOnly: root.fullscreen

            onButtonHoveredChanged: root.requestLockUnlockAutoHide(buttonHovered)
        }
    }

    // fullscreen without CSD: nothing but a fullscreen toggle on the right
    CSDWindowButtonSet {
        id: fullscreenToggle

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.spacing_6
        anchors.verticalCenter: parent.verticalCenter

        height: VLCStyle.windowButton_h

        visible: !root.showCSD && root.fullscreen
        fullscreenOnly: true

        onButtonHoveredChanged: root.requestLockUnlockAutoHide(buttonHovered)
    }
}
