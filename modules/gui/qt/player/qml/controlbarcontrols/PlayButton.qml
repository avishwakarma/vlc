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
import VLC.Playlist
import VLC.Util

// Accent play/pause pill of the control bar (Figma 848:1711): 54x28, radius 6,
// accent fill (ButtonAccent colour set), 24px glyph in FG/B1.
T.Control {
    id: root

    // Properties

    property bool paintOnly: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.ButtonAccent

        enabled: root.enabled || root.paintOnly
        focused: root.activeFocus
        hovered: root.cursorInside
        pressed: mouseArea.containsPress || root._keyOkPressed
    }

    property bool _keyOkPressed: false

    // Aliases

    property alias cursorInside: mouseArea.containsMouse

    // Settings

    implicitWidth: VLCStyle.playButton_w
    implicitHeight: VLCStyle.playButton_h

    scale: (_keyOkPressed || (mouseArea.pressed && cursorInside)) ? 0.96
                                                                  : 1.00

    Behavior on scale {
        NumberAnimation {
            duration: VLCStyle.duration_veryShort
            easing.type: Easing.OutSine
        }
    }

    readonly property bool _playing: {
        const state = Player.playingState

        return !paintOnly
                && state !== Player.PLAYING_STATE_PAUSED
                && state !== Player.PLAYING_STATE_STOPPED
    }

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Play/Pause")
    AccessibleCompat.id: "playButton"
    Accessible.checkable: true
    Accessible.checked: Player.playingState !== Player.PLAYING_STATE_PAUSED
                        && Player.playingState !== Player.PLAYING_STATE_STOPPED
    Accessible.onPressAction: MainPlaylistController.togglePlayPause()
    Accessible.onToggleAction: MainPlaylistController.togglePlayPause()

    // Tooltip

    T.ToolTip.visible: (cursorInside || visualFocus)
    T.ToolTip.delay: VLCStyle.delayToolTipAppear
    T.ToolTip.text: PlayerAux.tip(root.Accessible.name, "play-pause")

    // Keys

    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event) ) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = true
                keyHoldTimer.restart()
            }
            event.accepted = true
        }
        Navigation.defaultKeyAction(event)
    }

    Keys.onReleased: (event) => {
        if (KeyHelper.matchOk(event)) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = false
                keyHoldTimer.stop()
                if (Player.playingState !== Player.PLAYING_STATE_STOPPED)
                    MainPlaylistController.togglePlayPause()
            }
            event.accepted = true
        }
    }

    // Functions

    function _pressAndHoldAction() {
        _keyOkPressed = false
        MainPlaylistController.stop()
    }

    // Children

    Timer {
        id: keyHoldTimer

        interval: mouseArea.pressAndHoldInterval
        repeat: false

        Component.onCompleted: {
            triggered.connect(_pressAndHoldAction)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent

        hoverEnabled: true

        onPressed: (mouse) => {
            root.forceActiveFocus(Qt.MouseFocusReason)
        }

        onClicked: (mouse) => {
            MainPlaylistController.togglePlayPause()
            mouse.accepted = true
        }

        onPressAndHold: (mouse) => {
            _pressAndHoldAction()
            mouse.accepted = true
        }
    }

    contentItem: Item {
        Widgets.SvgIcon {
            anchors.centerIn: parent

            name: root._playing ? "pause" : "play"
            size: VLCStyle.icon_normal

            // glyph colour of the accent button set (FG/B1)
            color: theme.fg.primary
            accentColor: theme.fg.primary

            Behavior on color {
                enabled: theme.initialized
                ColorAnimation {
                    duration: VLCStyle.duration_veryShort
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    background: Item {
        implicitWidth: VLCStyle.playButton_w
        implicitHeight: VLCStyle.playButton_h

        // focus ring
        Widgets.AnimatedBackground {
            anchors.fill: parent
            anchors.margins: -VLCStyle.focus_border * 2

            radius: VLCStyle.radius_m + VLCStyle.focus_border * 2
            border.pixelAligned: false

            enabled: theme.initialized

            border.color: root.visualFocus ? theme.visualFocus : Qt.alpha(theme.visualFocus, 0.0)
        }

        Rectangle {
            anchors.fill: parent

            radius: VLCStyle.radius_m

            color: theme.bg.primary

            Behavior on color {
                enabled: theme.initialized
                ColorAnimation {
                    duration: VLCStyle.duration_veryShort
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
