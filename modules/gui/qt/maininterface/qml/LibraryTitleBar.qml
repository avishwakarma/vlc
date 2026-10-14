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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.PlayerControls

// Title bar of the library window (Figma 970:2703): 40 px, the cone and the main menu button on
// the left, the title centred and the window buttons on the right. With client side decoration
// it is the window drag area.
FocusScope {
    id: root

    property string title: ""

    property bool showCSD: false

    readonly property bool fullscreen: (MainCtx.intfMainWindow.visibility === Window.FullScreen)

    implicitHeight: VLCStyle.titleBar_height
    implicitWidth: cone.width + menuButton.width + VLCStyle.spacing_12 * 2

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Title bar")

    Rectangle {
        anchors.fill: parent
        color: theme.bg.primary
    }

    // drag and double click the title bar in client side decoration mode
    Loader {
        anchors.fill: parent
        active: root.showCSD && !root.fullscreen
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"
    }

    // cone: 38x28 box, 24px icon
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

    TitleMenuButton {
        id: menuButton

        x: cone.x + cone.width + VLCStyle.dp(7, VLCStyle.scale)
        anchors.verticalCenter: parent.verticalCenter

        focus: true

        Navigation.parentItem: root
    }

    Text {
        id: titleText

        // room left free by the buttons on both sides, the title stays centred on the window
        readonly property real _left: menuButton.x + menuButton.width + VLCStyle.spacing_16
        readonly property real _right: (windowButtons.active ? windowButtons.x : root.width) - VLCStyle.spacing_16
        readonly property real _half: Math.min(root.width / 2 - _left, _right - root.width / 2)

        height: parent.height
        width: Math.min(implicitWidth, Math.max(0, 2 * _half))
        x: (root.width - width) / 2

        text: root.title
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        color: theme.fg.primary
        font.pixelSize: VLCStyle.text_body
        font.weight: VLCStyle.fontWeight_regular

        Accessible.role: Accessible.Heading
        Accessible.name: text
    }

    Loader {
        id: windowButtons

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.spacing_6
        anchors.verticalCenter: parent.verticalCenter

        height: VLCStyle.windowButton_h

        active: root.showCSD
        visible: active

        sourceComponent: Widgets.CSDWindowButtonSet {
            height: VLCStyle.windowButton_h

            fullscreenOnly: root.fullscreen
        }
    }
}
