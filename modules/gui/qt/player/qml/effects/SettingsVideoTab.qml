
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

// Settings > Video (Figma 498:2937, filters 536:1855 / 543:990 / 614:1430).
SettingsTabBase {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property var flipChoices: [
        { text: qsTr("None"), value: "" },
        { text: qsTr("Horizontal"), value: "hflip" },
        { text: qsTr("Vertical"), value: "vflip" }
    ]

    Component.onCompleted: PlayerEffects.refresh()

    PanelHeading {
        text: qsTr("Defaults")
    }

    PanelRow {
        label: qsTr("Flip")
        rowHeight: VLCStyle.dp(56, VLCStyle.scale)
    }

    Widgets.SegmentedControl {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.dp(11, VLCStyle.scale)

        model: root.flipChoices
        currentIndex: {
            if (!PlayerEffects.flip.enabled)
                return 0
            return PlayerEffects.flip.params[0].value === "vflip" ? 2 : 1
        }
        onActivated: (i) => {
            if (i === 0) {
                PlayerEffects.flip.enabled = false
            } else {
                PlayerEffects.flip.params[0].value = root.flipChoices[i].value
                PlayerEffects.flip.enabled = true
            }
        }
        Accessible.name: qsTr("Flip")
    }

    PanelRow {
        label: qsTr("Rotate")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)

        ValueField {
            width: parent.width

            font.pixelSize: VLCStyle.text_body
            decimals: 0
            unit: " deg"
            from: 0
            to: 359
            value: Number(PlayerEffects.rotate.params[0].value)
            onCommitted: (v) => PlayerEffects.rotate.params[0].value = v
            Accessible.name: qsTr("Rotate")
        }
    }

    PanelRow {
        label: qsTr("Zoom")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)

        VarChoiceDropdown {
            width: parent.width
            choiceModel: Player.zoom
            Accessible.name: qsTr("Zoom")
        }
    }

    PanelRow {
        label: qsTr("HDR")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)
        // Figma 2372:8733; tone mapping is only read when the video output opens
        unavailableText: qsTr("Not available yet")

        EffectsDropdown {
            width: parent.width
            enabled: PlayerEffects.hdrAvailable
            opacity: 0.4
            textRole: "text"
            model: [{ text: qsTr("Auto") }, { text: qsTr("Off") }, { text: "HDR10" }, { text: "HDR10+" },
                    { text: "Dolby Vision" }, { text: "HLG" }]
            currentIndex: 0
            Accessible.name: qsTr("HDR")
        }
    }

    PanelRow {
        label: qsTr("Resolution")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)

        EffectsDropdown {
            readonly property ConfigOption option: SettingsModel.option("preferred-resolution")

            width: parent.width
            textRole: "text"
            model: option.choices
            currentIndex: {
                const l = option.choices
                for (let i = 0; i < l.length; ++i)
                    if (l[i].value == option.value)
                        return i
                return -1
            }
            displayText: currentIndex >= 0 ? option.choices[currentIndex].text : ""
            onActivated: (i) => option.value = option.choices[i].value
            Accessible.name: qsTr("Resolution")
        }
    }

    PanelRow {
        label: qsTr("Aspect Ratio")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)

        VarChoiceDropdown {
            width: parent.width
            choiceModel: Player.aspectRatio
            Accessible.name: qsTr("Aspect Ratio")
        }
    }

    PanelRow {
        label: qsTr("Crop")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)

        VarChoiceDropdown {
            width: parent.width
            choiceModel: Player.crop
            Accessible.name: qsTr("Crop")
        }
    }

    PanelRow {
        label: qsTr("Render")
        rowHeight: VLCStyle.dp(68, VLCStyle.scale)
        controlWidth: VLCStyle.dp(218, VLCStyle.scale)

        EffectsDropdown {
            width: parent.width
            enabled: false
            textRole: "text"
            model: [{ text: qsTr("Local") }]
            currentIndex: 0
            Accessible.name: qsTr("Render")
        }
    }

    PanelHeading {
        text: qsTr("Filters")
        divider: true
    }

    PanelSubLabel { text: qsTr("Essential") }

    EffectParamsCard {
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_20

        params: PlayerEffects.essential
        showValue: false
    }

    PanelSubLabel { text: qsTr("Crop") }

    CropCard {
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_20
    }

    PanelSubLabel { text: qsTr("Colors") }

    ColorsCard {
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_20
    }
}
