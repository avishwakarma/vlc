
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

// Settings > Subtitles (Figma 763:1958): defaults, synchronisation and the
// appearance of the rendered text.
SettingsTabBase {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    PanelHeading {
        text: qsTr("Defaults")
    }

    PanelRow {
        label: qsTr("Subtitle Track")
        OptionField { width: parent.width; option: SettingsModel.option("sub-track"); numeric: true; Accessible.name: qsTr("Subtitle Track") }
    }

    PanelRow {
        label: qsTr("Subtitle Language")
        OptionField { width: parent.width; option: SettingsModel.option("sub-language"); Accessible.name: qsTr("Subtitle Language") }
    }

    PanelDivider {}

    PanelHeading {
        text: qsTr("Synchronization")
    }

    PanelRow {
        Layout.topMargin: VLCStyle.spacing_2
        label: qsTr("Subtitle Track Delay")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)

        ValueField {
            width: parent.width
            font.pixelSize: VLCStyle.text_body
            decimals: 3
            unit: " s"
            from: -100
            to: 100
            value: Player.subtitleDelayMS / 1000
            onCommitted: (v) => Player.subtitleDelayMS = Math.round(v * 1000)
            Accessible.name: qsTr("Subtitle Track Delay")
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
        value: Math.max(from, Math.min(to, Player.subtitleDelayMS / 1000))
        labels: [qsTr("-10 s"), qsTr("0 s"), qsTr("+10 s")]
        onMoved: Player.subtitleDelayMS = Math.round(value * 1000)
        onReset: Player.subtitleDelayMS = 0
        Accessible.name: qsTr("Subtitle Track Delay")
    }

    PanelRow {
        label: qsTr("Subtitle Speed")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)

        ValueField {
            width: parent.width
            font.pixelSize: VLCStyle.text_body
            decimals: 3
            unit: " fps"
            from: 0
            to: 10
            value: Player.subtitleFPS
            onCommitted: (v) => Player.subtitleFPS = v
            Accessible.name: qsTr("Subtitle Speed")
        }
    }

    DelaySlider {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.spacing_8
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.dp(5, VLCStyle.scale)

        from: 0
        to: 10
        pivot: 0
        stepSize: 0.01
        value: Player.subtitleFPS
        onMoved: Player.subtitleFPS = value
        onReset: Player.subtitleFPS = 1
        Accessible.name: qsTr("Subtitle Speed")
    }

    PanelRow {
        label: qsTr("Subtitle Duration Factor")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)
        visible: PlayerEffects.subsDelay.available

        ValueField {
            width: parent.width
            font.pixelSize: VLCStyle.text_body
            decimals: 3
            from: 0
            to: 10
            value: Number(PlayerEffects.subsDelay.params[0].value)
            onCommitted: (v) => PlayerEffects.subsDelay.params[0].value = v
            Accessible.name: qsTr("Subtitle Duration Factor")
        }
    }

    DelaySlider {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.spacing_8
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.dp(5, VLCStyle.scale)

        visible: PlayerEffects.subsDelay.available
        from: 0
        to: 10
        pivot: 0
        value: Number(PlayerEffects.subsDelay.params[0].value)
        onMoved: PlayerEffects.subsDelay.params[0].value = value
        onReset: PlayerEffects.subsDelay.params[0].reset()
        Accessible.name: qsTr("Subtitle Duration Factor")
    }

    PanelDivider {}

    PanelHeading {
        text: qsTr("Appearance")
    }

    PanelRow {
        label: qsTr("Subtitle Font")
        OptionField { width: parent.width; option: SettingsModel.option("freetype-font"); Accessible.name: qsTr("Subtitle Font") }
    }

    PanelRow {
        label: qsTr("Text Color")
        OptionColorField { width: parent.width; option: SettingsModel.option("freetype-color"); Accessible.name: qsTr("Text Color") }
    }

    PanelRow {
        label: qsTr("Outline Color")
        OptionColorField { width: parent.width; option: SettingsModel.option("freetype-outline-color"); Accessible.name: qsTr("Outline Color") }
    }

    // Subtitle size: relative text scale in percent
    PanelRow {
        label: qsTr("Subtitle Size")
        rowHeight: VLCStyle.dp(52, VLCStyle.scale)

        ValueField {
            readonly property ConfigOption option: SettingsModel.option("sub-text-scale")

            width: parent.width
            font.pixelSize: VLCStyle.text_body
            decimals: 0
            unit: " %"
            from: 10
            to: 500
            value: Number(option.value)
            onCommitted: (v) => option.value = Math.round(v)
            Accessible.name: qsTr("Subtitle Size")
        }
    }

    Widgets.SliderExt {
        id: sizeSlider

        readonly property ConfigOption option: SettingsModel.option("sub-text-scale")

        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_10

        handleColor: colorContext.accentDim
        handleHeight: VLCStyle.dp(24, VLCStyle.scale)
        from: 10
        to: 500
        stepSize: 0
        value: Number(option.value)
        onMoved: option.value = Math.round(value)
        Widgets.PointingToolTipAttached.visible: false
        Accessible.name: qsTr("Subtitle Size")

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onDoubleTapped: sizeSlider.option.reset()
        }
    }
}
