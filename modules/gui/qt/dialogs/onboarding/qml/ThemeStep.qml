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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// Step 2: theme tiles + accent swatches + live preview (Figma 1902:3670 and accent variants)
FocusScope {
    id: root

    required property OnboardingController controller
    property bool active: false

    function dp(v) { return v * VLCStyle.scale }

    // ColorSchemeModel indexes: 1 Day, 2 Night, 3 Auto (System)
    readonly property var tiles: [
        { label: qsTr("Light"),  scheme: 1, color: "#AFAFAF" },
        { label: qsTr("Dark"),   scheme: 2, color: "#222222" },
        { label: qsTr("System"), scheme: 3, color: "#AFAFAF" }
    ]

    onActiveChanged: if (active) tileRow.forceActiveFocus()

    ColorContext {
        id: viewTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    ThemePreview {
        x: root.dp(17)
        y: root.dp(19)
    }

    Text {
        x: (root.width - width) / 2
        y: root.dp(173)
        text: qsTr("Select your preferred theme and color.")
        color: viewTheme.fg.primary
        font.pixelSize: VLCStyle.text_title
        font.weight: VLCStyle.fontWeight_light
        font.letterSpacing: font.pixelSize * 0.027
        lineHeightMode: Text.FixedHeight
        lineHeight: font.pixelSize * 1.75
        // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
        transform: Translate { y: VLCStyle.text_title * 0.27 }
    }

    // Light / Dark / System tiles (116 box, swatch 100, radius 12; selected ring 4 px, radius 19)
    FocusScope {
        id: tileRow
        x: 0
        y: root.dp(286)
        width: root.width
        height: root.dp(8 + 100 + 8 + 22 + 20)
        activeFocusOnTab: true

        readonly property int currentTile: {
            const i = root.controller.colorSchemeIndex
            return (i >= 1 && i <= 3) ? i - 1 : 2
        }

        Keys.onLeftPressed: root.controller.colorSchemeIndex = root.tiles[Math.max(0, currentTile - 1)].scheme
        Keys.onRightPressed: root.controller.colorSchemeIndex = root.tiles[Math.min(2, currentTile + 1)].scheme

        Repeater {
            model: root.tiles

            delegate: Item {
                id: tile

                required property int index
                required property var modelData

                readonly property bool selected: tileRow.currentTile === index
                readonly property bool hovered: mouse.containsMouse

                x: root.dp(331 + 156 * index)
                width: root.dp(116)
                height: tileRow.height

                // selection / hover / focus ring
                Rectangle {
                    x: -root.dp(4)
                    y: -root.dp(4)
                    width: root.dp(124)
                    height: width
                    radius: root.dp(19)
                    color: "transparent"
                    border.width: root.dp(4)
                    border.color: tile.selected ? swatchTheme.accent
                                                : Qt.alpha(swatchTheme.accent, 0.3)
                    opacity: (tile.selected || tile.hovered) ? 1 : 0
                    scale: tile.selected ? 1 : 0.96

                    Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                    Behavior on scale { NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: VLCStyle.duration_short } }
                }

                // keyboard focus
                Rectangle {
                    x: -root.dp(6)
                    y: -root.dp(6)
                    width: root.dp(128)
                    height: width
                    radius: root.dp(21)
                    color: "transparent"
                    border.width: VLCStyle.dp(1, VLCStyle.scale)
                    border.color: swatchTheme.visualFocus
                    visible: tileRow.activeFocus && tile.selected
                }

                // the swatches depict the schemes, so they do not follow the current palette
                Rectangle {
                    x: root.dp(8)
                    y: root.dp(8)
                    width: root.dp(100)
                    height: width
                    radius: root.dp(12)
                    color: tile.modelData.color

                    Canvas {
                        // "System": split diagonally (Figma gradient 238.7deg, hard stop at 52.4%),
                        // dark half bottom-left
                        visible: tile.modelData.scheme === 3
                        anchors.fill: parent
                        renderTarget: Canvas.Image

                        onWidthChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            const w = width, h = height, r = parent.radius
                            ctx.reset()
                            ctx.beginPath()
                            ctx.moveTo(r, 0); ctx.lineTo(w - r, 0); ctx.arcTo(w, 0, w, r, r)
                            ctx.lineTo(w, h - r); ctx.arcTo(w, h, w - r, h, r)
                            ctx.lineTo(r, h); ctx.arcTo(0, h, 0, h - r, r)
                            ctx.lineTo(0, r); ctx.arcTo(0, 0, r, 0, r)
                            ctx.closePath()
                            ctx.clip()
                            ctx.fillStyle = tile.modelData.color
                            ctx.fillRect(0, 0, w, h)
                            ctx.fillStyle = root.tiles[1].color
                            ctx.beginPath()
                            ctx.moveTo(0, 0); ctx.lineTo(w * 0.158, 0)
                            ctx.lineTo(w * 0.765, h); ctx.lineTo(0, h)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.dp(8 + 100 + 8 + 19)
                    text: tile.modelData.label
                    color: viewTheme.fg.primary
                    font.pixelSize: VLCStyle.text_heading
                    font.weight: VLCStyle.fontWeight_light
                    Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
                }

                ColorContext {
                    id: swatchTheme
                    palette: VLCStyle.palette
                    colorSet: ColorContext.ButtonAccent
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tileRow.forceActiveFocus()
                        root.controller.colorSchemeIndex = tile.modelData.scheme
                    }
                }
            }
        }
    }

    // accent swatches
    Row {
        id: swatchRow
        x: root.dp(41)
        y: root.dp(655)
        spacing: root.dp(16)

        Repeater {
            model: MainCtx.accentPresets

            delegate: Item {
                id: swatch

                required property int index
                required property string modelData

                readonly property bool selected: Qt.colorEqual(MainCtx.accentColor, modelData)

                width: root.dp(64)
                height: width

                activeFocusOnTab: false

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: root.dp(4)
                    border.color: Qt.alpha(swatch.modelData, 0.3)
                    opacity: swatch.selected ? 1 : 0
                    scale: swatch.selected ? 1 : 0.8
                    Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                    Behavior on scale { NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.dp(40)
                    height: width
                    radius: width / 2
                    color: swatch.modelData
                    opacity: swatch.selected ? 1 : (swatchMouse.containsMouse ? 0.75 : 0.5)
                    Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                }

                MouseArea {
                    id: swatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MainCtx.accentColor = swatch.modelData
                }
            }
        }
    }
}
