
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

import VLC.Style
import VLC.Player
import VLC.Dialogs
import VLC.Widgets as Widgets

// Settings > Playback (Figma 2238:9432): toggles, sleep timer, audio
// visualizer and the playback speed.
SettingsTabBase {
    id: root

    topPad: VLCStyle.dp(11, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property var sleepChoices: [
        { text: qsTr("Off"), minutes: 0 },
        { text: qsTr("15 minutes"), minutes: 15 },
        { text: qsTr("30 minutes"), minutes: 30 },
        { text: qsTr("45 minutes"), minutes: 45 },
        { text: qsTr("1 hour"), minutes: 60 },
        { text: qsTr("2 hours"), minutes: 120 }
    ]

    function visualizerIcon(name) {
        const n = name.toLowerCase()
        if (n.indexOf("spectrometer") !== -1) return "spectometer-twotone"
        if (n.indexOf("spectrum") !== -1) return "spectrum-twotone"
        if (n.indexOf("scope") !== -1) return "scope-twotone"
        if (n.indexOf("wave") !== -1) return "waveform-twotone"
        return ""
    }

    PanelRow {
        label: qsTr("Show Subtitle Timeline on Seekbar")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)
        controlWidth: VLCStyle.toggle_w
        unavailableText: qsTr("Not available yet")

        Widgets.CheckButton {
            text: ""
            enabled: false
            opacity: 0.4
        }
    }

    PanelRow {
        label: qsTr("Show Statistics")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)
        controlWidth: VLCStyle.toggle_w

        Widgets.CheckButton {
            text: ""
            checked: DialogsProvider.mediaInfoDialogVisible ?? false
            onToggled: DialogsProvider.mediaInfoDialog()
            Accessible.name: qsTr("Show Statistics")
        }
    }

    PanelRow {
        label: qsTr("Reverse")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)
        controlWidth: VLCStyle.toggle_w
        enabled: Player.rewindable
        opacity: enabled ? 1 : 0.3

        Widgets.CheckButton {
            text: ""
            checked: Player.rate < 0
            onToggled: Player.reverse()
            Accessible.name: qsTr("Reverse")
        }
    }

    PanelRow {
        label: qsTr("Sleep Timer")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)

        EffectsDropdown {
            width: parent.width
            model: root.sleepChoices
            textRole: "text"
            currentIndex: {
                for (let i = 0; i < root.sleepChoices.length; ++i)
                    if (root.sleepChoices[i].minutes === PlayerAux.sleepMinutes)
                        return i
                return 0
            }
            onActivated: (i) => PlayerAux.setSleep(root.sleepChoices[i].minutes)
            Accessible.name: qsTr("Sleep Timer")
        }
    }

    PanelRow {
        label: qsTr("Audio Visualizer")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)

        VarChoiceDropdown {
            width: parent.width
            choiceModel: Player.audioVisualization
            iconFor: root.visualizerIcon
            Accessible.name: qsTr("Audio Visualizer")
        }
    }

    // playback speed
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.spacing_24
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.topMargin: VLCStyle.dp(13, VLCStyle.scale)

        Widgets.LabelExt {
            Layout.fillWidth: true

            text: qsTr("Speed")
            font.pixelSize: VLCStyle.text_body
            color: theme.fg.secondary
        }

        ValueField {
            Layout.preferredWidth: VLCStyle.dp(140, VLCStyle.scale)

            font.pixelSize: VLCStyle.text_body
            horizontalAlignment: Text.AlignLeft
            decimals: 2
            trimZeros: true
            unit: "x"
            from: 0.25
            to: 4
            value: Player.rate
            enabled: Player.ratechangable
            onCommitted: (v) => Player.rate = v
        }
    }

    SpeedSlider {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.leftMargin: VLCStyle.spacing_24
        Layout.rightMargin: VLCStyle.spacing_20
    }
}
