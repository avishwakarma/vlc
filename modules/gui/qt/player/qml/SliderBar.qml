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

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.MainInterface

T.ProgressBar {
    id: control

    // Figma seek bar: 28 high B2 track (radius 6), played fill inset by 2 (radius 4),
    // 8x24 thumb at the played edge
    property int barHeight: VLCStyle.seek_height

    readonly property real _inset: VLCStyle.spacing_2
    readonly property real _thumbWidth: VLCStyle.dp(8, VLCStyle.scale)
    readonly property real _innerHeight: control.barHeight - _inset * 2

    // x of the left edge of the thumb for the current position
    readonly property real _thumbX: _inset + control.visualPosition * Math.max(0, control.width - _inset * 2 - _thumbWidth)

    readonly property bool _active: hoverHandler.hovered || control.visualFocus || dragHandler.active

    // Waveform (Figma 2139:8124, music bar 4767:23726): drawn instead of the fill and the
    // thumb for local audio files. Set to false to always use the plain bar.
    property bool waveformEnabled: !Player.hasVideoOutput

    readonly property bool _waveform: waveformTrack.active

    readonly property color handleColor: control._active ? Qt.lighter(theme.accent, 1.12) : theme.accent

    // position for an x coordinate of the control
    function _positionAt(x) {
        return control._waveform ? waveformTrack.positionAt(x) : x / control.width
    }

    // position (in px, relative to the control) of the hovered / dragged point
    readonly property real _pointerX: dragHandler.active ? Helpers.clamp(dragHandler.centroid.position.x, 0, control.width)
                                                         : (hoverHandler.hovered ? Helpers.clamp(hoverHandler.point.position.x, 0, control.width)
                                                                                 : (control._thumbX + _thumbWidth / 2))

    property real _tooltipPosition: control.width > 0 ? control._positionAt(control._pointerX) : 0

    // Track (Figma B2, darker than the bar in the dark theme, a touch lighter in the light one).
    // Derived from the surface the bar sits on: with the "System" colour scheme the Slider set
    // comes from the platform palette, where its background equals the window one and the unplayed
    // part of the track became invisible (the bar looked like a short orange block).
    readonly property color _surface: surfaceTheme.bg.primary
    readonly property color _track: surfaceTheme.palette.isDark ? Qt.darker(_surface, 3.3)
                                                                : Qt.lighter(_surface, 1.04)
    // played fill: accent over the track (Figma Accent Bright = accent at 24 % over B2)
    readonly property color _fill: Qt.tint(_track, Qt.alpha(theme.accent, surfaceTheme.palette.isDark ? 0.24 : 0.30))

    property color backgroundColor: _track
    property real touchHandlerMargin: VLCStyle.touchHandlerMargin

    Keys.onRightPressed: Player.jumpFwd()
    Keys.onLeftPressed: Player.jumpBwd()

    Accessible.onIncreaseAction: Player.jumpFwd()
    Accessible.onDecreaseAction: Player.jumpBwd()

    // chapter marks are always drawn, kept for API compatibility
    function showChapterMarks() {
    }

    readonly property ColorContext surfaceColorContext: ColorContext {
        id: surfaceTheme
        colorSet: ColorContext.Window
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: hoverHandler.hovered
        pressed: dragHandler.active
    }

    // Tooltip: time (and chapter) at the pointer
    readonly property string tooltipText: {
        const length = Player.length
        let _text

        if (hoverHandler.hovered || dragHandler.active)
            _text = length.scale(control._tooltipPosition)
        else
            _text = Player.time

        let str = control.formatTime(_text, length)

        if (Player.hasChapters)
            str += "  -  " + Player.chapters.getNameAtPosition(control._tooltipPosition)

        return str
    }

    // always HH:MM:SS like the Figma time chips
    function formatTime(tick, length) {
        let str = tick.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)
        if (/^\d\d:\d\d$/.test(str))
            str = "00:" + str
        else if (str === "--:--")
            str = "--:--:--"
        return str
    }

    FSM {
        id: fsm
        signal playerUpdatePosition(real position)
        signal pressControl(real position, bool forcePrecise)
        signal releaseControl(real position, bool forcePrecise)
        signal moveControl(real position, bool forcePrecise)
        signal inputChanged()

        //each signal is associated to a key, when a signal is received,
        //transitions of active state for the given key are evaluated
        signalMap: ({
            "playerUpdatePosition": fsm.playerUpdatePosition,
            "pressControl": fsm.pressControl,
            "releaseControl": fsm.releaseControl,
            "moveControl": fsm.moveControl,
            "inputChanged": fsm.inputChanged
        })

        initialState: fsmReleased

        function _setPositionFromValue(position) {
            control.value = position
        }

        function _seekToPosition(position, threshold, forcePrecise) {
            position = Helpers.clamp(position, 0., 1.)
            control.value = position
            if (!forcePrecise) {
                const chapter = Player.chapters.getClosestChapterFromPos(position, threshold)
                if (chapter !== -1) {
                    Player.chapters.selectChapter(chapter)
                    return
                }
            }
            Player.position = position
        }

        FSMState {
            id: fsmReleased

            transitions: ({
                "playerUpdatePosition": {
                    action: (position) => {
                        control.value = position
                    }
                },
                "pressControl": {
                    action: (position, forcePrecise) => {
                        control.forceActiveFocus()
                        fsm._seekToPosition(position, VLCStyle.dp(4, VLCStyle.scale) / control.width, forcePrecise)
                    },
                    target: fsmHeld
                }
            })
        }

        FSMState  {
            id: fsmHeld

            transitions: ({
                "moveControl": {
                    action: (position, forcePrecise) => {
                        fsm._seekToPosition(position, VLCStyle.dp(2, VLCStyle.scale) / control.width, forcePrecise)
                    }
                },
                "releaseControl": {
                    target: fsmReleased
                },
                "inputChanged": {
                    target: fsmHeldWrongInput
                }
            })
        }

        FSMState  {
            id: fsmHeldWrongInput

            function enter() {
                fsm._setPositionFromValue(Player.position)
            }

            transitions: ({
                "playerUpdatePosition": {
                    action: fsm._setPositionFromValue
                },
                "releaseControl": {
                    target: fsmReleased
                }
            })
        }
    }

    Connections {
        target: Player
        function onPositionChanged() {  fsm.playerUpdatePosition(Player.position) }
        function onInputChanged() {  fsm.inputChanged() }
    }

    Component.onCompleted: value = Player.position

    implicitHeight: control.barHeight
    height: implicitHeight

    padding: 0

    //we use our own HoverHandler
    hoverEnabled: false

    HoverHandler {
        id: hoverHandler

    }

    contentItem: Item {
        implicitHeight: control.implicitHeight
        implicitWidth: control.implicitWidth

        //placing the TapHandler directly in the Control doesn't work with 6.2
        TapHandler {
            acceptedButtons: Qt.LeftButton

            gesturePolicy: TapHandler.WithinBounds

            // Make it easier to tap with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0.0

            onPressedChanged: {
                if (pressed) {
                    fsm.pressControl(control._positionAt(point.position.x), point.modifiers === Qt.ShiftModifier)
                } else {
                    // NOTE: Point is still valid at this point.
                    fsm.releaseControl(control._positionAt(point.position.x), point.modifiers === Qt.ShiftModifier)
                }
            }
        }

        DragHandler {
            id: dragHandler
            acceptedButtons: Qt.LeftButton

            // Make it easier to drag with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0

            target: null
            dragThreshold: 0
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            property bool filterEvents: false

            function moveControl() {
                fsm.moveControl(control._positionAt(dragHandler.centroid.position.x),
                                dragHandler.centroid.modifiers === Qt.ShiftModifier)
            }

            onActiveChanged: {
                if (active) {
                    filterEvents = false
                    fsm.pressControl(control._positionAt(centroid.position.x), centroid.modifiers === Qt.ShiftModifier)
                } else {
                    fsm.releaseControl(control._positionAt(centroid.position.x), centroid.modifiers === Qt.ShiftModifier)
                }
            }

            onCentroidChanged: {
                // FIXME: Qt 6.5 use xAxis.onActiveValueChanged in the DragHandler
                if (filterEvents) {
                    Qt.callLater(dragHandler.moveControl)
                } else {
                    dragHandler.moveControl()
                    filterEvents = true
                }
            }
        }

        WheelHandler {
            orientation: Qt.Vertical | Qt.Horizontal

            acceptedDevices: PointerDevice.AllDevices

            onWheel: (wheel) => {
                wheelToVLC.qmlWheelEvent(wheel)
                wheel.accepted = true
            }
        }

        WheelToVLCConverter {
            id: wheelToVLC

            function handleVertical(steps: int) {
                if (steps > 0)
                    Player.jumpFwd()
                else
                    Player.jumpBwd()
            }

            function handleHorizontal(steps: int) {
                if (steps > 0)
                    Player.jumpBwd()
                else
                    Player.jumpFwd()
            }

            Component.onCompleted: {
                wheelUpDown.connect(wheelToVLC, wheelToVLC.handleVertical)
                wheelLeftRight.connect(wheelToVLC, wheelToVLC.handleHorizontal)
            }
        }
    }

    background: Rectangle {
        id: sliderRect

        implicitHeight: control.barHeight
        implicitWidth: VLCStyle.dp(200, VLCStyle.scale)

        width: control.availableWidth
        height: control.barHeight

        radius: VLCStyle.radius_m

        color: control.backgroundColor

        border.width: control.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus
        border.pixelAligned: false

        // played part: from the left inset to the right edge of the thumb
        Rectangle {
            id: progressRect

            x: control._inset
            y: control._inset

            width: control._thumbX + control._thumbWidth - control._inset
            height: control._innerHeight

            radius: VLCStyle.radius_s

            color: control._fill

            opacity: control._waveform ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: VLCStyle.duration_long }
            }

            // We use dynamic mutability group because time interpolation
            // may induce rapid change:
            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: progressRect
                property: "mutabilityGroup"
                when: (progressRect.mutabilityGroup !== undefined)
                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                              : Item.StaticMutabilityGroup
            }
        }

        WaveformSeekTrack {
            id: waveformTrack

            anchors.fill: parent

            slider: control
            source: control.waveformEnabled ? Player.url : ""
            pointerX: (hoverHandler.hovered || dragHandler.active) ? control._pointerX : -1
        }

        // chapter marks
        Repeater {
            model: Player.hasChapters ? Player.chapters : null

            Rectangle {
                required property var model

                readonly property real startPosition: model.startPosition ?? 0.0

                visible: startPosition > 0.0 && startPosition < 1.0

                x: control._inset + startPosition * (control.width - control._inset * 2) - width / 2
                y: control._inset
                width: VLCStyle.dp(2, VLCStyle.scale)
                height: control._innerHeight

                color: control.backgroundColor
            }
        }

        // buffering indicator: thin line along the bottom of the track
        Rectangle {
            id: bufferRect

            property int bufferAnimWidth: VLCStyle.dp(100, VLCStyle.scale)
            property int bufferAnimPosition: 0
            property int bufferFrames: 1000
            property alias animateLoading: loadingAnim.running
            property bool display: false
            property bool buffering: Player.buffering > 0 && Player.buffering < 1

            y: parent.height - control._inset - height
            height: VLCStyle.dp(2, VLCStyle.scale)
            opacity: 0.6
            color: theme.fg.neutral //FIXME buffer color ?
            radius: height

            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: bufferRect
                property: "mutabilityGroup"
                when: bufferRect.mutabilityGroup !== undefined
                value: bufferRect.buffering ? Item.DynamicMutabilityGroup
                                            : Item.StaticMutabilityGroup
            }

            Timer {
                id: bufferingTimer
                interval: VLCStyle.duration_humanMoment
                repeat: false
                running: false
                onTriggered: {
                    bufferRect.display = true
                }
            }

            onBufferingChanged: {
                if(buffering)
                {
                    bufferingTimer.start()
                }
                else
                {
                    bufferingTimer.stop()
                    bufferRect.display = false
                }
            }

            states: [
                State {
                    name: "hidden"
                    when: !control.visible
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "buffering not started"
                    when: control.visible && Player.buffering === 0
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: true
                        x: (bufferAnimPosition / bufferFrames) * (parent.width - bufferAnimWidth)
                        animateLoading: true
                    }
                },
                State {
                    name: "time to start playing known"
                    when: control.visible && bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: true
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "playing from buffer"
                    when: control.visible && !bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                }
            ]

            SequentialAnimation on bufferAnimPosition {
                id: loadingAnim
                running: bufferRect.animateLoading
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 0.0
                    to: bufferRect.bufferFrames
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
                PropertyAnimation {
                    from: bufferRect.bufferFrames
                    to: 0.0
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
            }
        }
    }

    // Thumb: 8x24, accent, flush with the right edge of the played fill
    Rectangle {
        id: sliderHandle

        x: control._thumbX
        y: control._inset

        width: control._thumbWidth
        height: control._innerHeight

        radius: VLCStyle.radius_s

        color: control.handleColor

        opacity: control._waveform ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: VLCStyle.duration_long }
        }

        Behavior on color {
            ColorAnimation {
                duration: VLCStyle.duration_short
            }
        }

        // We use dynamic mutability group because time interpolation
        // may induce rapid change:
        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: sliderHandle
            property: "mutabilityGroup"
            when: (sliderHandle.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }
    }

    // Time tooltip above the pointer
    Widgets.ValueBubble {
        id: tooltip

        readonly property point _origin: control.mapToItem(null, 0, 0)

        // keep the bubble inside the window
        x: {
            const win = control.Window.width
            const gx = Helpers.clamp(_origin.x + control._pointerX - width / 2, VLCStyle.viewport_inset, win - width - VLCStyle.viewport_inset)
            return gx - _origin.x
        }

        y: -(height + VLCStyle.spacing_12)

        z: 10

        shown: control._active && control.enabled

        text: control.tooltipText

        colorSet: ColorContext.Menu
    }
}
