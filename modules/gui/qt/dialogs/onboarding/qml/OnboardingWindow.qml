/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// First-run window (Figma "Onboarding", 1090x759 card). The window is a bit larger
// than the card so the card shadow is not clipped: the Figma frame is 1114x783,
// card at (12, 8).
Window {
    id: root

    // --- layout constants from the Figma frame
    readonly property real cardWidth: dp(1090)
    readonly property real cardHeight: dp(759)
    readonly property real marginLeft: dp(12)
    readonly property real marginTop: dp(8)

    readonly property int stepCount: 3
    property int step: controller.initialStep

    // true once the user finished the flow (closing earlier keeps asking on next start)
    property bool finished: false

    signal unload()

    function dp(v) { return v * VLCStyle.scale }

    function open() {
        // centre on the main window's screen (a frameless window has no platform placement)
        const parentWin = MainCtx.intfMainWindow
        if (parentWin) {
            // centre on the screen holding the main window
            const cx = parentWin.x + parentWin.width / 2
            const cy = parentWin.y + parentWin.height / 2
            for (const scr of Qt.application.screens) {
                if (cx >= scr.virtualX && cx < scr.virtualX + scr.width
                        && cy >= scr.virtualY && cy < scr.virtualY + scr.height) {
                    x = scr.virtualX + (scr.width - width) / 2
                    y = scr.virtualY + Math.max(0, (scr.height - height) / 2)
                    break
                }
            }
        }
        show()
        raise()
        requestActivate()
    }

    function next() {
        if (step < stepCount - 1)
            step++
        else
            finish()
    }

    function back() {
        if (step > 0)
            step--
        else
            close()
    }

    function skip() {
        controller.skip()
        finished = true
        close()
    }

    function finish() {
        controller.finish(welcomeStep.metadataAccess)
        finished = true
        close()
    }

    title: qsTr("Welcome to VLC!")

    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    modality: Qt.ApplicationModal

    width: cardWidth + marginLeft * 2
    height: marginTop + cardHeight + dp(16)

    onClosing: unload()

    OnboardingController {
        id: controller
        ctx: MainCtx

        Component.onCompleted: {
            // The designs start on Dark with the accent preselected; apply it right away so
            // the preview and the window reflect it.
            if (colorSchemeIndex === 0)
                colorSchemeIndex = 2
        }
    }

    Rectangle {
        id: card

        x: root.marginLeft
        y: root.marginTop
        width: root.cardWidth
        height: root.cardHeight

        radius: VLCStyle.radius_xl
        color: theme.bg.primary

        // palette for everything inside the card (ColorContext inherits from a direct child of an ancestor item)
        ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.Pane
        }

        Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }

        Widgets.RoundedRectangleShadow {
            blurRadius: root.dp(11.8)
            yOffset: root.dp(4)
            color: VLCStyle.shadowColor(0.38)
        }

        // keyboard: Enter = next, Esc = back
        FocusScope {
            id: keyScope
            anchors.fill: parent
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.next()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    root.back()
                    event.accepted = true
                }
            }

            Item {
                id: stepArea
                anchors.fill: parent
                clip: true

                component Slot : Item {
                    id: slot
                    required property int index
                    readonly property bool current: root.step === index
                    readonly property real direction: (root.step > index) ? -1 : 1

                    width: stepArea.width
                    height: stepArea.height

                    opacity: current ? 1 : 0
                    visible: opacity > 0
                    x: current ? 0 : direction * root.dp(24)
                    enabled: current

                    Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.OutCubic } }
                }

                Slot {
                    index: 0
                    WelcomeStep {
                        id: welcomeStep
                        anchors.fill: parent
                        controller: controller
                        active: root.step === 0
                    }
                }

                Slot {
                    index: 1
                    ThemeStep {
                        anchors.fill: parent
                        controller: controller
                        active: root.step === 1
                    }
                }

                Slot {
                    index: 2
                    ShortcutsStep {
                        anchors.fill: parent
                    }
                }
            }

            // Navigation buttons are shared by all steps (bottom 56, right 62, 100x32)
            Widgets.DialogButton {
                id: nextButton

                x: card.width - root.dp(62) - width
                y: card.height - root.dp(56) - height

                kind: Widgets.DialogButton.Accent
                text: (root.step === root.stepCount - 1) ? qsTr("Finish") : qsTr("Next")
                focus: true

                onClicked: root.next()
            }

            // Skip: leave the wizard now (nothing is added, it is not shown again)
            Widgets.DialogButton {
                id: skipButton

                // bottom strip, below the Back / Next row (the theme step has swatches on that row)
                x: root.dp(62)
                y: card.height - root.dp(8) - height

                text: qsTr("Skip")

                visible: root.step < root.stepCount - 1
                onClicked: root.skip()
            }

            // step dots
            Row {
                id: dots

                anchors.horizontalCenter: parent.horizontalCenter
                y: skipButton.y + (skipButton.height - height) / 2
                spacing: VLCStyle.spacing_8

                Repeater {
                    model: root.stepCount

                    delegate: Rectangle {
                        required property int index

                        readonly property bool current: root.step === index

                        width: current ? VLCStyle.spacing_20 : VLCStyle.spacing_8
                        height: VLCStyle.spacing_8
                        radius: height / 2
                        color: current ? theme.accent : theme.fg.disabled

                        Behavior on width { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }
                    }
                }

                Accessible.role: Accessible.ProgressBar
                Accessible.name: qsTr("Step %1 of %2").arg(root.step + 1).arg(root.stepCount)
            }

            Widgets.DialogButton {
                id: backButton

                x: nextButton.x - root.dp(8) - width
                y: nextButton.y

                text: qsTr("Back")
                font.pixelSize: VLCStyle.text_heading

                opacity: root.step > 0 ? 1 : 0
                visible: opacity > 0
                enabled: root.step > 0
                Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_long } }

                onClicked: root.back()
            }
        }

        // drag the frameless window by its empty area
        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            onActiveChanged: if (active) root.startSystemMove()
        }
    }
}
