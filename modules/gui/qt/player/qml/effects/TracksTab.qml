
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

import VLC.Style
import VLC.Player
import VLC.Dialogs
import VLC.Widgets as Widgets
import VLC.Util

// Tracks tab of the popover (Figma 491:2216 / 496:2495 / 498:2674).
//   kind: "video" | "audio" | "subtitles"
Flickable {
    id: root

    property string kind: "audio"

    // asks the host to switch to the Settings panel (subtitle/audio sync...)
    signal requestSettings(string tab)

    readonly property var tracksModel: kind === "video" ? Player.videoTracks
                                      : kind === "subtitles" ? Player.subtitleTracks
                                      : Player.audioTracks

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // external subtitle files are listed apart from the embedded tracks
    function isExternal(title) {
        return kind === "subtitles" && /\.(srt|ass|ssa|sub|idx|vtt|smi|txt|sup|aqt|jss|rt|usf)(\s|$|\])/i.test(title)
    }

    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    ColumnLayout {
        id: column

        width: root.width
        spacing: 0

        PanelSectionLabel {
            Layout.fillWidth: true
            text: qsTr("Embedded Tracks")
        }

        Repeater {
            model: root.tracksModel

            TrackRow {
                required property var model
                required property int index

                Layout.fillWidth: true
                visible: !root.isExternal(model.display)
                Layout.preferredHeight: visible ? implicitHeight : 0

                text: model.display
                selected: model.checked
                onClicked: model.checked = true
            }
        }

        // audio: output devices
        PanelSectionLabel {
            visible: root.kind === "audio"
            Layout.fillWidth: true

            text: qsTr("Output Device")
            divider: true

            Widgets.IconToolButton {
                iconName: "refresh"
                description: qsTr("Refresh")
                onClicked: PlayerEffects.refresh()
            }
        }

        Repeater {
            model: root.kind === "audio" ? Player.audioDevices : null

            TrackRow {
                required property var model
                required property int index

                Layout.fillWidth: true

                text: model.display
                selected: model.checked
                onClicked: model.checked = true
            }
        }

        // subtitles: external files
        PanelSectionLabel {
            visible: root.kind === "subtitles"
            Layout.fillWidth: true

            text: qsTr("External Tracks")
            divider: true

            Widgets.IconToolButton {
                iconName: "edit"
                description: qsTr("Adjust subtitles")
                onClicked: root.requestSettings("subtitles")
            }

            Widgets.IconToolButton {
                iconName: "add"
                description: qsTr("Add subtitle file")
                onClicked: DialogsProvider.loadSubtitlesFile()
            }
        }

        Repeater {
            model: root.kind === "subtitles" ? Player.subtitleTracks : null

            TrackRow {
                required property var model
                required property int index

                Layout.fillWidth: true
                visible: root.isExternal(model.display)
                Layout.preferredHeight: visible ? implicitHeight : 0

                text: model.display
                selected: model.checked
                onClicked: model.checked = true
            }
        }

        // video: add a video track from a file
        Widgets.SettingButton {
            visible: root.kind === "video"

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: VLCStyle.spacing_12

            text: qsTr("Add video file...")
            iconName: "add"
            onClicked: DialogsProvider.loadVideoFile()
        }
    }
}
