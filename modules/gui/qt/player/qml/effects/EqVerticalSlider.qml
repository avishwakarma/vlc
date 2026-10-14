
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

import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

// Vertical band slider of the wide equalizer (Figma 3178:16769): 12 px track
// with accent fill from the bottom, 24x8 horizontal handle.
Widgets.SliderExt {
    id: control

    property EffectParam param: null

    orientation: Qt.Vertical

    from: param ? param.from : -20
    to: param ? param.to : 20
    stepSize: 0
    value: param ? Number(param.value) : 0

    trackHeight: VLCStyle.dp(12, VLCStyle.scale)
    handleColor: Qt.darker(colorContext.accent, 1.23)
    handleHeight: VLCStyle.dp(24, VLCStyle.scale)
    handleWidth: VLCStyle.icon_xsmall
    fillInset: VLCStyle.dp(1, VLCStyle.scale)

    implicitWidth: handleHeight
    implicitHeight: VLCStyle.dp(320, VLCStyle.scale)

    Widgets.PointingToolTipAttached.visible: false

    onMoved: {
        if (!param)
            return
        const step = 0.1
        param.value = Math.max(from, Math.min(to, Math.round(value / step) * step))
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        // like the QWidget panel: back to the preset's value
        onDoubleTapped: if (control.param) control.param.reset()
    }
}
