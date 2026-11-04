
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
import VLC.Widgets as Widgets
import VLC.Util

// Wide equalizer (Figma 3178:16769): a second floating panel to the left of
// the settings panel with the preamp and the ten bands as vertical sliders,
// each with its frequency and an editable dB chip.
T.Popup {
    id: root

    // the panel it floats next to
    property var anchorPanel: null

    property bool wanted: false

    onWantedChanged: wanted ? open() : close()
    onClosed: wanted = false

    readonly property var params: [PlayerEffects.preamp].concat(PlayerEffects.bands)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    readonly property ColorContext _window: ColorContext {
        id: windowTheme
        colorSet: ColorContext.View
        palette: theme.palette
    }

    width: Math.min(VLCStyle.dp(824, VLCStyle.scale), anchorPanel ? anchorPanel.x - 2 * VLCStyle.popoverPanel_margin : VLCStyle.dp(824, VLCStyle.scale))
    height: VLCStyle.dp(585, VLCStyle.scale)

    x: anchorPanel ? anchorPanel.x - width - VLCStyle.popoverPanel_margin : 0
    y: anchorPanel ? anchorPanel.y + anchorPanel.height - height : 0

    padding: 0
    closePolicy: T.Popup.CloseOnEscape

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long }
            NumberAnimation { target: slide; property: "x"; from: VLCStyle.spacing_12; to: 0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
        }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_short }
    }

    background: null

    contentItem: Item {
        readonly property ColorContext colorContext: ColorContext {
            colorSet: theme.colorSet
            palette: theme.palette
        }

        transform: Translate { id: slide }

        Rectangle {
            anchors.fill: parent
            radius: VLCStyle.radius_l
            color: theme.bg.primary
            opacity: 0.95

            Widgets.RoundedRectangleShadow {
                z: -1
                blurRadius: VLCStyle.shadow_floating.blur
                yOffset: VLCStyle.shadow_floating.y
                color: VLCStyle.shadowColor(VLCStyle.shadow_floating.alpha)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: VLCStyle.spacing_20
            spacing: VLCStyle.spacing_20

            // collapsed look of the bar, kept for the Figma layout: closes the panel
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

                radius: VLCStyle.radius_m
                color: windowTheme.bg.secondary

                Row {
                    anchors.centerIn: parent
                    spacing: VLCStyle.spacing_8

                    Widgets.LabelExt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Open Equalizer")
                        font.pixelSize: VLCStyle.text_body
                        color: windowTheme.fg.secondary
                    }

                    Widgets.SvgIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron-down"
                        size: VLCStyle.icon_normal
                        color: windowTheme.fg.secondary
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                radius: VLCStyle.radius_m
                color: windowTheme.bg.primary

                MouseArea {
                    id: closeArea

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: VLCStyle.dp(36, VLCStyle.scale)

                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.wanted = false

                    Row {
                        anchors.centerIn: parent
                        spacing: VLCStyle.spacing_8

                        Widgets.LabelExt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Close Equalizer")
                            font.pixelSize: VLCStyle.text_body
                            color: windowTheme.fg.secondary
                        }

                        Widgets.SvgIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevron-down"
                            size: VLCStyle.icon_normal
                            color: windowTheme.fg.secondary
                        }
                    }
                }

                RowLayout {
                    anchors.top: closeArea.bottom
                    anchors.topMargin: VLCStyle.dp(19, VLCStyle.scale)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: VLCStyle.spacing_20
                    anchors.rightMargin: VLCStyle.spacing_20

                    spacing: 0

                    Repeater {
                        model: root.params

                        ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: VLCStyle.spacing_12

                            EqVerticalSlider {
                                Layout.alignment: Qt.AlignHCenter
                                param: modelData
                                Accessible.name: modelData.label
                            }

                            Widgets.LabelExt {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: VLCStyle.dp(21, VLCStyle.scale)

                                text: modelData.label
                                font.pixelSize: VLCStyle.text_caption
                                color: windowTheme.fg.secondary
                            }

                            ValueField {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: VLCStyle.dp(60, VLCStyle.scale)
                                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                                horizontalAlignment: Text.AlignHCenter

                                leftPadding: VLCStyle.spacing_4
                                rightPadding: VLCStyle.spacing_4

                                value: Number(modelData.value)
                                unit: modelData.unit
                                from: modelData.from
                                to: modelData.to
                                onCommitted: (v) => modelData.value = v
                            }
                        }
                    }
                }
            }
        }
    }
}
