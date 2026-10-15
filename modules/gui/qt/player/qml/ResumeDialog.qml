/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import VLC.Util

// "Resume where you left off?" pill, centered at the bottom of the video just above
// the control bar: [message] [Continue at 1:30] [Start over] [x]
// Auto dismisses after 10 s (playback then continues from the start).
FocusScope {
    id: resumePanel

    // width available to the pill
    property int maxWidth

    // saved position as a time ("1:30", "1:02:03")
    readonly property string resumeTime: {
        const len = Player.length
        if (!len || !len.valid())
            return ""
        const secs = Math.max(0, Math.round(len.toSeconds() * Player.restorePosition))
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        const sec = secs % 60
        const two = (n) => (n < 10 ? "0" : "") + n
        return h > 0 ? (h + ":" + two(m) + ":" + two(sec)) : (m + ":" + two(sec))
    }

    implicitHeight: surface.height
    implicitWidth: Math.min(surface.implicitWidth, maxWidth)

    opacity: 0
    visible: opacity > 0
    enabled: shown

    property bool shown: false

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    function showResumePanel ()
    {
        shown = true
        continueBtn.forceActiveFocus()
        resumeTimeout.restart()
    }

    function hideResumePanel() {
        resumeTimeout.stop()
        shown = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    Timer {
        id: resumeTimeout
        interval: 10000
        onTriggered: {
            resumePanel.shown = false
            resumePanel.hidden()
        }
    }

    Connections {
        target: Player
        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback) {
                showResumePanel()
            } else {
                hideResumePanel()
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Menu
    }

    Component.onCompleted: {
        if (Player.canRestorePlayback) {
            showResumePanel()
        }
    }

    // fade + slide in
    states: State {
        name: "shown"
        when: resumePanel.shown
        PropertyChanges { target: resumePanel; opacity: 1 }
        PropertyChanges { target: slide; y: 0 }
    }

    transitions: Transition {
        NumberAnimation { properties: "opacity,y"; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
    }

    Navigation.cancelAction: function() {
        hideResumePanel()
    }

    Keys.onReturnPressed: continueBtn.clicked()
    Keys.onEnterPressed: continueBtn.clicked()

    Item {
        id: surface

        readonly property real implicitWidth: row.implicitWidth + 2 * VLCStyle.spacing_12

        width: resumePanel.implicitWidth
        height: row.implicitHeight + 2 * VLCStyle.spacing_8

        transform: Translate { id: slide; y: VLCStyle.spacing_12 }

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
                color: Qt.rgba(0, 0, 0, VLCStyle.shadow_floating.alpha)
            }
        }

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.leftMargin: VLCStyle.spacing_12
            anchors.rightMargin: VLCStyle.spacing_8
            spacing: VLCStyle.spacing_8

            T.Label {
                id: label

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: implicitWidth

                text: qsTr("Resume where you left off?")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
                elide: Text.ElideRight
            }

            Widgets.ButtonExt {
                id: continueBtn

                Layout.alignment: Qt.AlignVCenter

                buttonStyle: Widgets.ButtonExt.Accent
                text: resumePanel.resumeTime !== "" ? qsTr("Continue at %1").arg(resumePanel.resumeTime)
                                                    : qsTr("Continue")

                AccessibleCompat.id: "resumeContinueButton"

                font.bold: true
                focus: true
                onClicked: {
                    Player.restorePlaybackPos()
                    resumePanel.hideResumePanel()
                }

                Navigation.parentItem: resumePanel
                Navigation.rightItem: startOverBtn
            }

            Widgets.ButtonExt {
                id: startOverBtn

                Layout.alignment: Qt.AlignVCenter

                buttonStyle: Widgets.ButtonExt.Secondary
                text: qsTr("Start over")

                AccessibleCompat.id: "resumeDismissButton"

                onClicked: resumePanel.hideResumePanel()

                Navigation.parentItem: resumePanel
                Navigation.leftItem: continueBtn
                Navigation.rightItem: closeBtn
            }

            Widgets.ButtonExt {
                id: closeBtn

                Layout.alignment: Qt.AlignVCenter

                iconTxt: VLCIcons.close
                iconSize: VLCStyle.icon_small
                color: theme.fg.secondary

                Accessible.name: qsTr("Dismiss")
                AccessibleCompat.id: "resumeCloseButton"

                onClicked: resumePanel.hideResumePanel()

                Navigation.parentItem: resumePanel
                Navigation.leftItem: startOverBtn
            }
        }
    }
}
