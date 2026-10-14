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


// Audio settings. Figma 3073:15879 (advanced / equalizer 3180:17398).
//
// Figma row                                  -> VLC option
//   Enable audio                             -> audio
//   Output device                            -> audioDevice (virtual, <aout>-audio-device)
//   Speaker setup                            -> stereo-mode
//   Maximum volume                           -> qt-max-volume (100 .. 300 %)
//   Startup volume                           -> volume-save (Remember last volume) + the output's own
//                                               startup volume (auhal-volume on macOS, mmdevice-volume on
//                                               Windows); the "Always starts at" field is hidden when the
//                                               output has none
//   Volume step                              -> volume-step
//   Normalize loudness                       -> "normvol" in audio-filter (hidden when the module is absent)
//   Target level                             -> norm-max-level
//   Night mode                               -> "compressor" in audio-filter
//   Replay gain / Replay gain preamp         -> audio-replay-gain-mode / audio-replay-gain-preamp
//   Equalizer                                -> "equalizer" in audio-filter
//   Equalizer preset                         -> equalizer-preset (the preset values are copied to the bands)
//   Equalizer panel (Preamp + 10 bands)      -> equalizer-preamp / equalizer-bands
//   Two-pass                                 -> equalizer-2pass
//   Spatial audio                            -> "spatializer" in audio-filter
//   Spatial audio mode                       -> (omitted: replaced by a "Headphone virtualization" toggle
//                                               on the "headphone" filter)
//   Stereo widening                          -> "stereo_widen" in audio-filter (hidden when absent)
//   Tracks: Preferred language               -> audio-language
//   Visualization                            -> audio-visual

import QtQuick
import QtQuick.Layouts
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

    readonly property ConfigOption filters: SettingsModel.option("audio-filter")

    function hasFilterModule(name) {
        const list = filters.choices
        for (let i = 0; i < list.length; ++i) {
            if (list[i].value === name)
                return true
        }
        return false
    }


    // Figma equalizer: preamp + 10 bands, collapsible ("Close Equalizer")
    component EqualizerPanel: Item {
        id: eq

        property ConfigOption preset: null

        readonly property ConfigOption bandsOption: SettingsModel.option("equalizer-bands")
        readonly property ConfigOption preampOption: SettingsModel.option("equalizer-preamp")
        readonly property var bandNames: ["60 Hz", "170 Hz", "310 Hz", "600 Hz", "1 KHz", "3 KHz", "6 KHz", "12 KHz", "14 KHz", "16 KHz"]

        // copies of the VLC presets (modules/audio_filter/equalizer_presets.h): [preamp, 10 band gains]
        readonly property var presetData: ({
            "flat": [12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "classical": [12, 0, 0, 0, 0, 0, 0, -7.2, -7.2, -7.2, -9.6],
            "club": [6, 0, 0, 8, 5.6, 5.6, 5.6, 3.2, 0, 0, 0],
            "dance": [5, 9.6, 7.2, 2.4, 0, 0, -5.6, -7.2, -7.2, 0, 0],
            "fullbass": [5, -8, 9.6, 9.6, 5.6, 1.6, -4, -8, -10.4, -11.2, -11.2],
            "fullbasstreble": [4, 7.2, 5.6, 0, -7.2, -4.8, 1.6, 8, 11.2, 12, 12],
            "fulltreble": [3, -9.6, -9.6, -9.6, -4, 2.4, 11.2, 16, 16, 16, 16.8],
            "headphones": [4, 4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4],
            "largehall": [5, 10.4, 10.4, 5.6, 5.6, 0, -4.8, -4.8, -4.8, 0, 0],
            "live": [7, -4.8, 0, 4, 5.6, 5.6, 5.6, 4, 2.4, 2.4, 2.4],
            "party": [6, 7.2, 7.2, 0, 0, 0, 0, 0, 0, 7.2, 7.2],
            "pop": [6, -1.6, 4.8, 7.2, 8, 5.6, 0, -2.4, -2.4, -1.6, -1.6],
            "reggae": [8, 0, 0, 0, -5.6, 0, 6.4, 6.4, 0, 0, 0],
            "rock": [5, 8, 4.8, -5.6, -8, -3.2, 4, 8.8, 11.2, 11.2, 11.2],
            "ska": [6, -2.4, -4.8, -4, 0, 4, 5.6, 8.8, 9.6, 11.2, 9.6],
            "soft": [5, 4.8, 1.6, 0, -2.4, 0, 4, 8, 9.6, 11.2, 12],
            "softrock": [7, 4, 4, 2.4, 0, -4, -5.6, -3.2, 0, 2.4, 8.8],
            "techno": [5, 8, 5.6, 0, -5.6, -4.8, 0, 8, 9.6, 9.6, 8.8]
        })

        readonly property var bands: {
            const parts = String(bandsOption.value ?? "").trim().split(/\s+/)
            const out = []
            for (let i = 0; i < 10; ++i) {
                const v = parseFloat(parts[i])
                out.push(isNaN(v) ? 0 : v)
            }
            return out
        }

        property bool expanded: true

        function setBand(i, v) {
            const b = bands.slice()
            b[i] = Math.round(v * 10) / 10
            bandsOption.value = b.map((x) => x.toFixed(1)).join(" ")
        }

        // picking a preset writes its gains, so the sliders and the filter agree
        function applyPreset(name) {
            preset.value = name
            const d = presetData[name]
            if (!d)
                return
            preampOption.value = d[0]
            bandsOption.value = d.slice(1).map((x) => x.toFixed(1)).join(" ")
        }

        Connections {
            target: eq.preset
            function onEdited() { eq.applyPreset(eq.preset.value) }
        }

        readonly property real sliderH: VLCStyle.dp(320, VLCStyle.scale)

        implicitHeight: expanded ? VLCStyle.dp(507, VLCStyle.scale) : VLCStyle.dp(50, VLCStyle.scale)
        Layout.preferredHeight: implicitHeight
        Layout.topMargin: VLCStyle.dp(-2, VLCStyle.scale)

        Behavior on implicitHeight {
            NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad }
        }

        readonly property ColorContext colorContext: ColorContext {
            id: eqTheme
            colorSet: ColorContext.Pane
        }

        clip: true

        Rectangle {
            anchors.fill: parent
            color: eqTheme.bg.secondary
        }

        T.AbstractButton {
            id: closeButton

            anchors.horizontalCenter: parent.horizontalCenter
            y: VLCStyle.dp(8, VLCStyle.scale)
            width: closeRow.implicitWidth + 2 * VLCStyle.spacing_12
            height: VLCStyle.dp(32, VLCStyle.scale)
            hoverEnabled: true
            onClicked: eq.expanded = !eq.expanded

            Accessible.name: closeRow.text

            contentItem: Row {
                id: closeRow

                property string text: eq.expanded ? qsTr("Close Equalizer") : qsTr("Open Equalizer")

                spacing: VLCStyle.spacing_10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: closeRow.text
                    color: eqTheme.fg.primary
                    font.pixelSize: VLCStyle.text_body
                }

                Widgets.SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron-down"
                    size: VLCStyle.dp(16, VLCStyle.scale)
                    color: eqTheme.fg.primary
                    rotation: eq.expanded ? 0 : 180

                    Behavior on rotation {
                        NumberAnimation { duration: VLCStyle.duration_short }
                    }
                }
            }
        }

        Repeater {
            model: 11

            delegate: Item {
                id: col

                required property int index

                readonly property bool isPreamp: index === 0
                readonly property real value: isPreamp ? Number(eq.preampOption.value) : eq.bands[index - 1]

                x: VLCStyle.dp(51 + 68 * index - 30, VLCStyle.scale)
                y: VLCStyle.dp(68, VLCStyle.scale)
                width: VLCStyle.dp(60, VLCStyle.scale)
                height: parent.height - y
                opacity: eq.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: VLCStyle.duration_short }
                }

                Widgets.SliderExt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: VLCStyle.dp(20, VLCStyle.scale)
                    height: eq.sliderH
                    orientation: Qt.Vertical
                    from: -20
                    to: 20
                    stepSize: 0.1
                    value: col.value
                    padding: 0

                    trackHeight: VLCStyle.dp(16, VLCStyle.scale)
                    handleHeight: VLCStyle.dp(20, VLCStyle.scale)
                    handleWidth: VLCStyle.dp(10, VLCStyle.scale)
                    toolTipTextProvider: (v) => v.toFixed(1) + " dB"

                    onMoved: {
                        if (col.isPreamp)
                            eq.preampOption.value = Math.round(value * 10) / 10
                        else
                            eq.setBand(col.index - 1, value)
                    }

                    Accessible.name: col.isPreamp ? qsTr("Preamp") : eq.bandNames[col.index - 1]
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: eq.sliderH + VLCStyle.dp(30, VLCStyle.scale)
                    text: col.isPreamp ? qsTr("Preamp") : eq.bandNames[col.index - 1]
                    color: eqTheme.fg.secondary
                    font.pixelSize: VLCStyle.text_body
                }

                Widgets.TextFieldExt {
                    id: dbField

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: eq.sliderH + VLCStyle.dp(61, VLCStyle.scale)
                    width: VLCStyle.dp(60, VLCStyle.scale)
                    height: VLCStyle.dp(34, VLCStyle.scale)
                    horizontalAlignment: TextInput.AlignHCenter
                    font.pixelSize: VLCStyle.text_caption
                    leftPadding: 0
                    rightPadding: 0
                    selectByMouse: true
                    validator: DoubleValidator { bottom: -20; top: 20; notation: DoubleValidator.StandardNotation }

                    text: col.value.toFixed(1) + " dB"
                    onActiveFocusChanged: if (activeFocus) { text = col.value.toFixed(1); selectAll() }
                                          else text = Qt.binding(() => col.value.toFixed(1) + " dB")
                    onEditingFinished: {
                        const v = Math.max(-20, Math.min(20, parseFloat(text)))
                        if (isNaN(v))
                            return
                        if (col.isPreamp)
                            eq.preampOption.value = v
                        else
                            eq.setBand(col.index - 1, v)
                    }
                }
            }
        }
    }

    // toggle for one module of the audio-filter list
    component FilterRow: SettingRow {
        id: filterRow

        property string filter

        option: page.hasFilterModule(filter) ? page.filters : null
        kind: "custom"
        customControl: Component {
            Widgets.CheckButton {
                checked: filterRow.option ? (filterRow.option.value, filterRow.option.hasListItem(filterRow.filter)) : false
                text: ""
                onToggled: if (filterRow.option) filterRow.option.setListItem(filterRow.filter, checked)

                Accessible.name: filterRow.label
            }
        }
    }

    // the startup volume option written by the active output
    readonly property ConfigOption startupVolumeOption: {
        const names = ["auhal-volume", "mmdevice-volume", "waveout-volume"]
        for (const n of names) {
            const o = SettingsModel.option(n)
            if (o.available)
                return o
        }
        return null
    }

    SettingSection {
        title: qsTr("Output")

        SettingRow {
            label: qsTr("Enable audio")
            option: SettingsModel.option("audio")
        }

        SettingRow {
            label: qsTr("Output device")
            option: SettingsModel.option("audioDevice")
            kind: "dropdown"
        }

        SettingRow {
            label: qsTr("Speaker setup")
            option: SettingsModel.option("stereo-mode")
        }
    }

    SettingSection {
        title: qsTr("Volume")

        SettingRow {
            label: qsTr("Maximum volume")
            info: ""
            option: SettingsModel.option("qt-max-volume")
            kind: "slider"
            from: 100
            to: 300
            stepSize: 25
            suffix: "%"
            ticks: true
        }

        SettingRow {
            id: startupRow

            label: qsTr("Startup volume")
            option: SettingsModel.option("volume-save")
            kind: "custom"
            customControl: Component {
                // Figma: one well with two choices stacked, "Remember last volume" and "Always starts at"
                Rectangle {
                    id: startup

                    readonly property bool remember: startupRow.option.value
                    readonly property bool hasFixed: page.startupVolumeOption !== null

                    implicitWidth: startupRow.controlWidth
                    implicitHeight: (hasFixed ? 2 : 1) * VLCStyle.dp(36, VLCStyle.scale)
                                    + (hasFixed ? 1 : 0) * VLCStyle.spacing_2 + 2 * VLCStyle.spacing_2
                    radius: VLCStyle.radius_m
                    color: startupTheme.bg.secondary

                    readonly property ColorContext colorContext: ColorContext {
                        id: startupTheme
                        colorSet: ColorContext.ComboBox
                    }

                    readonly property ColorContext tonalContext: ColorContext {
                        id: tonalTheme
                        colorSet: ColorContext.ButtonTonal
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: VLCStyle.spacing_2
                        spacing: VLCStyle.spacing_2

                        T.AbstractButton {
                            width: parent.width
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            hoverEnabled: true
                            onClicked: startupRow.option.value = true

                            Accessible.name: qsTr("Remember last volume")
                            Accessible.role: Accessible.RadioButton
                            Accessible.checked: startup.remember

                            background: Rectangle {
                                radius: VLCStyle.radius_s
                                color: startup.remember ? tonalTheme.bg.primary
                                                        : (parent.hovered ? startupTheme.bg.primary : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: VLCStyle.duration_short }
                                }
                            }

                            contentItem: Text {
                                leftPadding: VLCStyle.spacing_12
                                verticalAlignment: Text.AlignVCenter
                                text: qsTr("Remember last volume")
                                font.pixelSize: VLCStyle.text_body
                                color: startup.remember ? tonalTheme.fg.primary : startupTheme.fg.primary
                            }
                        }

                        Rectangle {
                            visible: startup.hasFixed
                            width: parent.width
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            radius: VLCStyle.radius_s
                            color: startup.remember ? "transparent" : tonalTheme.bg.primary

                            Row {
                                anchors.fill: parent

                                Text {
                                    width: implicitWidth + 2 * VLCStyle.spacing_12
                                    height: parent.height
                                    leftPadding: VLCStyle.spacing_12
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("Always starts at:")
                                    font.pixelSize: VLCStyle.text_body
                                    color: startup.remember ? startupTheme.fg.secondary : tonalTheme.fg.primary

                                    TapHandler { onTapped: startupRow.option.value = false }
                                }

                                Widgets.TextFieldExt {
                                    id: startField

                                    width: parent.width - x
                                    height: parent.height
                                    selectByMouse: true
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 0; top: 300 }

                                    // auhal stores 0..256 (256 = 100 %), the others a float where 1.0 = 100 %
                                    readonly property bool isInt: page.startupVolumeOption && page.startupVolumeOption.name === "auhal-volume"
                                    readonly property real percent: page.startupVolumeOption
                                        ? (isInt ? page.startupVolumeOption.value / 256 * 100
                                                 : page.startupVolumeOption.value * 100) : 0

                                    text: Math.round(percent) + "%"
                                    onActiveFocusChanged: if (activeFocus) { text = String(Math.round(percent)); selectAll() }
                                                          else text = Qt.binding(() => Math.round(percent) + "%")
                                    onEditingFinished: {
                                        const v = parseInt(text)
                                        if (isNaN(v) || !page.startupVolumeOption)
                                            return
                                        startupRow.option.value = false
                                        page.startupVolumeOption.value = isInt ? Math.round(v / 100 * 256) : v / 100
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        SettingRow {
            label: qsTr("Volume step")
            option: SettingsModel.option("volume-step")
            kind: "number"
        }
    }

    SettingSection {
        title: qsTr("Loudness")

        FilterRow {
            id: normalize

            label: qsTr("Normalize loudness")
            info: SettingsModel.option("norm-max-level").longText
            filter: "normvol"
        }

        SettingRow {
            label: qsTr("Target level")
            option: SettingsModel.option("norm-max-level")
            kind: "number"
            // the dependency is a module in a list, which dependsOn cannot express
            enabled: normalize.option ? (normalize.option.value, normalize.option.hasListItem("normvol")) : true
            opacity: enabled ? 1.0 : 0.3
        }

        FilterRow {
            label: qsTr("Night mode")
            info: qsTr("Compresses the dynamic range so that quiet and loud passages are closer together.")
            filter: "compressor"
        }

        SettingRow {
            label: qsTr("Replay gain")
            option: SettingsModel.option("audio-replay-gain-mode")
        }

        SettingRow {
            label: qsTr("Replay gain preamp")
            option: SettingsModel.option("audio-replay-gain-preamp")
            kind: "number"
        }
    }

    SettingSection {
        title: qsTr("Effects")

        FilterRow {
            id: eqToggle

            label: qsTr("Equalizer")
            info: SettingsModel.option("equalizer-preset").longText
            filter: "equalizer"
        }

        SettingRow {
            id: presetRow

            label: qsTr("Equalizer preset")
            option: SettingsModel.option("equalizer-preset")
        }

        EqualizerPanel {
            id: eqPanel

            Layout.fillWidth: true
            preset: presetRow.option
            visible: presetRow.shown && !page.searching
        }

        SettingRow {
            label: qsTr("Two-pass")
            option: SettingsModel.option("equalizer-2pass")
        }

        FilterRow {
            label: qsTr("Spatial audio")
            info: ""
            filter: "spatializer"
        }

        FilterRow {
            label: qsTr("Headphone virtualization")
            info: ""
            filter: "headphone"
        }

        FilterRow {
            label: qsTr("Stereo widening")
            filter: "stereo_widen"
        }
    }

    advanced: [
        SettingSection {
            title: qsTr("Tracks")

            SettingRow {
                label: qsTr("Preferred audio language")
                option: SettingsModel.option("audio-language")
            kind: "dropdown"
            choices: page.languages
            }
        },

        SettingSection {
            title: qsTr("Visualization")

            SettingRow {
                label: qsTr("Visualization")
                option: SettingsModel.option("audio-visual")
            }
        }
    ]
}
