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
import QtQml.Models


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Util

// Player control bar (Figma 491:1928): 54 high, padding 20 x 11, gap 20 between groups
//
//  [prev][ PLAY ][next]  [00:02:10 |=====seek=====| 00:25:40]  [vol ◢]  [audio][subs][settings]  [queue]
//
T.Pane {
    id: root

    // Properties

    property int identifier: -1

    property var menu: undefined

    // extra margins (safe area) added to the paddings
    property real sideMargin: 0
    property real bottomMargin: 0

    // true when the bar floats over the video (fullscreen): translucent surface + top border
    property bool overlay: false

    property real backgroundOpacity: 1.0

    property bool playlistVisible: false

    // For now, used for d&d functionality of the queue button
    property Item plListView

    // y of the bar top relative to the bar (anchor of popups placed above the bar)
    readonly property real sliderY: 0

    property alias trackPositionSlider: trackPositionSlider

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal togglePlaylistVisibility()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    leftPadding: VLCStyle.spacing_20 + sideMargin
    rightPadding: VLCStyle.spacing_20 + sideMargin
    topPadding: VLCStyle.dp(11, VLCStyle.scale)
    bottomPadding: VLCStyle.dp(11, VLCStyle.scale) + bottomMargin

    enabled: visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)
    Navigation.cancelAction: function() { History.previous(Qt.BacktabFocusReason) }

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    function showChapterMarks() {
        trackPositionSlider.showChapterMarks()
    }

    function applyMenu(menu) {
        if (root.menu === menu)
            return

        // NOTE: When applying a new menu we hide the previous one.
        if (menu)
            dismiss()

        root.menu = menu
    }

    function dismiss() {
        if ((typeof menu === undefined) || !menu)
            return
        if (menu.hasOwnProperty("dismiss"))
            menu.dismiss()
        else if (menu.hasOwnProperty("close"))
            menu.close()
    }

    // time as HH:MM:SS, like the Figma chips
    function formatTime(tick, prefix) {
        let str = tick.formatHMS(0)
        if (/^\d\d:\d\d$/.test(str))
            str = "00:" + str
        else if (str === "--:--")
            str = "--:--:--"
        return (prefix ?? "") + str
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    background: Rectangle {
        color: root.overlay ? theme.bg.secondary : theme.bg.primary
        opacity: root.overlay ? root.backgroundOpacity * 0.95 : root.backgroundOpacity

        Rectangle {
            visible: root.overlay

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: VLCStyle.dp(1, VLCStyle.scale)

            color: theme.border
        }
    }

    contentItem: RowLayout {
        id: row

        spacing: VLCStyle.spacing_20

        // Transport: previous, play, next (gap 8)
        RowLayout {
            spacing: VLCStyle.spacing_8

            Layout.alignment: Qt.AlignVCenter

            PreviousButton {
                id: previousButton

                Layout.preferredWidth: VLCStyle.iconButton_w
                Layout.preferredHeight: VLCStyle.iconButton_h

                Navigation.parentItem: root
                Navigation.rightItem: playButton
            }

            PlayButton {
                id: playButton

                Layout.preferredWidth: VLCStyle.playButton_w
                Layout.preferredHeight: VLCStyle.playButton_h
                Layout.alignment: Qt.AlignVCenter

                focus: true

                Navigation.parentItem: root
                Navigation.leftItem: previousButton
                Navigation.rightItem: nextButton
            }

            NextButton {
                id: nextButton

                Layout.preferredWidth: VLCStyle.iconButton_w
                Layout.preferredHeight: VLCStyle.iconButton_h

                Navigation.parentItem: root
                Navigation.leftItem: playButton
                Navigation.rightItem: trackPositionSlider.enabled ? trackPositionSlider : durationChip
            }
        }

        // Seek group: current time, seek bar, duration (gap 8)
        RowLayout {
            spacing: VLCStyle.spacing_8

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Widgets.TimeChip {
                id: timeChip

                text: root.formatTime(Player.time)

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

                enabled: Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED

                Navigation.parentItem: root
                Navigation.leftItem: nextButton
                Navigation.rightItem: durationChip

                activeFocusOnTab: true

                Keys.onPressed: (event) => {
                    Navigation.defaultKeyAction(event)
                }
            }

            Widgets.TimeChip {
                id: durationChip

                readonly property bool showRemainingTime: (MainCtx.showRemainingTime && Player.remainingTime.valid())

                clickable: true

                text: showRemainingTime ? root.formatTime(Player.remainingTime, "-")
                                        : root.formatTime(Player.length)

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
                Navigation.leftItem: trackPositionSlider.enabled ? trackPositionSlider : nextButton
                Navigation.rightItem: volumeWidget

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
        }

        // Volume: icon + wedge (gap 8)
        VolumeWidget {
            id: volumeWidget

            Layout.alignment: Qt.AlignVCenter

            Navigation.parentItem: root
            Navigation.leftItem: durationChip
            Navigation.rightItem: audioButton
        }

        // Audio tracks, subtitles, playback settings (gap 12)
        RowLayout {
            spacing: VLCStyle.spacing_12

            Layout.alignment: Qt.AlignVCenter

            LangButton {
                id: audioButton

                iconName: "audio"
                description: qsTr("Audio tracks")

                Layout.preferredWidth: VLCStyle.iconButton_w
                Layout.preferredHeight: VLCStyle.iconButton_h

                Navigation.parentItem: root
                Navigation.leftItem: volumeWidget
                Navigation.rightItem: subtitleButton

                onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
                onMenuOpened: (menu) => root.applyMenu(menu)

                Component.onCompleted: root.forceUnlock.connect(audioButton.forceUnlock)
            }

            LangButton {
                id: subtitleButton

                iconName: "subtitles"
                description: qsTr("Subtitles")

                Layout.preferredWidth: VLCStyle.iconButton_w
                Layout.preferredHeight: VLCStyle.iconButton_h

                Navigation.parentItem: root
                Navigation.leftItem: audioButton
                Navigation.rightItem: settingsButton

                onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
                onMenuOpened: (menu) => root.applyMenu(menu)

                Component.onCompleted: root.forceUnlock.connect(subtitleButton.forceUnlock)
            }

            ExtendedSettingsButton {
                id: settingsButton

                Layout.preferredWidth: VLCStyle.iconButton_w
                Layout.preferredHeight: VLCStyle.iconButton_h

                Navigation.parentItem: root
                Navigation.leftItem: subtitleButton
                Navigation.rightItem: queueButton
            }
        }

        // Queue
        PlaylistPane.PlaylistToggleButton {
            id: queueButton

            Layout.preferredWidth: VLCStyle.iconButton_w
            Layout.preferredHeight: VLCStyle.iconButton_h
            Layout.alignment: Qt.AlignVCenter

            iconName: "lists"
            iconNameChecked: "lists-active"
            iconSize: VLCStyle.icon_normal

            description: qsTr("Play Queue")

            AccessibleCompat.id: "topBarPlayqueueButton"

            checked: root.playlistVisible

            plListView: root.plListView

            Navigation.parentItem: root
            Navigation.leftItem: settingsButton

            onClicked: root.togglePlaylistVisibility()

            Accessible.onToggleAction: root.togglePlaylistVisibility()

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }
    }
}
