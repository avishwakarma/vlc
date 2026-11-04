/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: fullScreenBtn

    // set by the control row: the item is drawn like the window buttons in the title bar
    property bool inTitleBar: false

    readonly property bool keepSize: inTitleBar

    // in the title bar of a window decorated by the system the toggle is not needed (except to leave fullscreen)
    readonly property bool hostHidden: inTitleBar && (!PlayerHost.showCSD || MainCtx.nativeTrafficLights) && !PlayerHost.windowFullscreen

    implicitWidth: inTitleBar ? VLCStyle.windowButton_w : Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                                                    implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: inTitleBar ? VLCStyle.windowButton_h : Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                                                     implicitContentHeight + topPadding + bottomPadding)

    radius: inTitleBar ? VLCStyle.radius_m : VLCStyle.button_radius

    // hidden when the window is not decorated by us in fullscreen? no: it is the way out of fullscreen
    readonly property bool _fullscreen: Player.hasVideoOutput ? Player.fullscreen : PlayerHost.windowFullscreen

    enabled: !paintOnly
    text: _fullscreen ? VLCIcons.defullscreen : VLCIcons.fullscreen
    iconName: _fullscreen ? "fullscreen-active" : "fullscreen"
    onClicked: {
        if (Player.hasVideoOutput)
            Player.fullscreen = !Player.fullscreen
        else
            MainCtx.toggleInterfaceFullScreen()
    }
    description: qsTr("Fullscreen")

    T.ToolTip.text: PlayerAux.tip(description, "toggle-fullscreen")

    AccessibleCompat.id: "fullscreenButton"
}
