
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

// Card of slider rows, one per EffectParam (compressor, spatializer, stereo
// widener, video essential, equalizer).
EffectCard {
    id: root

    property var params: []
    property bool showValue: true
    property bool editable: false

    topGap: editable ? VLCStyle.dp(24, VLCStyle.scale) : VLCStyle.dp(26, VLCStyle.scale)

    Repeater {
        model: root.params

        EffectSlider {
            required property var modelData

            Layout.fillWidth: true

            param: modelData
            showValue: root.showValue
            editable: root.editable
        }
    }
}
