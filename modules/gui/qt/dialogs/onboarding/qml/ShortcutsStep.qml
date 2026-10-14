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
import VLC.Style

// Step 3: basic keyboard shortcuts (Figma 1902:6770). Static key caps: the labels
// show VLC's default bindings.
Item {
    id: root

    function dp(v) { return v * VLCStyle.scale }

    // a key is [text] or [text, true] for narrow keys (12 px padding); "/" is a separator
    readonly property var leftColumn: [
        { label: qsTr("Play / Pause"),            keys: [["Space"]] },
        { label: qsTr("Seek Backward / Forward"), keys: [["←", true], ["/"], ["→", true]] },
        { label: qsTr("Previous / Next Item"),    keys: [["<", true], ["/"], [">", true]] },
        { label: qsTr("Previous / Next Frame"),   keys: [[",", true], ["/"], [".", true]] },
        { label: qsTr("Cycle Subtitle Track"),    keys: [["V"]] },
        { label: qsTr("Cycle Audio Track"),       keys: [["B"]] }
    ]

    readonly property var rightColumn: [
        { label: qsTr("Toggle Fullscreen"),         keys: [["F"]] },
        { label: qsTr("Increase / Decrease Volume"), keys: [["↑", true], ["/"], ["↓", true]] },
        { label: qsTr("Show / Hide Queue"),         keys: [["Q"]] },
        { label: qsTr("Show / Hide File Browser"),  keys: [["L"]] },
        { label: qsTr("Take a Snapshot"),           keys: [["SHIFT"], ["S"]] },
        { label: qsTr("Record"),                    keys: [["SHIFT"], ["R"]] }
    ]

    ColorContext {
        id: viewTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    Text {
        x: (root.width - width) / 2
        y: root.dp(60)
        text: qsTr("Learn the basic keyboard shortcuts.")
        color: viewTheme.fg.primary
        font.pixelSize: VLCStyle.text_title
        font.weight: VLCStyle.fontWeight_regular
        font.letterSpacing: font.pixelSize * 0.02
        lineHeightMode: Text.FixedHeight
        lineHeight: font.pixelSize * 1.75
        // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
        transform: Translate { y: VLCStyle.text_title * 0.27 }
    }

    Text {
        x: root.dp(62)
        y: root.dp(671)
        text: qsTr("Find the full list in the menu.")
        color: viewTheme.fg.secondary
        font.pixelSize: VLCStyle.text_heading
        font.weight: VLCStyle.fontWeight_regular
        lineHeightMode: Text.FixedHeight
        lineHeight: font.pixelSize * 1.75
        // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
        transform: Translate { y: VLCStyle.text_heading * 0.27 }
    }

    component ShortcutColumn : Item {
        id: column

        property var rows: []

        width: root.dp(220 + 20 + 153)
        height: root.dp(452)

        Repeater {
            model: column.rows

            delegate: Item {
                id: row

                required property int index
                required property var modelData

                y: root.dp(82) * index
                width: column.width
                height: root.dp(42)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.dp(220)
                    text: row.modelData.label
                    color: viewTheme.fg.primary
                    font.pixelSize: VLCStyle.text_heading
                    font.weight: VLCStyle.fontWeight_light
                    font.letterSpacing: font.pixelSize * 0.0075
                    lineHeightMode: Text.FixedHeight
                    lineHeight: font.pixelSize * 1.75
                    // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
                    transform: Translate { y: VLCStyle.text_heading * 0.27 }
                }

                Row {
                    x: root.dp(220 + 20)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: (row.modelData.keys.length === 2 && row.modelData.keys[0][0] === "SHIFT")
                             ? root.dp(4) : root.dp(10)

                    Repeater {
                        model: row.modelData.keys

                        delegate: Loader {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter

                            sourceComponent: (modelData[0] === "/") ? slash : cap

                            Component {
                                id: cap
                                KeyCap {
                                    text: modelData[0]
                                    hPadding: modelData[1] ? VLCStyle.spacing_12 : VLCStyle.spacing_20
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: slash
        Text {
            text: "/"
            color: viewTheme.fg.primary
            font.pixelSize: VLCStyle.text_heading
            font.weight: VLCStyle.fontWeight_light
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize * 1.75
            // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
            transform: Translate { y: VLCStyle.text_heading * 0.27 }
        }
    }

    ShortcutColumn {
        x: root.dp(62)
        y: root.dp(154)
        rows: root.leftColumn
    }

    ShortcutColumn {
        x: root.dp(62 + 220 + 20 + 153 + 150)
        y: root.dp(154)
        rows: root.rightColumn
    }
}
