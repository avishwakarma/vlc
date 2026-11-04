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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Util

// Small on-screen message ("toast") that replaces the big freetype OSD text of the
// video output (the Qt interface turns that one off, see qt.cpp):
//
//       [icon]  Volume 40%   [====----]
//
// A pill centered at the top of the player, under the title bar, with the same surface
// as the resume pill. It is driven by the player state (volume, mute, speed, audio and
// subtitle track, delays, media title) so it also reacts to hotkeys and menus, and
// dismisses itself after a short time. It never takes the focus.
// Honors the "Show on-screen messages" (osd) and "Show the media title on start"
// (video-title-show) preferences.
Item {
    id: toast

    // width available to the pill
    property int maxWidth

    // text of the message currently displayed
    property string text
    // name of the icon (svg) displayed in front of the message
    property string iconName
    // 0..1 shows a progress bar (volume), -1 hides it
    property real progress: -1

    // time (ms) the message stays on screen
    property int timeout: 1800

    // optional click action: label shown after the message and the url opened on click
    // (snapshot: "Show in Finder")
    property string actionText
    property url actionUrl

    property bool shown: false

    readonly property bool osdEnabled: !!SettingsModel.option("osd").value
    readonly property bool titleOnStart: !!SettingsModel.option("video-title-show").value

    implicitHeight: surface.height
    implicitWidth: Math.min(row.implicitWidth + 2 * VLCStyle.spacing_12, maxWidth)

    opacity: 0
    visible: opacity > 0

    // purely informative: no focus; only a message with an action takes the mouse
    activeFocusOnTab: false
    enabled: actionText !== "" && shown

    Accessible.role: Accessible.AlertMessage
    Accessible.name: text

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Menu
    }

    // ---- API -------------------------------------------------------------------------

    function show(message, icon, ratio, action, url) {
        if (!osdEnabled || message === "")
            return

        actionText = action || ""
        actionUrl = url || ""
        timeout = actionText !== "" ? 4000 : 1800
        text = message
        iconName = icon || ""
        progress = (ratio === undefined) ? -1 : Math.max(0, Math.min(1, ratio))
        shown = true
        hideTimer.restart()
    }

    function hide() {
        actionText = ""
        hideTimer.stop()
        shown = false
    }

    // ---- player state -> messages ----------------------------------------------------

    // The state sent by the player when a media starts (restored volume, default tracks, ...)
    // is not a user action: nothing is shown until the media has settled.
    property bool _armed: false

    Timer {
        id: armTimer
        interval: 1500
        onTriggered: toast._armed = true
    }

    property bool _titlePending: false

    function _disarm() {
        _armed = false
        armTimer.restart()
    }

    Component.onCompleted: {
        _disarm()
        // the player view is created when the media is already starting
        _titlePending = titleOnStart && Player.isStarted
        _showTitle()
    }

    Connections {
        target: Player

        function onInputChanged(hasInput) {
            toast.hide()
            toast._disarm()
            toast._titlePending = hasInput && toast.titleOnStart
            toast._showTitle()
        }

        function onDisplayTitleChanged() {
            toast._showTitle()
        }

        function onVolumeChanged() {
            toast._showVolume()
        }

        function onSoundMuteChanged() {
            toast._showVolume()
        }

        function onRateChanged() {
            if (!toast._armed)
                return
            toast.show(qsTr("Speed %1x").arg(+Player.rate.toFixed(2)), "speed")
        }

        function onSnapshotTaken(path) {
            if (!toast.osdEnabled)
                return
            const slash = path.lastIndexOf("/")
            const dir = slash > 0 ? path.substring(0, slash) : ""
            toast.show(qsTr("Snapshot saved"), "snapshot", undefined,
                       dir !== "" ? qsTr("Show in Finder") : "", dir !== "" ? "file://" + encodeURI(dir) : "")
        }

        // keyboard / menu seeks: the player time jumps by more than playback explains
        function onTimeChanged() {
            const now = Date.now()
            const t = Player.position * Player.length.toSeconds() * 1000
            const playing = Player.playingState === Player.PLAYING_STATE_PLAYING
            const expected = playing ? (now - toast._lastWall) * Player.rate : 0
            const jump = t - toast._lastTime - expected
            const first = toast._lastWall === 0
            toast._lastTime = t
            toast._lastWall = now
            if (first || !toast._armed || Math.abs(jump) < 1500 || now - toast._slider < 800)
                return
            const delta = Math.round(jump / 1000)
            const sign = delta > 0 ? "+" : "\u2212"
            toast.show("%1 / %2   %3%4 s".arg(Player.time.formatHMS()).arg(Player.length.formatHMS())
                           .arg(sign).arg(Math.abs(delta)),
                       delta > 0 ? "arrow-right" : "arrow-left",
                       Player.length.toSeconds() > 0 ? Player.position : undefined)
        }

        // seeks done with the seek bar show their own position
        function onSeekRequested() {
            toast._slider = Date.now()
        }

        function onAudioDelayChanged() {
            if (!toast._armed)
                return
            toast.show(qsTr("Audio delay %1").arg(toast._delayText(Player.audioDelayMS)), "audio")
        }

        function onSubtitleDelayChanged() {
            if (!toast._armed)
                return
            toast.show(qsTr("Subtitle delay %1").arg(toast._delayText(Player.subtitleDelayMS)), "subtitles")
        }
    }

    // A-B loop state (Q_PROPERTY of the player, observed through a binding)
    readonly property int _abState: Player.ABloopState

    on_AbStateChanged: {
        if (!_armed)
            return
        switch (_abState) {
        case Player.ABLOOP_STATE_A:
            show(qsTr("Loop start set at %1").arg(Player.ABLoopA.formatHMS()), "speed")
            break
        case Player.ABLOOP_STATE_B:
            show(qsTr("Looping %1 to %2").arg(Player.ABLoopA.formatHMS()).arg(Player.ABLoopB.formatHMS()), "speed")
            break
        default:
            show(qsTr("Loop off"), "speed")
        }
    }

    // aspect ratio, crop and zoom (they were vout text)
    Connections {
        target: Player.aspectRatio
        function onDataChanged(top, bottom, roles) { toast._varChoice(top, qsTr("Aspect ratio"), "video", Player.aspectRatio) }
    }

    Connections {
        target: Player.crop
        function onDataChanged(top, bottom, roles) { toast._varChoice(top, qsTr("Crop"), "video", Player.crop) }
    }

    Connections {
        target: Player.zoom
        function onDataChanged(top, bottom, roles) { toast._varChoice(top, qsTr("Zoom"), "zoom", Player.zoom) }
    }

    property double _lastWall: 0
    property double _lastTime: 0
    property double _slider: 0

    function _varChoice(index, label, icon, model) {
        if (!_armed || model.data(index, Qt.CheckStateRole) !== true && model.data(index, Qt.CheckStateRole) !== Qt.Checked)
            return
        show("%1: %2".arg(label).arg(model.data(index, Qt.DisplayRole)), icon)
    }

    Connections {
        target: Player.audioTracks

        function onTrackSelectionChanged(title, selected) {
            if (!toast._armed || !selected)
                return
            toast.show(qsTr("Audio: %1").arg(title), "audio")
        }
    }

    Connections {
        target: Player.subtitleTracks

        function onTrackSelectionChanged(title, selected) {
            if (!toast._armed)
                return
            if (selected)
                toast.show(qsTr("Subtitles: %1").arg(title), "subtitles")
            else if (Player.isStarted)
                toast.show(qsTr("Subtitles off"), "subtitles")
        }
    }

    function _showTitle() {
        if (!_titlePending || Player.displayTitle === "")
            return
        _titlePending = false
        show(Player.displayTitle, "")
    }

    function _showVolume() {
        if (!_armed)
            return
        const percent = Math.round(Player.volume * 100)
        if (Player.muted || percent === 0) {
            show(qsTr("Muted"), "close-none")
            return
        }
        let icon = "volume-high"
        if (Player.volume < .33)
            icon = "close-low"
        else if (Player.volume <= .66)
            icon = "close-medium"
        show(qsTr("Volume %1%").arg(percent), icon, Math.min(1, Player.volume))
    }

    function _delayText(ms) {
        return (ms > 0 ? "+" : "") + ms + " ms"
    }

    // ---- look ------------------------------------------------------------------------

    Timer {
        id: hideTimer
        interval: toast.timeout
        onTriggered: toast.shown = false
    }

    // fade + slide in, fade out
    states: State {
        name: "shown"
        when: toast.shown
        PropertyChanges { target: toast; opacity: 1 }
        PropertyChanges { target: slide; y: 0 }
    }

    transitions: Transition {
        NumberAnimation { properties: "opacity,y"; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
    }

    Item {
        id: surface

        width: toast.implicitWidth
        height: row.implicitHeight + 2 * VLCStyle.spacing_8

        transform: Translate { id: slide; y: -VLCStyle.spacing_12 }

        Rectangle {
            anchors.fill: parent

            radius: VLCStyle.radius_l
            color: theme.bg.primary
            opacity: 0.95

            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: theme.border

            Widgets.RoundedRectangleShadow {
                z: -1
                blurRadius: VLCStyle.shadow_floating.blur
                yOffset: VLCStyle.shadow_floating.y
                color: VLCStyle.shadowColor(VLCStyle.shadow_floating.alpha)
            }
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            z: 1
            enabled: toast.actionText !== ""
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Qt.openUrlExternally(toast.actionUrl)
                toast.hide()
            }
        }

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.leftMargin: VLCStyle.spacing_12
            anchors.rightMargin: VLCStyle.spacing_12
            spacing: VLCStyle.spacing_8

            Widgets.SvgIcon {
                Layout.alignment: Qt.AlignVCenter

                visible: toast.iconName !== ""
                name: toast.iconName
                size: VLCStyle.icon_normal
                color: theme.fg.secondary
            }

            T.Label {
                id: label

                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                // not implicitWidth: with elide it is computed from the current (stale) width
                Layout.preferredWidth: Math.ceil(metrics.advanceWidth)

                TextMetrics {
                    id: metrics
                    font: label.font
                    text: label.text
                }

                text: toast.text
                color: theme.fg.primary
                font.pixelSize: VLCStyle.text_body
                elide: Text.ElideRight
            }

            T.Label {
                Layout.alignment: Qt.AlignVCenter

                visible: toast.actionText !== ""
                text: toast.actionText
                color: theme.accentText
                font.pixelSize: VLCStyle.text_body
                font.weight: VLCStyle.fontWeight_semibold
                font.underline: actionArea.containsMouse
            }

            // level (volume)
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: VLCStyle.dp(64, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(4, VLCStyle.scale)

                visible: toast.progress >= 0
                radius: height / 2
                color: theme.bg.secondary

                Rectangle {
                    width: parent.width * Math.max(0, toast.progress)
                    height: parent.height
                    radius: parent.radius
                    color: theme.accent
                }
            }
        }
    }
}
