/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import VLC.Player
import VLC.Style

// Window buttons of the slim title bar: minimize, maximize/restore, fullscreen, close.
// Order and icons follow the Figma title bar (jf8IwqZrI8Q0bWCTounVPx 247:464).
Row {
    id: windowButtonGroup

    spacing: 0
    padding: 0

    width: implicitWidth

    property color color: theme.fg.primary
    property color hoverColor: itemTheme.bg.primary

    // show a fullscreen toggle between maximize and close
    property bool showFullscreen: true
    // only show the fullscreen toggle (used while the window is fullscreen)
    property bool fullscreenOnly: false

    readonly property bool _isFullscreen: (MainCtx.intfMainWindow.visibility === Window.FullScreen)

    readonly property bool buttonHovered: {
        let h = fullscreenButton.hovered
        for (let i = 0; i < repeater.count; ++i) {
            const button = repeater.itemAt(i)
            h = h || button.hovered || button.showHovered
        }
        for (let i = 0; i < repeaterClose.count; ++i) {
            const button = repeaterClose.itemAt(i)
            h = h || button.hovered || button.showHovered
        }

        return h
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton
    }

    readonly property ColorContext itemColorContext: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
        hovered: true
    }

    function toggleFullscreen() {
        if (Player.hasVideoOutput)
            Player.fullscreen = !Player.fullscreen
        else
            MainCtx.toggleInterfaceFullScreen()
    }

    component WindowButton : CSDWindowButton {
        id: windowButton

        required property var modelData

        // false: minimize/maximize, true: close
        property bool closeButton: false

        readonly property bool _isClose: (modelData.type === CSDButton.Close)

        y: (windowButtonGroup.height - height) / 2

        visible: !windowButtonGroup.fullscreenOnly && (_isClose === closeButton)

        showHovered: modelData.showHovered

        externalPressed: modelData.externalPressed

        color: windowButtonGroup.color
        hoverColor: _isClose ? VLCStyle.windowButton_closeHover
                             : windowButtonGroup.hoverColor
        hoverIconColor: _isClose ? theme.fg.primary
                                 : windowButtonGroup.color

        iconName: {
            switch (modelData.type) {
            case CSDButton.Minimize:
                return "minimize"
            case CSDButton.MaximizeRestore:
                return "maximize"
            case CSDButton.Close:
                return "close"
            }
            return ""
        }

        Accessible.name: {
            switch (modelData.type) {
            case CSDButton.Minimize:
                return qsTr("Minimize")
            case CSDButton.MaximizeRestore:
                return qsTr("Maximize")
            case CSDButton.Close:
                return qsTr("Close")
            }
            return ""
        }

        onClicked: modelData.click()

        // handles VLCStyle.scale changes
        onWidthChanged: Qt.callLater(updateRect)
        onHeightChanged: Qt.callLater(updateRect)
        onYChanged: Qt.callLater(updateRect)
        onVisibleChanged: Qt.callLater(updateRect)

        Connections {
            target: VLCStyle

            // handle window resize
            function onAppWidthChanged() { Qt.callLater(windowButton.updateRect) }
            function onAppHeightChanged() { Qt.callLater(windowButton.updateRect) }
        }

        function updateRect() {
            const point = mapToItem(null, 0, 0)
            const rect = Qt.rect(point.x, point.y, width, height)

            modelData.rect = rect
        }
    }

    Repeater {
        id: repeater

        model: MainCtx.csdButtonModel.windowCSDButtons

        WindowButton {
            closeButton: false
        }
    }

    // Fullscreen toggle sits between maximize and close
    CSDWindowButton {
        id: fullscreenButton

        y: (windowButtonGroup.height - height) / 2

        visible: windowButtonGroup.showFullscreen

        color: windowButtonGroup.color
        hoverColor: windowButtonGroup.hoverColor
        hoverIconColor: windowButtonGroup.color

        iconName: windowButtonGroup._isFullscreen ? "fullscreen-active" : "fullscreen"

        Accessible.name: qsTr("Fullscreen")

        onClicked: windowButtonGroup.toggleFullscreen()
    }

    Repeater {
        id: repeaterClose

        model: MainCtx.csdButtonModel.windowCSDButtons

        WindowButton {
            closeButton: true
        }
    }
}
