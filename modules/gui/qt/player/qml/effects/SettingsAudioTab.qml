
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

import VLC.Style
import VLC.Player
import VLC.Dialogs
import VLC.Widgets as Widgets

// Settings > Audio (Figma 536:1059): defaults, synchronisation and the audio
// filters (equalizer 2372:8487 / 6114:13610, compressor 536:1513,
// spatializer 536:1703, stereo widener 612:1223).
SettingsTabBase {
    id: root

    // opens the wide equalizer (Figma 3178:16769)
    signal requestEqualizer()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property var eqIcons: ({
        "flat": "EQ", "classical": "EQ-classical", "club": "EQ-club", "dance": "EQ-dance",
        "fullbass": "EQ-full-bass", "fullbasstreble": "EQ-full-bass-and-treble",
        "fulltreble": "EQ-full-treble", "headphones": "EQ-headphones", "largehall": "EQ-large-hall",
        "live": "EQ-live", "party": "EQ-party", "pop": "EQ-pop", "reggae": "EQ-reggae",
        "rock": "EQ-rock", "ska": "EQ-ska", "soft": "EQ-soft", "softrock": "EQ-soft-rock",
        "techno": "EQ-techno"
    })

    // None, the presets of the core, "Custom" while the bands match none
    readonly property var eqItems: {
        const list = [{ name: "", text: qsTr("None"), iconName: "" }]
        for (const p of PlayerEffects.presets)
            list.push({ name: p.name, text: p.text, iconName: root.eqIcons[p.name] ?? "EQ" })
        if (PlayerEffects.equalizer.enabled && PlayerEffects.preset === "")
            list.push({ name: "custom", text: qsTr("Custom"), iconName: "" })
        return list
    }

    Component.onCompleted: PlayerEffects.refresh()

    PanelHeading {
        text: qsTr("Defaults")
    }

    PanelRow {
        label: qsTr("Audio Track")
        OptionField { width: parent.width; option: SettingsModel.option("audio-track"); numeric: true; Accessible.name: qsTr("Audio Track") }
    }

    PanelRow {
        label: qsTr("Audio Language")
        OptionField { width: parent.width; option: SettingsModel.option("audio-language"); Accessible.name: qsTr("Audio Language") }
    }

    PanelRow {
        label: qsTr("Stereo Mode")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)
        controlWidth: VLCStyle.dp(68, VLCStyle.scale)
        unavailableText: qsTr("Not available yet")

        TonalButton {
            width: parent.width
            text: qsTr("Test")
            enabled: false
        }
    }

    VarChoiceDropdown {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_8

        choiceModel: Player.audioStereoMode
        Accessible.name: qsTr("Stereo Mode")
    }

    PanelDivider {}

    PanelHeading {
        text: qsTr("Synchronization")
    }

    PanelRow {
        Layout.topMargin: VLCStyle.spacing_2
        label: qsTr("Audio Track Delay")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)

        ValueField {
            width: parent.width
            font.pixelSize: VLCStyle.text_body
            decimals: 3
            unit: " s"
            from: -10
            to: 10
            value: Player.audioDelayMS / 1000
            onCommitted: (v) => Player.audioDelayMS = Math.round(v * 1000)
            Accessible.name: qsTr("Audio Track Delay")
        }
    }

    DelaySlider {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.spacing_8
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.dp(8, VLCStyle.scale)

        from: -10
        to: 10
        stepSize: 0.05
        value: Player.audioDelayMS / 1000
        labels: [qsTr("-10 s"), qsTr("0 s"), qsTr("+10 s")]
        onMoved: Player.audioDelayMS = Math.round(value * 1000)
        onReset: Player.audioDelayMS = 0
        Accessible.name: qsTr("Audio Track Delay")
    }

    PanelDivider {}

    PanelHeading {
        text: qsTr("Filters")
    }

    PanelSubLabel { text: qsTr("Equalizer") }

    EffectsDropdown {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_12

        visible: PlayerEffects.equalizer.available

        iconRole: "iconName"
        textRole: "text"
        model: root.eqItems
        currentIndex: {
            if (!PlayerEffects.equalizer.enabled)
                return 0
            for (let i = 0; i < root.eqItems.length; ++i) {
                if (root.eqItems[i].name === (PlayerEffects.preset === "" ? "custom" : PlayerEffects.preset))
                    return i
            }
            return 0
        }
        onActivated: (i) => {
            const it = root.eqItems[i]
            if (it.name === "") {
                PlayerEffects.equalizer.enabled = false
            } else if (it.name !== "custom") {
                PlayerEffects.equalizer.enabled = true
                PlayerEffects.applyPreset(it.name)
            }
        }
        Accessible.name: qsTr("Equalizer")
    }

    EffectParamsCard {
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_10

        visible: PlayerEffects.equalizer.available

        params: [PlayerEffects.preamp].concat(PlayerEffects.bands)
        editable: true
        rowSpacing: VLCStyle.spacing_20
        opacity: PlayerEffects.equalizer.enabled ? 1.0 : 0.6
    }

    PanelRow {
        label: qsTr("2 Pass")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)
        controlWidth: VLCStyle.toggle_w
        visible: PlayerEffects.equalizer.available

        Widgets.CheckButton {
            text: ""
            checked: PlayerEffects.twoPass.value
            onToggled: PlayerEffects.twoPass.value = checked
            Accessible.name: qsTr("2 Pass")
        }
    }

    Widgets.SettingButton {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: VLCStyle.spacing_20

        visible: PlayerEffects.equalizer.available
        text: qsTr("Open Equalizer")
        iconName: "EQ"
        onClicked: root.requestEqualizer()
    }

    FilterSection {
        title: qsTr("Compressor")
        effect: PlayerEffects.compressor
        params: PlayerEffects.compressor.params
    }

    FilterSection {
        title: qsTr("Spatializer")
        effect: PlayerEffects.spatializer
        params: PlayerEffects.spatializer.params
    }

    FilterSection {
        title: qsTr("Stereo Widener")
        effect: PlayerEffects.stereoWidener
        params: PlayerEffects.stereoWidener.params
    }
}
