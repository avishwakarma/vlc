
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

// An audio effect of the Filters block: title with an enable toggle, then the
// expandable card with its sliders.
ColumnLayout {
    id: root

    property string title: ""
    property FilterEffect effect: null
    property var params: []
    property bool showValue: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    visible: effect ? effect.available : false
    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.spacing_24
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_12

        Widgets.LabelExt {
            Layout.fillWidth: true

            text: root.title
            font.pixelSize: VLCStyle.text_body
            color: theme.fg.secondary
        }

        Widgets.CheckButton {
            text: ""
            checked: root.effect ? root.effect.enabled : false
            onToggled: root.effect.enabled = checked
            Accessible.name: root.title
        }
    }

    EffectParamsCard {
        Layout.leftMargin: VLCStyle.spacing_20
        Layout.rightMargin: VLCStyle.spacing_20
        Layout.bottomMargin: VLCStyle.spacing_20

        params: root.params
        showValue: root.showValue
        opacity: root.effect && root.effect.enabled ? 1.0 : 0.6

        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
    }
}
