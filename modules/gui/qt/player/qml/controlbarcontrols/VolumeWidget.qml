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
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style
import VLC.Player

// Volume control of the player control bar (Figma 491:1731):
// speaker icon + 88x28 wedge. The fill is the green -> yellow -> orange -> red
// volume gradient, revealed from the left according to the volume.
T.Pane {
    id: root

    property bool paintOnly: false

    readonly property var _player: paintOnly ? ({ muted: false, volume: .5 }) : Player
    readonly property int _maxvol: MainCtx.maxVolume
    readonly property real _fullvolpos: 100 / _maxvol
    readonly property real _maxvolpos: _maxvol / 100

    // Figma: 100% is at 63 px of the 86 px wide fill, the remaining range fills the rest
    readonly property real _fullFraction: (_maxvol > 100) ? (63 / 86) : 1.0

    // fraction of the wedge covered for a volume in [0, _maxvolpos]
    function fractionFor(volume: real) : real {
        if (_maxvol <= 100)
            return Helpers.clamp(volume, 0, 1)

        if (volume <= 1.0)
            return Math.max(0, volume) * _fullFraction

        return Math.min(1.0, _fullFraction + (volume - 1.0) / (_maxvolpos - 1.0) * (1.0 - _fullFraction))
    }

    function volumeFor(fraction: real) : real {
        fraction = Helpers.clamp(fraction, 0, 1)

        if (_maxvol <= 100)
            return fraction

        if (fraction <= _fullFraction)
            return fraction / _fullFraction

        return 1.0 + (fraction - _fullFraction) / (1.0 - _fullFraction) * (_maxvolpos - 1.0)
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: 0

    contentWidth: volumeWidget.implicitWidth
    contentHeight: volumeWidget.implicitHeight

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider
    }

    RowLayout {
        id: volumeWidget

        anchors.fill: parent
        spacing: VLCStyle.spacing_8

        Widgets.IconToolButton {
            id: volumeBtn

            focus: true
            paintOnly: root.paintOnly

            Layout.preferredWidth: VLCStyle.icon_normal
            Layout.preferredHeight: VLCStyle.icon_normal
            Layout.alignment: Qt.AlignVCenter

            iconName: {
                if (_player.muted || _player.volume === 0)
                    return "close-none"
                else if (_player.volume < .33)
                    return "close-low"
                else if (_player.volume <= .66)
                    return "close-medium"
                else
                    return "volume-high"
            }

            // glyph text is only needed as a fallback by the base type
            text: description
            description: qsTr("Mute")

            T.ToolTip.text: PlayerAux.tip(description, "vol-mute")

            AccessibleCompat.id: "muteButton"

            onClicked: Player.muted = !Player.muted

            Accessible.onIncreaseAction: {
                Player.muted = false
                Player.setVolumeUp()
            }

            Accessible.onDecreaseAction: {
                Player.muted = false
                Player.setVolumeDown()
            }

            Navigation.parentItem: root
            Navigation.rightItem: volControl
        }

        T.Slider {
            id: volControl

            implicitWidth: VLCStyle.volume_w
            implicitHeight: VLCStyle.seek_height

            Layout.preferredWidth: VLCStyle.volume_w
            Layout.preferredHeight: VLCStyle.seek_height
            Layout.alignment: Qt.AlignVCenter

            padding: 0

            // the slider value is the covered fraction of the wedge, the
            // (non-linear) volume is derived with root.volumeFor()
            from: 0
            to: 1

            property bool _inhibitPlayerVolumeUpdate: false

            // FIXME: Currently we are not updating the ShiftModifier status while dragging. This
            //        could be fixed with a custom Slider based on a MouseArea.
            property bool _shiftPressed: false

            property real _clamp: 0.01

            property bool _keyPressed: false

            property bool filterEvents: false

            // value tooltip is shown on hover, drag, keyboard focus and briefly after a change
            property bool _recentlyChanged: false

            enabled: !root.paintOnly // disables event handling depending on this
            hoverEnabled: true
            activeFocusOnTab: true

            opacity: _player.muted ? 0.5 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: VLCStyle.duration_short
                }
            }

            Accessible.name: qsTr("Volume")
            Accessible.role: Accessible.Slider
            AccessibleCompat.id: "volumeSlider"

            readonly property real fillFraction: volControl.value

            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event)) {
                    event.accepted = true

                    _keyPressed = true
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            Keys.onReleased: (event) => {
                if (_keyPressed === false)
                    return

                _keyPressed = false

                if (KeyHelper.matchOk(event)) {
                    Player.muted = !Player.muted
                }
            }

            function _syncVolumeWithPlayer() {
                volControl._inhibitPlayerVolumeUpdate = true
                volControl.value = root.fractionFor(_player.volume)
                volControl._inhibitPlayerVolumeUpdate = false
            }

            function _adjustPlayerVolume() {
                Player.muted = false

                let value = root.volumeFor(volControl.value)

                // NOTE: We are clamping the value to make it easier to restore the default volume.
                if (_shiftPressed === false) {
                    if (Math.abs(value - 1.0) < _clamp)
                        value = 1.0
                    else
                        _clamp = 0.01
                }

                Player.volume = value

                volControl.value = root.fractionFor(value)
            }

            Component.onCompleted: {
                root.paintOnlyChanged.connect(_syncVolumeWithPlayer)
                volControl._syncVolumeWithPlayer()
            }

            Connections {
                target: Player
                enabled: !paintOnly

                function onVolumeChanged() {
                    volControl._syncVolumeWithPlayer()

                    volControl._recentlyChanged = true
                    changedTimer.restart()
                }
            }

            Timer {
                id: changedTimer

                interval: VLCStyle.duration_humanMoment
                onTriggered: volControl._recentlyChanged = false
            }

            Navigation.leftItem: volumeBtn
            Navigation.parentItem: root

            Keys.onUpPressed: (event) => {
                Player.muted = false
                Player.setVolumeUp()
            }

            Keys.onDownPressed: (event) => {
                Player.muted = false
                Player.setVolumeDown()
            }

            Keys.priority: Keys.BeforeItem

            onValueChanged: {
                if (paintOnly)
                    return

                if (!volControl._inhibitPlayerVolumeUpdate) {
                    if (filterEvents) {
                        Qt.callLater(volControl._adjustPlayerVolume)
                    } else {
                        volControl._adjustPlayerVolume()
                        filterEvents = true
                    }
                }
            }

            handle: Item {
                implicitWidth: 0
                implicitHeight: 0
            }

            background: Item {
                implicitWidth: VLCStyle.volume_w
                implicitHeight: VLCStyle.seek_height

                // Figma wedge geometry, 89 x 27.36 at y=0.3
                readonly property real _s: width / 89

                // track
                Shape {
                    id: track

                    y: 0.3 * parent._s
                    width: 89
                    height: 27.36

                    scale: parent._s
                    transformOrigin: Item.TopLeft

                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: theme.bg.primary

                        PathSvg {
                            path: "M3.598 19.045C1.555 18.839 0 17.119 0 15.066V12.298C0 10.244 1.555 8.524 3.598 8.318L85.698 0.016C87.465-0.163 89 1.224 89 3V24.363C89 26.139 87.465 27.526 85.698 27.348L3.598 19.045Z"
                        }
                    }
                }

                // fill, revealed up to fillFraction of the 86 px wide wedge
                Item {
                    id: fillClip

                    x: 1.5 * parent._s
                    y: 1.7 * parent._s

                    width: 86 * parent._s * volControl.fillFraction
                    height: 24.56 * parent._s

                    clip: true

                    Behavior on width {
                        enabled: !volControl.pressed
                        NumberAnimation {
                            duration: VLCStyle.duration_short
                            easing.type: Easing.OutSine
                        }
                    }

                    Shape {
                        width: 86
                        height: 24.56

                        scale: parent.parent._s
                        transformOrigin: Item.TopLeft

                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: "transparent"

                            fillGradient: LinearGradient {
                                x1: -2.5; y1: 0
                                x2: 87.5; y2: 0

                                // accent up to 100 %, towards "negative" only in the over-amplified range
                                GradientStop { position: 0.0; color: theme.accent }
                                GradientStop { position: root._fullFraction * 0.97; color: theme.accent }
                                GradientStop { position: 1.0; color: root._maxvol > 100 ? theme.fg.negative : theme.accent }
                            }

                            PathSvg {
                                path: "M1.792 15.968C0.773 15.861 0 15.002 0 13.978V10.582C0 9.558 0.773 8.699 1.792 8.592L83.792 0.011C84.972-0.112 86 0.813 86 2V22.56C86 23.747 84.972 24.672 83.792 24.549L1.792 15.968Z"
                            }
                        }
                    }
                }

                // 100% marker when the maximum volume exceeds 100%
                Rectangle {
                    visible: root._maxvol > 100

                    x: parent.width * root._fullFraction * (86 / 89) + 1.5 * parent._s
                    y: (parent.height - height) / 2
                    width: VLCStyle.dp(1, VLCStyle.scale)
                    height: VLCStyle.dp(6, VLCStyle.scale)

                    color: theme.fg.primary
                    opacity: 0.35
                }

                // focus ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -VLCStyle.dp(1, VLCStyle.scale)

                    radius: VLCStyle.radius_s
                    color: "transparent"
                    visible: volControl.visualFocus

                    border.width: VLCStyle.focus_border
                    border.color: theme.visualFocus
                }
            }

            Widgets.ValueBubble {
                id: valueBubble

                x: (parent.width - width) / 2
                y: -(height + VLCStyle.spacing_8)

                z: 10

                shown: (volControl.hovered || volControl.pressed || volControl.visualFocus
                        || volControl._recentlyChanged) && !root.paintOnly

                // 100 %, the value is the player volume (can be > 100)
                text: Math.round(Player.volume * 100)
                suffix: " %"

                colorSet: ColorContext.Pane
            }

            MouseArea {
                id: sliderMouseArea

                anchors.fill: parent

                acceptedButtons: (Qt.LeftButton | Qt.RightButton)

                onPressed: (mouse) => {
                    if (root.paintOnly) {
                        mouse.accepted = true
                        return
                    }

                    volControl._shiftPressed = (mouse.modifiers === Qt.ShiftModifier)

                    if (mouse.button === Qt.LeftButton) {
                        mouse.accepted = false

                        return
                    }

                    volControl.filterEvents = false
                    adjustVolume(mouse)
                }

                onPositionChanged: (mouse) => {
                    if (mouse.buttons & Qt.RightButton)
                        adjustVolume(mouse)
                }

                onWheel: (wheel) => {

                    if ((Math.abs(wheel.pixelDelta.x) % 120 > 0) || (Math.abs(wheel.pixelDelta.y) % 120 > 0)) {
                        let delta = 0
                        if (Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y))
                            delta = wheel.pixelDelta.x
                        else
                            delta = wheel.pixelDelta.y

                        if (wheel.inverted)
                            delta = -delta
                        volControl.value += 0.001 * delta
                    }
                    else
                        wheelToVLC.qmlWheelEvent(wheel)

                    wheel.accepted = true
                }

                function adjustVolume(mouse) {
                    mouse.accepted = true

                    const pos = root.volumeFor(mouse.x / width)

                    if (pos < 0.25)
                        volControl.value = root.fractionFor(0)
                    else if (pos < 0.75)
                        volControl.value = root.fractionFor(0.5)
                    else if (pos < 1.125)
                        volControl.value = root.fractionFor(1)
                    else
                        volControl.value = root.fractionFor(1.25)
                }

                WheelToVLCConverter {
                    id: wheelToVLC

                    function handle(steps: int) {
                        if (steps > 0)
                            Player.setVolumeUp(steps)
                        else
                            Player.setVolumeDown(-steps)
                    }

                    Component.onCompleted: {
                        wheelUpDown.connect(wheelToVLC.handle)
                        wheelLeftRight.connect(wheelToVLC.handle)
                    }
                }
            }
        }
    }
}
