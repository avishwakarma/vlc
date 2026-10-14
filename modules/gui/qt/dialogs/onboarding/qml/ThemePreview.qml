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
import QtQuick.Shapes

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

// Miniature of the player (title bar + control bar of the real 1920x1080 layout scaled to 0.55).
// It uses the real palette, so accent and scheme changes show up immediately.
Item {
    id: root

    // Figma: 1056x594 of a 1920x1080 player
    readonly property real previewScale: 0.55

    width: VLCStyle.dp(1056, VLCStyle.scale)
    height: VLCStyle.dp(594, VLCStyle.scale)
    clip: true

    ColorContext {
        id: paneTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Pane
    }

    ColorContext {
        id: viewTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    ColorContext {
        id: accentTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.ButtonAccent
    }

    ColorContext {
        id: sliderTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Slider
    }

    Rectangle {
        anchors.fill: parent
        color: viewTheme.bg.secondary
        Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }
    }

    Item {
        id: full

        width: root.width / root.previewScale
        height: root.height / root.previewScale
        scale: root.previewScale
        transformOrigin: Item.TopLeft

        // title bar
        Rectangle {
            width: parent.width
            height: VLCStyle.titleBar_height
            color: paneTheme.bg.secondary
            Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }

            Widgets.SvgIcon {
                x: VLCStyle.spacing_14 + VLCStyle.spacing_2
                anchors.verticalCenter: parent.verticalCenter
                name: "vlc"
                size: VLCStyle.icon_normal
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.spacing_6
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.spacing_12

                Repeater {
                    model: ["minimize", "maximize", "fullscreen", "close"]
                    Widgets.SvgIcon {
                        required property string modelData
                        name: modelData
                        size: VLCStyle.icon_normal
                    }
                }
            }
        }

        // control bar
        Rectangle {
            id: bar
            y: parent.height - height
            width: parent.width
            height: VLCStyle.controlBar_height
            color: Qt.alpha(paneTheme.bg.secondary, 0.95)
            Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }

            Rectangle {
                width: parent.width
                height: VLCStyle.dp(1, VLCStyle.scale)
                color: paneTheme.separator
            }

            Row {
                id: left
                x: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.spacing_8

                Widgets.SvgIcon { name: "previous"; size: VLCStyle.icon_normal; anchors.verticalCenter: parent.verticalCenter }

                Rectangle {
                    width: VLCStyle.playButton_w
                    height: VLCStyle.playButton_h
                    radius: VLCStyle.radius_m
                    color: accentTheme.bg.primary
                    Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }

                    Widgets.SvgIcon {
                        anchors.centerIn: parent
                        name: "play"
                        size: VLCStyle.icon_normal
                        color: accentTheme.fg.primary
                    }
                }

                Widgets.SvgIcon { name: "next"; size: VLCStyle.icon_normal; anchors.verticalCenter: parent.verticalCenter }
            }

            Row {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.spacing_12

                Widgets.SvgIcon { name: "volume-high"; size: VLCStyle.icon_normal; anchors.verticalCenter: parent.verticalCenter }

                // volume: wedge-shaped well, fixed green gradient fill (as in the design)
                Item {
                    id: volume
                    width: VLCStyle.volume_w
                    height: VLCStyle.seek_height
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property real leftHeight: height * 0.5
                    readonly property real fillWidth: width * 0.3

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: viewTheme.bg.secondary
                            strokeColor: "transparent"
                            startX: 0; startY: volume.height - volume.leftHeight
                            PathLine { x: volume.width; y: 0 }
                            PathLine { x: volume.width; y: volume.height }
                            PathLine { x: 0; y: volume.height }
                        }

                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 0; y1: 0; x2: volume.fillWidth; y2: 0
                                GradientStop { position: 0; color: "#7AA312" }
                                GradientStop { position: 1; color: "#859513" }
                            }
                            startX: 0; startY: volume.height - volume.leftHeight
                            PathLine { x: volume.fillWidth; y: volume.height - volume.leftHeight - (volume.fillWidth / volume.width) * (volume.height - volume.leftHeight) }
                            PathLine { x: volume.fillWidth; y: volume.height }
                            PathLine { x: 0; y: volume.height }
                        }
                    }
                }

                Item { width: VLCStyle.spacing_8; height: 1 }

                Repeater {
                    model: ["waveform-twotone", "subtitles", "settings", "list"]
                    Widgets.SvgIcon {
                        required property string modelData
                        name: modelData
                        // the waveform glyph is two-tone, the design draws it in the plain icon colour
                        accentColor: color
                        accentDimColor: color
                        size: VLCStyle.icon_normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Text {
                id: current
                anchors.left: left.right
                anchors.leftMargin: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                text: "00:02:10"
                color: viewTheme.fg.primary
                font.pixelSize: VLCStyle.text_time
            }

            Text {
                id: duration
                anchors.right: right.left
                anchors.rightMargin: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                text: "00:25:40"
                color: viewTheme.fg.primary
                font.pixelSize: VLCStyle.text_time
            }

            // seek bar
            Rectangle {
                id: track
                anchors.left: current.right
                anchors.leftMargin: VLCStyle.spacing_20
                anchors.right: duration.left
                anchors.rightMargin: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                height: VLCStyle.seek_height
                radius: VLCStyle.radius_m
                color: viewTheme.bg.secondary

                Rectangle {
                    x: VLCStyle.spacing_2
                    y: VLCStyle.spacing_2
                    width: track.width * 0.0814
                    height: parent.height - VLCStyle.spacing_4
                    radius: VLCStyle.radius_s
                    color: sliderTheme.fg.primary
                    Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }

                    Rectangle {
                        anchors.right: parent.right
                        width: VLCStyle.spacing_8
                        height: parent.height
                        radius: VLCStyle.radius_s
                        color: accentTheme.bg.primary
                        Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }
                    }
                }
            }
        }
    }
}
