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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Util

// Seek group of the control bar (Figma 491:1928): current time, seek bar, duration.
// Either one of the items of a control row (it takes all the free width) or, when the
// profile does not contain it, shown by the control bar in a row of its own.
FocusScope {
    id: root

    // used by the control rows when they look for the next item to focus
    property int focusReason: Qt.OtherFocusReason

    // Properties

    property bool paintOnly: false

    // makes the item expand in the control rows
    readonly property bool fillWidth: true

    property alias trackPositionSlider: trackPositionSlider

    // one time policy: "0:05", "53:12", "1:47:12", unknown "—"
    function formatTime(tick, prefix) {
        const str = tick.formatHMS(0)
        return str === "—" ? str : (prefix ?? "") + str
    }

    property var _host: null

    // the control bar tracks the slider (popup anchors, chapter marks)
    function _findHost() {
        let p = root.parent
        while (p) {
            if (p.registerTimeline)
                return p
            p = p.parent
        }
        return null
    }

    Component.onCompleted: {
        _host = _findHost()
        if (_host)
            _host.registerTimeline(trackPositionSlider)
    }

    Component.onDestruction: {
        if (_host)
            _host.unregisterTimeline(trackPositionSlider)
    }

    // Settings

    implicitWidth: VLCStyle.dp(420, VLCStyle.scale)
    implicitHeight: VLCStyle.seek_height

    // both time chips and a track that stays usable
    Layout.minimumWidth: Math.max(timeChip.Layout.preferredWidth, 0) + Math.max(durationChip.Layout.preferredWidth, 0)
                         + VLCStyle.spacing_8 * 2 + VLCStyle.dp(140, VLCStyle.scale)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Seek bar")

    // Children

    RowLayout {
        anchors.fill: parent

        spacing: VLCStyle.spacing_8

        Widgets.TimeChip {
            id: timeChip

            text: root.paintOnly ? "0:02:10" : root.formatTime(Player.time)

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.max(implicitWidth, durationChip.implicitWidth)

            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: timeChip
                property: "mutabilityGroup"
                when: (timeChip.mutabilityGroup !== undefined)
                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                              : Item.StaticMutabilityGroup
            }
        }

        SliderBar {
            id: trackPositionSlider

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Progress")
            AccessibleCompat.id: "progressSlider"

            enabled: !root.paintOnly && (Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED)

            focus: true

            Navigation.parentItem: root
            Navigation.leftItem: root.Navigation.leftItem
            Navigation.rightItem: durationChip

            activeFocusOnTab: true

            Keys.onPressed: (event) => {
                Navigation.defaultKeyAction(event)
            }
        }

        Widgets.TimeChip {
            id: durationChip

            readonly property bool showRemainingTime: (!root.paintOnly && MainCtx.showRemainingTime && Player.remainingTime.valid())

            clickable: !root.paintOnly

            text: root.paintOnly ? "0:25:40"
                                 : (showRemainingTime ? root.formatTime(Player.remainingTime, "-")
                                                      : root.formatTime(Player.length))

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.max(implicitWidth, timeChip.implicitWidth)

            Accessible.name: showRemainingTime ? qsTr("Remaining time %1").arg(text)
                                               : qsTr("Duration %1").arg(text)

            T.ToolTip.visible: hovered && MainCtx.showRemainingTime && Player.rate !== 1
            T.ToolTip.delay: VLCStyle.delayToolTipAppear
            T.ToolTip.text: {
                if (!T.ToolTip.visible)
                    return ""

                const playbackSpeed = Math.abs(Player.rate)
                const adjustedRemainingTime = Player.remainingTime.scale(1 / playbackSpeed)
                    ? Player.remainingTime.scale(1 / playbackSpeed)
                    : Player.remainingTime

                return qsTr("%1 (%2x)")
                    .arg(adjustedRemainingTime.formatHMS())
                    .arg(+Player.rate.toFixed(2))
            }

            Navigation.parentItem: root
            Navigation.leftItem: trackPositionSlider.enabled ? trackPositionSlider : root.Navigation.leftItem
            Navigation.rightItem: root.Navigation.rightItem

            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event)) {
                    event.accepted = true
                    MainCtx.showRemainingTime = !MainCtx.showRemainingTime
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            onClicked: MainCtx.showRemainingTime = !MainCtx.showRemainingTime
        }

        StatusChips {
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
