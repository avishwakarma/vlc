/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Playlist
import VLC.Util

// "Playback" quick menu of the settings button (Figma 2238:9432, compact): the things that are
// reached for during playback, in one small popover. "More Settings…" opens the full panel.
T.Popup {
    id: root

    // time the popup was last closed, lets the owner button turn a click into a toggle
    property double closedAt: 0

    signal requestMoreSettings()

    readonly property real _barTop: (parent && parent.positionSliderY !== undefined) ? parent.positionSliderY : (parent ? parent.height : 0)

    readonly property var speedChoices: [0.5, 1, 1.25, 1.5, 2]
    readonly property var sleepChoices: [
        { text: qsTr("Off"), minutes: 0 },
        { text: qsTr("15 min"), minutes: 15 },
        { text: qsTr("30 min"), minutes: 30 },
        { text: qsTr("1 h"), minutes: 60 }
    ]

    width: VLCStyle.dp(320, VLCStyle.scale)
    height: panelColumn.implicitHeight
    x: parent ? parent.width - width - VLCStyle.popoverPanel_margin : 0
    y: _barTop - height - VLCStyle.popoverPanel_margin

    padding: 0
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
    focus: true

    onClosed: closedAt = Date.now()

    readonly property ColorContext colorContext: ColorContext {
        id: popupTheme
        colorSet: ColorContext.Pane
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long }
            NumberAnimation { target: slide; property: "y"; from: VLCStyle.spacing_12; to: 0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_short }
            NumberAnimation { target: slide; property: "y"; from: 0; to: VLCStyle.spacing_8; duration: VLCStyle.duration_short }
        }
    }

    background: null

    contentItem: Item {
        focus: true

        readonly property ColorContext colorContext: ColorContext {
            colorSet: popupTheme.colorSet
            palette: popupTheme.palette
        }

        transform: Translate { id: slide }

        Rectangle {
            anchors.fill: parent
            radius: VLCStyle.radius_l

            color: popupTheme.bg.primary
            opacity: 0.97

            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: popupTheme.border

            Widgets.RoundedRectangleShadow {
                z: -1
                blurRadius: VLCStyle.shadow_floating.blur
                yOffset: VLCStyle.shadow_floating.y
                color: VLCStyle.shadowColor(VLCStyle.shadow_floating.alpha)
            }
        }

        ColumnLayout {
            id: panelColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            spacing: 0

            readonly property ColorContext colorContext: ColorContext {
                id: theme
                colorSet: ColorContext.View
            }

            // Speed
            Widgets.LabelExt {
                Layout.topMargin: VLCStyle.spacing_16
                Layout.leftMargin: VLCStyle.spacing_20
                text: qsTr("Speed")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }

            Widgets.SegmentedControl {
                Layout.topMargin: VLCStyle.spacing_8
                Layout.leftMargin: VLCStyle.spacing_20
                Layout.rightMargin: VLCStyle.spacing_20
                Layout.fillWidth: true

                compact: true
                enabled: Player.ratechangable
                model: root.speedChoices.map(v => qsTr("%1×").arg(v))
                currentIndex: {
                    for (let i = 0; i < root.speedChoices.length; ++i)
                        if (Math.abs(root.speedChoices[i] - Player.rate) < 0.005)
                            return i
                    return -1
                }
                onActivated: (i) => Player.rate = root.speedChoices[i]
                Accessible.name: qsTr("Playback speed")
            }

            // Sleep timer
            Widgets.LabelExt {
                Layout.topMargin: VLCStyle.spacing_16
                Layout.leftMargin: VLCStyle.spacing_20
                text: PlayerAux.sleepActive ? qsTr("Sleep Timer, %1 left").arg(PlayerAux.sleepText)
                                            : qsTr("Sleep Timer")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }

            Widgets.SegmentedControl {
                Layout.topMargin: VLCStyle.spacing_8
                Layout.leftMargin: VLCStyle.spacing_20
                Layout.rightMargin: VLCStyle.spacing_20
                Layout.fillWidth: true

                compact: true
                model: root.sleepChoices
                currentIndex: {
                    for (let i = 0; i < root.sleepChoices.length; ++i)
                        if (root.sleepChoices[i].minutes === PlayerAux.sleepMinutes)
                            return i
                    return -1
                }
                onActivated: (i) => PlayerAux.setSleep(root.sleepChoices[i].minutes)
                Accessible.name: qsTr("Sleep Timer")
            }

            PanelToggleRow {
                Layout.topMargin: VLCStyle.spacing_12
                Layout.leftMargin: VLCStyle.spacing_20
                Layout.rightMargin: VLCStyle.spacing_20
                label: qsTr("A-B Loop")
                checked: Player.ABloopState !== Player.ABLOOP_STATE_NONE
                onToggled: Player.toggleABloopState()
            }

            PanelToggleRow {
                Layout.topMargin: VLCStyle.spacing_8
                Layout.leftMargin: VLCStyle.spacing_20
                Layout.rightMargin: VLCStyle.spacing_20
                label: qsTr("Repeat")
                checked: MainPlaylistController.repeatMode !== PlaylistController.PLAYBACK_REPEAT_NONE
                onToggled: MainPlaylistController.toggleRepeatMode()
            }

            PanelToggleRow {
                Layout.topMargin: VLCStyle.spacing_8
                Layout.leftMargin: VLCStyle.spacing_20
                Layout.rightMargin: VLCStyle.spacing_20
                label: qsTr("Shuffle")
                checked: MainPlaylistController.random
                onToggled: MainPlaylistController.toggleRandom()
            }

            PanelToggleRow {
                Layout.topMargin: VLCStyle.spacing_8
                Layout.leftMargin: VLCStyle.spacing_20
                Layout.rightMargin: VLCStyle.spacing_20
                label: qsTr("Always on Top")
                checked: MainCtx.interfaceAlwaysOnTop
                onToggled: MainCtx.interfaceAlwaysOnTop = !MainCtx.interfaceAlwaysOnTop
            }

            Rectangle {
                Layout.topMargin: VLCStyle.spacing_12
                Layout.fillWidth: true
                implicitHeight: VLCStyle.dp(1, VLCStyle.scale)
                color: popupTheme.separator
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: VLCStyle.spacing_8

                FooterLink {
                    enabled: Player.hasVideoOutput
                    text: qsTr("Picture in Picture")
                    iconName: "PiP"
                    onClicked: {
                        root.close()
                        MainCtx.interfaceAlwaysOnTop = true
                        MainCtx.minimalView = true
                    }
                }

                FooterLink {
                    enabled: Player.isStarted
                    text: qsTr("Snapshot")
                    iconName: "snapshot"
                    onClicked: {
                        root.close()
                        Player.snapshot()
                    }
                }
            }

            FooterLink {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: VLCStyle.spacing_12

                text: qsTr("More Settings…")
                iconName: "settings"
                onClicked: {
                    root.close()
                    root.requestMoreSettings()
                }
            }
        }
    }
}
