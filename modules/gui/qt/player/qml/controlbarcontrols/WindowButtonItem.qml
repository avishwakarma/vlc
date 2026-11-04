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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Base of the minimize / maximize / close items of the title bar (client side decoration)
Widgets.CSDWindowButton {
    id: root

    // CSDButton.Minimize, CSDButton.MaximizeRestore or CSDButton.Close
    property int buttonType: CSDButton.Close

    property bool paintOnly: false

    signal requestLockUnlockAutoHide(bool lock)

    readonly property bool keepSize: true

    // the real button of the window (hit test rectangle, window actions)
    readonly property var _csd: {
        const buttons = MainCtx.csdButtonModel.windowCSDButtons
        for (let i = 0; i < buttons.length; ++i) {
            if (buttons[i].type === root.buttonType)
                return buttons[i]
        }
        return null
    }

    // only drawn with client side decoration and when the window is not fullscreen
    readonly property bool hostHidden: !PlayerHost.showCSD || PlayerHost.windowFullscreen || MainCtx.nativeTrafficLights

    readonly property ColorContext toolColorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton
    }

    readonly property ColorContext itemColorContext: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
        hovered: true
    }

    readonly property bool _isClose: (buttonType === CSDButton.Close)

    enabled: !paintOnly

    color: theme.fg.primary
    hoverColor: _isClose ? VLCStyle.windowButton_closeHover : itemTheme.bg.primary
    hoverIconColor: _isClose ? theme.fg.primary : theme.fg.primary

    showHovered: _csd ? _csd.showHovered : false
    externalPressed: _csd ? _csd.externalPressed : false

    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

    onClicked: {
        if (_csd)
            _csd.click()
    }

    // handles VLCStyle.scale changes
    onWidthChanged: Qt.callLater(updateRect)
    onHeightChanged: Qt.callLater(updateRect)
    onXChanged: Qt.callLater(updateRect)
    onYChanged: Qt.callLater(updateRect)
    onVisibleChanged: Qt.callLater(updateRect)

    Connections {
        target: VLCStyle

        // handle window resize
        function onAppWidthChanged() { Qt.callLater(root.updateRect) }
        function onAppHeightChanged() { Qt.callLater(root.updateRect) }
    }

    function updateRect() {
        if (!_csd || paintOnly)
            return

        const point = mapToItem(null, 0, 0)
        _csd.rect = Qt.rect(point.x, point.y, width, height)
    }
}
