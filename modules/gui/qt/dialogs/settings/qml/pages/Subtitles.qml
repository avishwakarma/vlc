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


// Subtitle settings. Figma 3180:17989 (advanced 6536:13908).
//
// Figma row                                  -> VLC option
//   Enable subtitles                         -> spu
//   Preferred language                       -> sub-language
//   Text encoding                            -> subsdec-encoding
//   Load subtitle files automatically        -> sub-autodetect-file
//   File name matching                       -> sub-autodetect-fuzzy
//   Font                                     -> freetype-font
//   Size values (Relative / Pixels)          -> (omitted: freetype-rel-fontsize and freetype-fontsize are
//                                               obsolete in 4.0, only the relative sub-text-scale exists)
//   Font size                                -> sub-text-scale (percent, Smaller .. Larger)
//   Bold                                     -> freetype-bold
//   Text color / Text opacity                -> freetype-color / freetype-opacity (0-255 shown as %)
//   Outline thickness / Outline color        -> freetype-outline-thickness / freetype-outline-color
//   Shadow                                   -> freetype-shadow-opacity (128 = on, 0 = off, as the classic prefs)
//   Timing: Subtitle delay                   -> sub-delay
//   Subtitle margin                          -> sub-margin
//   On-Screen Messages                       -> osd, video-title-show, video-title-timeout
//   Ignore ASS/SSA styling, Show feedback duration -> (omitted: no option)

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets

SettingsPage {
    id: page

    // common ISO 639 languages; "" keeps VLC's default (the system language)
    readonly property var languages: [
        { value: "", text: qsTr("System language") },
        { value: "en", text: qsTr("English") },
        { value: "fr", text: qsTr("French") },
        { value: "de", text: qsTr("German") },
        { value: "es", text: qsTr("Spanish") },
        { value: "it", text: qsTr("Italian") },
        { value: "pt", text: qsTr("Portuguese") },
        { value: "nl", text: qsTr("Dutch") },
        { value: "sv", text: qsTr("Swedish") },
        { value: "pl", text: qsTr("Polish") },
        { value: "ru", text: qsTr("Russian") },
        { value: "tr", text: qsTr("Turkish") },
        { value: "ar", text: qsTr("Arabic") },
        { value: "hi", text: qsTr("Hindi") },
        { value: "zh", text: qsTr("Chinese") },
        { value: "ja", text: qsTr("Japanese") },
        { value: "ko", text: qsTr("Korean") }
    ]

    // hex field + swatch, the Figma colour row; the swatch opens the presets of the option
    component ColorField: FocusScope {
        id: colorField

        property ConfigOption option: null
        property string label: ""

        implicitWidth: VLCStyle.dp(320, VLCStyle.scale)
        implicitHeight: VLCStyle.input_h

        readonly property string hex: option && option.value ? String(option.value).toUpperCase() : "#000000"

        Widgets.TextFieldExt {
            id: field

            anchors.fill: parent
            rightPadding: swatch.width + 2 * VLCStyle.spacing_10
            text: colorField.hex
            selectByMouse: true
            maximumLength: 7
            inputMethodHints: Qt.ImhNoPredictiveText
            validator: RegularExpressionValidator { regularExpression: /^#[0-9A-Fa-f]{6}$/ }
            onEditingFinished: if (acceptableInput) colorField.option.value = text.toUpperCase()

            Accessible.name: colorField.label
        }

        Rectangle {
            id: swatch

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.spacing_6
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(22, VLCStyle.scale)
            height: width
            radius: VLCStyle.radius_xxs
            color: colorField.hex
            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: Qt.darker(color, 1.6)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: colorField.option && colorField.option.choices.length > 0
                onClicked: presetPopup.open()
            }
        }

        Popup {
            id: presetPopup

            y: colorField.height + VLCStyle.spacing_4
            x: colorField.width - width
            padding: VLCStyle.spacing_6

            readonly property ColorContext colorContext: ColorContext {
                id: popupTheme
                colorSet: ColorContext.Window
            }

            background: Rectangle {
                radius: VLCStyle.radius_m
                color: popupTheme.bg.primary
                border.width: VLCStyle.border
                border.color: popupTheme.border
            }

            contentItem: Grid {
                columns: 6
                spacing: VLCStyle.spacing_4

                Repeater {
                    model: colorField.option ? colorField.option.choices : []

                    delegate: Rectangle {
                        required property var modelData

                        width: VLCStyle.dp(22, VLCStyle.scale)
                        height: width
                        radius: VLCStyle.radius_xxs
                        color: modelData.value
                        border.width: VLCStyle.dp(1, VLCStyle.scale)
                        border.color: Qt.darker(color, 1.6)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                colorField.option.value = modelData.value
                                presetPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }

    SettingSection {
        title: qsTr("Tracks & Languages")

        SettingRow {
            label: qsTr("Enable subtitles")
            option: SettingsModel.option("spu")
        }

        SettingRow {
            label: qsTr("Preferred language")
            option: SettingsModel.option("sub-language")
            kind: "dropdown"
            choices: page.languages
        }

        SettingRow {
            label: qsTr("Text encoding")
            option: SettingsModel.option("subsdec-encoding")
        }
    }

    SettingSection {
        title: qsTr("Loading Subtitles")

        SettingRow {
            id: autoLoad

            label: qsTr("Load subtitle files automatically")
            option: SettingsModel.option("sub-autodetect-file")
        }

        SettingRow {
            label: qsTr("File name matching")
            option: SettingsModel.option("sub-autodetect-fuzzy")
            kind: "dropdown"
            choices: [
                { value: 0, text: qsTr("Off") },
                { value: 1, text: qsTr("Any subtitle file") },
                { value: 2, text: qsTr("Title anywhere in the name") },
                { value: 3, text: qsTr("Title with extra characters") },
                { value: 4, text: qsTr("Exact title") }
            ]
            dependsOn: autoLoad.option
        }
    }

    SettingSection {
        title: qsTr("Appearance")

        SettingRow {
            label: qsTr("Font")
            option: SettingsModel.option("freetype-font")
            kind: "text"
        }

        SettingRow {
            label: qsTr("Font size")
            option: SettingsModel.option("sub-text-scale")
            kind: "dropdown"
            choices: [
                { value: 75, text: qsTr("Small") },
                { value: 100, text: qsTr("Normal") },
                { value: 150, text: qsTr("Large") },
                { value: 200, text: qsTr("Larger") }
            ]
        }

        SettingRow {
            label: qsTr("Bold")
            info: ""
            option: SettingsModel.option("freetype-bold")
        }

        SettingRow {
            id: textColor

            label: qsTr("Text color")
            info: ""
            option: SettingsModel.option("freetype-color")
            kind: "custom"
            customControl: Component {
                ColorField {
                    option: textColor.option
                    label: textColor.label
                }
            }
        }

        SettingRow {
            label: qsTr("Text opacity")
            info: ""
            option: SettingsModel.option("freetype-opacity")
            kind: "slider"
            valueScale: 100 / 255
            from: 0
            to: 100
            stepSize: 10
            suffix: "%"
            ticks: true
        }

        SettingRow {
            label: qsTr("Outline thickness")
            info: ""
            option: SettingsModel.option("freetype-outline-thickness")
            kind: "dropdown"
            choices: [
                { value: 0, text: qsTr("None") },
                { value: 2, text: qsTr("Thin") },
                { value: 4, text: qsTr("Normal") },
                { value: 6, text: qsTr("Thick") }
            ]
        }

        SettingRow {
            id: outlineColor

            label: qsTr("Outline color")
            info: ""
            option: SettingsModel.option("freetype-outline-color")
            kind: "custom"
            customControl: Component {
                ColorField {
                    option: outlineColor.option
                    label: outlineColor.label
                }
            }
        }

        SettingRow {
            label: qsTr("Shadow")
            info: ""
            option: SettingsModel.option("freetype-shadow-opacity")
            kind: "toggle"
            valueOn: 128
            valueOff: 0
        }
    }

    advanced: [
        SettingSection {
            title: qsTr("Timing")

            SettingRow {
                label: qsTr("Subtitle delay")
                option: SettingsModel.option("sub-delay")
                kind: "number"
            }

            SettingRow {
                label: qsTr("Subtitle margin")
                option: SettingsModel.option("sub-margin")
            }
        },

        SettingSection {
            title: qsTr("On-Screen Messages")

            SettingRow {
                label: qsTr("Show on-screen messages")
                option: SettingsModel.option("osd")
            }

            SettingRow {
                label: qsTr("Show the media title on start")
                option: SettingsModel.option("video-title-show")
            }

            SettingRow {
                label: qsTr("Title display time")
                option: SettingsModel.option("video-title-timeout")
                suffix: "ms"
            }
        }
    ]
}
