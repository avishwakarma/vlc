
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
import VLC.Widgets as Widgets

// Video colour effects (Figma 614:1430): extraction, threshold, negate,
// posterize, gradient and sepia, each a filter of the vout chain. The vertical
// rhythm is explicit (margins in design pixels) to match the frame.
EffectCard {
    id: root

    rowSpacing: 0
    topGap: VLCStyle.dp(21, VLCStyle.scale)

    readonly property ColorContext colorContext2: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    function dp(n) { return VLCStyle.dp(n, VLCStyle.scale) }

    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(1, VLCStyle.scale)
        color: theme.separator
    }

    // label, colour chip, toggle
    component ColorToggleRow: RowLayout {
        id: row

        property FilterEffect effect
        property string label

        Layout.fillWidth: true
        spacing: VLCStyle.spacing_8

        Widgets.LabelExt {
            Layout.fillWidth: true
            text: row.label
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
        }

        HexColorField {
            rgb: Number(row.effect.params[0].value)
            onCommitted: (v) => row.effect.params[0].value = v
        }

        Widgets.CheckButton {
            text: ""
            checked: row.effect.enabled
            enabled: row.effect.available
            Accessible.name: row.label
            onToggled: row.effect.enabled = checked
        }
    }

    ColorToggleRow {
        effect: PlayerEffects.extract
        label: qsTr("Color Extraction")
    }

    Divider { Layout.topMargin: root.dp(19) }

    ColorToggleRow {
        Layout.topMargin: root.dp(20)
        effect: PlayerEffects.colorThreshold
        label: qsTr("Color Threshold")
    }

    EffectSlider {
        Layout.fillWidth: true
        Layout.topMargin: root.dp(16)
        param: PlayerEffects.colorThreshold.params[1]
        showValue: false
        inactive: !PlayerEffects.colorThreshold.enabled
    }

    EffectSlider {
        Layout.fillWidth: true
        Layout.topMargin: root.dp(21)
        param: PlayerEffects.colorThreshold.params[2]
        showValue: false
        inactive: !PlayerEffects.colorThreshold.enabled
    }

    Divider { Layout.topMargin: root.dp(20) }

    PanelToggleRow {
        Layout.topMargin: root.dp(20)
        label: qsTr("Negate Colors")
        checked: PlayerEffects.invert.enabled
        toggleEnabled: PlayerEffects.invert.available
        onToggled: (c) => PlayerEffects.invert.enabled = c
    }

    Divider { Layout.topMargin: root.dp(10) }

    PanelToggleRow {
        Layout.topMargin: root.dp(9)
        label: qsTr("Posterize")
        checked: PlayerEffects.posterize.enabled
        toggleEnabled: PlayerEffects.posterize.available
        onToggled: (c) => PlayerEffects.posterize.enabled = c
    }

    Divider { Layout.topMargin: root.dp(9) }

    PanelToggleRow {
        Layout.topMargin: root.dp(15)
        label: qsTr("Gradient")
        checked: PlayerEffects.gradient.enabled
        toggleEnabled: PlayerEffects.gradient.available
        onToggled: (c) => PlayerEffects.gradient.enabled = c
    }

    EffectsDropdown {
        id: gradientMode

        Layout.fillWidth: true
        Layout.topMargin: root.dp(16)

        readonly property var modeParam: PlayerEffects.gradient.params[0]

        model: modeParam.choices
        textRole: "text"
        currentIndex: {
            for (let i = 0; i < modeParam.choices.length; ++i)
                if (modeParam.choices[i].value === modeParam.value)
                    return i
            return 0
        }
        displayText: currentIndex >= 0 ? modeParam.choices[currentIndex].text : ""
        onActivated: (i) => modeParam.value = modeParam.choices[i].value
    }

    PanelToggleRow {
        Layout.topMargin: root.dp(16)
        label: qsTr("Color")
        checked: PlayerEffects.gradient.params[1].value
        onToggled: (c) => PlayerEffects.gradient.params[1].value = c
    }

    PanelToggleRow {
        Layout.topMargin: root.dp(15)
        label: qsTr("Cartoon")
        checked: PlayerEffects.gradient.params[2].value
        onToggled: (c) => PlayerEffects.gradient.params[2].value = c
    }

    Divider { Layout.topMargin: root.dp(15) }

    EffectSlider {
        Layout.fillWidth: true
        Layout.topMargin: root.dp(19)
        param: PlayerEffects.sepia.params[0]
        showValue: false
    }
}
