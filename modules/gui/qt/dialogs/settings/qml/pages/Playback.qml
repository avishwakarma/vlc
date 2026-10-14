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


// Playback settings. Figma 3062:12552 (advanced 3072:13408).
//
// Figma row                                  -> VLC option
//   Continue where you left off              -> restore-playback-pos (Never / Always / Ask, as VLC lists them)
//   Start playing as soon as a file opens    -> start-paused (inverted)
//   Default playback speed                   -> rate (0.25 .. 2, 0.25 steps)
//   Pause when another app uses audio        -> (omitted: no option)
//   Preferred video quality                  -> preferred-resolution
//   Preferred menu language                  -> menu-language
//   Default audio track / subtitle track     -> audio-track / sub-track
//   Repeat                                   -> loop (All) + repeat (One), custom dropdown
//   Shuffle                                  -> random
//   Stop after each item                     -> play-and-stop
//   When playback finishes                   -> play-and-exit (Stop / Quit VLC)
//   Seek precisely                           -> input-fast-seek (inverted)
//   Files & Discs                            -> dvd, avi-index, mkv-preload-local-dir
//   Advanced (Time shifting)                 -> input-timeshift-path, input-timeshift-granularity
//   Show thumbnail while scrubbing           -> (omitted: no option)

import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
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

    SettingSection {
        title: qsTr("Startup")

        SettingRow {
            label: qsTr("Continue where you left off")
            option: SettingsModel.option("restore-playback-pos")
        }

        SettingRow {
            label: qsTr("Start playing as soon as a file opens")
            option: SettingsModel.option("start-paused")
            kind: "toggle"
            valueOn: false
            valueOff: true
        }

        SettingRow {
            id: speedRow

            label: qsTr("Default playback speed")
            info: ""
            option: SettingsModel.option("rate")
            kind: "custom"
            keywords: qsTr("rate")
            customControl: Component {
                // Figma: slider with one caption per 0.25 step
                Item {
                    id: speed

                    readonly property var steps: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]

                    implicitWidth: speedRow.controlWidth
                    implicitHeight: VLCStyle.dp(47, VLCStyle.scale)

                    readonly property ColorContext colorContext: ColorContext {
                        id: speedTheme
                        colorSet: ColorContext.Pane
                    }

                    Widgets.SliderExt {
                        id: speedSlider

                        width: parent.width
                        height: VLCStyle.dp(24, VLCStyle.scale)
                        topPadding: 0
                        bottomPadding: 0
                        from: 0.25
                        to: 2
                        stepSize: 0.25
                        snapMode: T.Slider.SnapAlways
                        value: speedRow.option.value
                        handleHeight: VLCStyle.dp(24, VLCStyle.scale)
                        trackHeight: VLCStyle.dp(16, VLCStyle.scale)
                        toolTipTextProvider: (v) => v + "x"
                        onMoved: speedRow.option.value = value

                        Accessible.name: speedRow.label

                        Item {
                            z: 1
                            x: speedSlider.leftPadding + speedSlider.handle.width / 2
                            y: (speedSlider.height - height) / 2
                            width: speedSlider.availableWidth - speedSlider.handle.width
                            height: VLCStyle.dp(6, VLCStyle.scale)

                            Repeater {
                                model: speed.steps.length

                                delegate: Rectangle {
                                    required property int index

                                    x: index * parent.width / (speed.steps.length - 1) - width / 2
                                    width: VLCStyle.border
                                    height: parent.height
                                    color: speedTheme.fg.secondary
                                    opacity: 0.6
                                }
                            }
                        }
                    }

                    Item {
                        y: VLCStyle.dp(28, VLCStyle.scale)
                        width: parent.width
                        height: VLCStyle.dp(15, VLCStyle.scale)

                        Repeater {
                            model: speed.steps

                            delegate: Text {
                                required property int index
                                required property real modelData

                                readonly property real center: speedSlider.handle.width / 2
                                                               + index * (parent.width - speedSlider.handle.width) / (speed.steps.length - 1)

                                x: Math.max(0, Math.min(parent.width - width, center - width / 2))
                                text: String(modelData)
                                color: speedTheme.fg.secondary
                                font.pixelSize: VLCStyle.text_caption
                            }
                        }
                    }
                }
            }
        }
    }

    SettingSection {
        title: qsTr("Tracks")

        SettingRow {
            label: qsTr("Preferred video quality")
            option: SettingsModel.option("preferred-resolution")
        }

        SettingRow {
            label: qsTr("Preferred menu language")
            option: SettingsModel.option("menu-language")
            kind: "dropdown"
            choices: page.languages
        }

        SettingRow {
            label: qsTr("Default audio track")
            option: SettingsModel.option("audio-track")
            kind: "number"
        }

        SettingRow {
            label: qsTr("Default subtitle track")
            option: SettingsModel.option("sub-track")
            kind: "number"
        }
    }

    SettingSection {
        title: qsTr("Order")

        SettingRow {
            id: repeatRow

            readonly property ConfigOption loopOpt: SettingsModel.option("loop")
            readonly property ConfigOption repeatOpt: SettingsModel.option("repeat")

            label: qsTr("Repeat")
            info: repeatOpt.longText
            needsOption: false
            kind: "custom"
            customControl: Component {
                Widgets.Dropdown {
                    implicitWidth: repeatRow.controlWidth
                    compact: true
                    model: [qsTr("Off"), qsTr("One"), qsTr("All")]
                    currentIndex: repeatRow.loopOpt.value == true ? 2 : (repeatRow.repeatOpt.value == true ? 1 : 0)
                    onActivated: (index) => {
                        repeatRow.repeatOpt.value = (index === 1)
                        repeatRow.loopOpt.value = (index === 2)
                    }

                    Accessible.name: repeatRow.label
                }
            }
        }

        SettingRow {
            label: qsTr("Shuffle")
            option: SettingsModel.option("random")
        }

        SettingRow {
            label: qsTr("Stop after each item")
            option: SettingsModel.option("play-and-stop")
        }

        SettingRow {
            label: qsTr("When playback finishes")
            option: SettingsModel.option("play-and-exit")
            kind: "dropdown"
            choices: [
                { value: false, text: qsTr("Stop") },
                { value: true, text: qsTr("Quit VLC") }
            ]
        }
    }

    SettingSection {
        title: qsTr("Seeking")

        SettingRow {
            label: qsTr("Seek precisely")
            option: SettingsModel.option("input-fast-seek")
            kind: "toggle"
            valueOn: false
            valueOff: true
        }
    }

    SettingSection {
        title: qsTr("Files & Discs")

        SettingRow {
            label: qsTr("Default disc device")
            option: SettingsModel.option("dvd")
        }

        SettingRow {
            label: qsTr("Repair broken AVI files")
            option: SettingsModel.option("avi-index")
        }

        SettingRow {
            label: qsTr("Preload MKV files in the same folder")
            option: SettingsModel.option("mkv-preload-local-dir")
        }
    }

    advanced: [
        SettingSection {
            title: qsTr("Time Shifting")

            SettingRow {
                label: qsTr("Time shift folder")
                option: SettingsModel.option("input-timeshift-path")
            }

            SettingRow {
                label: qsTr("Time shift granularity")
                option: SettingsModel.option("input-timeshift-granularity")
            }
        }
    ]
}
