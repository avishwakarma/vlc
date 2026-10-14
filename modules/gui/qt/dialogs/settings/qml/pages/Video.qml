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


// Video settings. Figma 3073:14187 (advanced 3073:15375).
//
// Figma row                                  -> VLC option
//   Enable video                             -> video
//   Start videos in fullscreen               -> fullscreen
//   Stop the screensaver during playback     -> disable-screensaver
//   Play video as desktop wallpaper          -> video-wallpaper (Windows only: hidden elsewhere)
//   Hue / Brightness / Contrast / Saturation / Gamma
//                                            -> hue / brightness / contrast / saturation / gamma
//                                               ("adjust" filter options; the filter is enabled
//                                               in video-filter while one of them is not default)
//   Reset picture                            -> resets the five options above
//   Deinterlacing / Method                   -> deinterlace / deinterlace-mode
//   Aspect ratio / Crop                      -> aspect-ratio / crop
//   Zoom / Alignment / Fit to window         -> zoom / align / autoscale
//   Snapshots folder / prefix / format       -> snapshot-path / snapshot-prefix / snapshot-format
//   Sequential numbering                     -> snapshot-sequential
//   Advanced                                 -> snapshot-width, snapshot-height, snapshot-preview,
//                                               custom-aspect-ratios, custom-crop-ratios, monitor-par

import QtQuick

import VLC.Dialogs
import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

SettingsPage {
    id: page

    readonly property var pictureOptions: ["hue", "brightness", "contrast", "saturation", "gamma"]

    // the sliders are options of the "adjust" filter: keep it in video-filter
    // while any of them differs from its default
    function syncAdjustFilter() {
        let modified = false
        for (const n of pictureOptions)
            modified = modified || SettingsModel.option(n).modified
        const filters = SettingsModel.option("video-filter")
        if (filters.available && filters.hasListItem("adjust") !== modified)
            filters.setListItem("adjust", modified)
    }


    // Figma picture row: bare slider without captions (24 px high)
    component PictureRow: SettingRow {
        id: pictureRow

        property bool withTicks: false

        info: ""
        kind: "custom"
        customControl: Component {
            Widgets.SliderExt {
                implicitWidth: pictureRow.controlWidth
                implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
                topPadding: 0
                bottomPadding: 0
                from: pictureRow.option.min
                to: pictureRow.option.max
                stepSize: pictureRow.stepSize
                value: pictureRow.option.value
                handleHeight: VLCStyle.dp(24, VLCStyle.scale)
                trackHeight: VLCStyle.dp(16, VLCStyle.scale)
                onMoved: pictureRow.option.value = value

                Accessible.name: pictureRow.label

                Item {
                    visible: pictureRow.withTicks
                    z: 1
                    x: parent.leftPadding + parent.handle.width / 2
                    y: (parent.height - height) / 2
                    width: parent.availableWidth - parent.handle.width
                    height: VLCStyle.dp(6, VLCStyle.scale)

                    Repeater {
                        model: 9

                        delegate: Rectangle {
                            required property int index

                            x: index * parent.width / 8 - width / 2
                            width: VLCStyle.border
                            height: parent.height
                            opacity: 0.6
                            color: pictureRow.colorContext.fg.secondary
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: page.pictureOptions

        delegate: Item {
            required property string modelData
            visible: false

            Connections {
                target: SettingsModel.option(modelData)
                function onEdited() { page.syncAdjustFilter() }
            }
        }
    }

    SettingSection {
        title: qsTr("Output")

        SettingRow {
            label: qsTr("Enable video")
            option: SettingsModel.option("video")
        }

        SettingRow {
            label: qsTr("Start videos in fullscreen")
            option: SettingsModel.option("fullscreen")
        }

        SettingRow {
            label: qsTr("Stop the screensaver during playback")
            option: SettingsModel.option("disable-screensaver")
            kind: "toggle"
            valueOn: 1      // Always
            valueOff: 0     // Never ("When fullscreen" reads as off)
        }

        SettingRow {
            label: qsTr("Play video as desktop wallpaper")
            option: Qt.platform.os === "windows" ? SettingsModel.option("video-wallpaper") : null
        }
    }

    SettingSection {
        title: qsTr("Picture")

        PictureRow {
            label: qsTr("Hue")
            option: SettingsModel.option("hue")
            stepSize: 1
        }

        PictureRow {
            label: qsTr("Brightness")
            option: SettingsModel.option("brightness")
            stepSize: 0.01
        }

        PictureRow {
            label: qsTr("Contrast")
            option: SettingsModel.option("contrast")
            stepSize: 0.01
        }

        PictureRow {
            label: qsTr("Saturation")
            option: SettingsModel.option("saturation")
            stepSize: 0.01
        }

        PictureRow {
            label: qsTr("Gamma")
            option: SettingsModel.option("gamma")
            stepSize: 0.01
            withTicks: true
        }

        SettingRow {
            label: qsTr("Reset picture")
            needsOption: false
            kind: "button"
            buttonText: qsTr("Reset")
            keywords: qsTr("hue brightness contrast saturation gamma default")
            onActivated: {
                for (const n of page.pictureOptions)
                    SettingsModel.option(n).reset()
                page.syncAdjustFilter()
            }
        }
    }

    SettingSection {
        title: qsTr("Deinterlacing")

        SettingRow {
            label: qsTr("Deinterlacing")
            option: SettingsModel.option("deinterlace")
        }

        SettingRow {
            label: qsTr("Method")
            option: SettingsModel.option("deinterlace-mode")
        }
    }

    SettingSection {
        title: qsTr("Framing")

        SettingRow {
            label: qsTr("Aspect ratio")
            option: SettingsModel.option("aspect-ratio")
            kind: "dropdown"
            choices: [
                { value: "", text: qsTr("Automatic") },
                { value: "1:1", text: "1:1" },
                { value: "4:3", text: "4:3" },
                { value: "16:9", text: "16:9" },
                { value: "16:10", text: "16:10" },
                { value: "221:100", text: "2.21:1" },
                { value: "235:100", text: "2.35:1" },
                { value: "239:100", text: "2.39:1" },
                { value: "5:4", text: "5:4" }
            ]
        }

        SettingRow {
            label: qsTr("Crop")
            option: SettingsModel.option("crop")
            kind: "dropdown"
            choices: [
                { value: "", text: qsTr("None") },
                { value: "1:1", text: "1:1" },
                { value: "4:3", text: "4:3" },
                { value: "16:9", text: "16:9" },
                { value: "16:10", text: "16:10" },
                { value: "185:100", text: "1.85:1" },
                { value: "221:100", text: "2.21:1" },
                { value: "235:100", text: "2.35:1" },
                { value: "239:100", text: "2.39:1" },
                { value: "5:3", text: "5:3" },
                { value: "5:4", text: "5:4" }
            ]
        }

        SettingRow {
            label: qsTr("Zoom")
            option: SettingsModel.option("zoom")
        }

        SettingRow {
            label: qsTr("Video alignment")
            option: SettingsModel.option("align")
        }

        SettingRow {
            label: qsTr("Fit video to the window")
            option: SettingsModel.option("autoscale")
        }
    }

    SettingSection {
        title: qsTr("Snapshots")

        SettingRow {
            label: qsTr("Save snapshots to")
            option: SettingsModel.option("snapshot-path")
        }

        SettingRow {
            label: qsTr("File name prefix")
            option: SettingsModel.option("snapshot-prefix")
        }

        SettingRow {
            label: qsTr("Format")
            option: SettingsModel.option("snapshot-format")
        }

        SettingRow {
            label: qsTr("Sequential numbering")
            option: SettingsModel.option("snapshot-sequential")
        }
    }

    advanced: [
        SettingSection {
            SettingRow {
                label: qsTr("Snapshot width")
                option: SettingsModel.option("snapshot-width")
            }

            SettingRow {
                label: qsTr("Snapshot height")
                option: SettingsModel.option("snapshot-height")
            }

            SettingRow {
                label: qsTr("Show snapshot preview")
                option: SettingsModel.option("snapshot-preview")
            }

            SettingRow {
                label: qsTr("Custom aspect ratios")
                option: SettingsModel.option("custom-aspect-ratios")
            }

            SettingRow {
                label: qsTr("Custom crop ratios")
                option: SettingsModel.option("custom-crop-ratios")
            }

            SettingRow {
                label: qsTr("Monitor pixel aspect ratio")
                option: SettingsModel.option("monitor-par")
            }
        }
    ]
}
