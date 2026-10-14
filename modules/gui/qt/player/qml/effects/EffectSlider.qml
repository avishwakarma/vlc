
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

// One row of an effect card (Figma "Audio - Compressor" 536:1513): label and
// value above a slider. Double-click on the slider resets it to the neutral
// value. The row is bound to an EffectParam of the Effects controller.
ColumnLayout {
    id: root

    property EffectParam param: null

    // false for the video sliders, which show no value (Figma 536:1855)
    property bool showValue: true

    // EQ bands: the value is an editable field (Figma 6114:13610)
    property bool editable: false

    // draws the slider in its grey, switched off look
    property bool inactive: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    function formatted() {
        if (!param)
            return ""
        const v = param.value * param.displayMultiplier
        return v.toFixed(param.decimals) + param.unit
    }

    spacing: editable ? VLCStyle.spacing_10 : VLCStyle.dp(14.5, VLCStyle.scale)

    RowLayout {
        Layout.fillWidth: true

        Widgets.LabelExt {
            Layout.fillWidth: true

            text: root.param ? root.param.label : ""
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
            elide: Text.ElideRight
        }

        ValueField {
            visible: root.editable

            Layout.preferredWidth: VLCStyle.dp(138, VLCStyle.scale)

            value: root.param ? Number(root.param.value) : 0
            unit: root.param ? root.param.unit : ""
            from: root.param ? root.param.from : 0
            to: root.param ? root.param.to : 1
            onCommitted: (v) => { if (root.param) root.param.value = v }
        }

        Widgets.LabelExt {
            visible: root.showValue && !root.editable

            text: root.formatted()
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
        }
    }

    EffectSliderBar {
        Layout.fillWidth: true

        param: root.param
        inactive: root.inactive
        Accessible.name: root.param ? root.param.label : ""

    }
}
