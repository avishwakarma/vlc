
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
import QtQuick.Templates as T

import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Util

// Slider bound to an EffectParam: Figma track (B2, 16 high) with accent fill,
// accent-dim thumb and optional tick marks. Double-click resets the value.
Widgets.SliderExt {
    id: control

    property EffectParam param: null

    // vertical sliders are only used by the wide equalizer
    readonly property int ticks: param ? param.ticks : 0

    from: param ? param.from : 0
    to: param ? param.to : 1
    stepSize: 0

    // bound manually so that dragging does not fight the model
    value: param ? Number(param.value) : 0

    onMoved: {
        if (!param)
            return
        const step = param.stepSize
        const v = step > 0 ? Math.round(value / step) * step : value
        param.value = Math.max(from, Math.min(to, v))
    }

    // the track fill uses the pointing tooltip of the base slider, not needed here
    Widgets.PointingToolTipAttached.visible: false

    // Figma: 24 px accent-dim thumb on a 16 px track
    // slider of a switched off effect (Figma 614:1430): grey handle and fill
    property bool inactive: false

    handleColor: inactive ? colorContext.fg.secondary : colorContext.accentDim
    color: inactive ? colorContext.hoverPlate : colorContext.fg.primary
    bgColor: colorContext.bg.primary
    handleHeight: VLCStyle.dp(24, VLCStyle.scale)
    trackHeight: VLCStyle.heightBar_small

    Repeater {
        model: control.ticks > 1 ? control.ticks - 1 : 0

        Rectangle {
            required property int index

            readonly property real hw: control.handle.width

            x: control.leftPadding + hw / 2 + (index + 1) * (control.availableWidth - hw) / control.ticks - width / 2
            y: (control.height - height) / 2
            z: -0.5

            width: VLCStyle.dp(1, VLCStyle.scale)
            height: VLCStyle.spacing_6

            color: control.colorContext.fg.secondary
            opacity: 0.45
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onDoubleTapped: if (control.param) control.param.reset()
    }
}
