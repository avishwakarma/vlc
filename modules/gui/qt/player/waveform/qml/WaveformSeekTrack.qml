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

import VLC.Player
import VLC.Style
import VLC.MainInterface

// Waveform drawn inside the SliderBar track (Figma 2139:8124, music bar 4767:23726).
// The SliderBar keeps the input handling (click, drag, wheel, keys) and the tooltip;
// this item only draws the bars and the playhead and tells whether it can be shown.
Item {
    id: root

    // the SliderBar
    required property Item slider

    // media to analyse, empty to disable
    property url source: ""

    // pointer x in the track while hovered or dragged, < 0 otherwise
    property real pointerX: -1

    // peaks exist or are being computed: the bar shows the waveform
    readonly property bool active: waveform.available

    function positionAt(x) {
        return Math.max(0, Math.min(1, waveform.positionAt(x)))
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: root.slider.enabled
    }

    opacity: active ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: VLCStyle.duration_long
            easing.type: Easing.OutCubic
        }
    }

    WaveformItem {
        id: waveform

        anchors.fill: parent

        ctx: MainCtx
        source: root.source

        position: root.slider.visualPosition
        hoverX: root.pointerX

        playedColor: theme.fg.secondary
        remainingColor: theme.indicator
        playheadColor: root.slider.handleColor

        barWidth: VLCStyle.waveform_barWidth
        barSpacing: VLCStyle.waveform_barSpacing
        barMinHeight: VLCStyle.waveform_barMinHeight
        barMaxHeight: VLCStyle.waveform_barMaxHeight
        leftPadding: VLCStyle.waveform_padding
        rightPadding: VLCStyle.waveform_padding
        playheadWidth: VLCStyle.waveform_playheadWidth
        playheadInset: VLCStyle.spacing_2
        playheadGap: VLCStyle.waveform_playheadGap

        animationDuration: VLCStyle.duration_long
    }
}
