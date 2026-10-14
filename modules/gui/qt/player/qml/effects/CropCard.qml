
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

// Video crop (Figma 543:990): top/bottom and left/right amounts in pixels with
// a link toggle that keeps the two sides equal. Applied live to the vout.
EffectCard {
    id: root

    rowSpacing: VLCStyle.dp(16, VLCStyle.scale)

    component CropRow: RowLayout {
        id: row

        property EffectParam first
        property EffectParam second
        property bool linked: false

        signal linkToggled(bool linked)

        Layout.fillWidth: true
        spacing: VLCStyle.spacing_8

        InlineField {
            Layout.fillWidth: true
            label: row.first.label
            unit: row.first.unit.trim()
            value: Number(row.first.value)
            onCommitted: (v) => row.first.value = v
        }

        InlineField {
            Layout.fillWidth: true
            label: row.second.label
            unit: row.second.unit.trim()
            value: Number(row.second.value)
            onCommitted: (v) => row.second.value = v
        }

        Widgets.IconToolButton {
            Layout.preferredWidth: VLCStyle.dp(24, VLCStyle.scale)

            iconName: "link"
            iconNameChecked: "link-active"
            checked: row.linked
            description: qsTr("Keep both sides equal")
            onClicked: row.linkToggled(!row.linked)
        }
    }

    CropRow {
        first: PlayerEffects.crop[0]
        second: PlayerEffects.crop[1]
        linked: PlayerEffects.cropLinkVertical
        onLinkToggled: (l) => PlayerEffects.cropLinkVertical = l
    }

    CropRow {
        first: PlayerEffects.crop[2]
        second: PlayerEffects.crop[3]
        linked: PlayerEffects.cropLinkHorizontal
        onLinkToggled: (l) => PlayerEffects.cropLinkHorizontal = l
    }
}
