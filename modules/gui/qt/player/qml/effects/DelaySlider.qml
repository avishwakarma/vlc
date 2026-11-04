
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
import VLC.Widgets as Widgets

// Slider with its fill drawn from a pivot (usually the middle) to the handle,
// used for the synchronisation delays (Figma panels "Audio"/"Subtitles"):
// B2 track, accent bright fill, accent dim handle, labels below.
T.Slider {
    id: control

    // value at which the fill starts
    property real pivot: (from + to) / 2

    // labels under the track ("-10 s", "0 s", "+10 s"); empty list for none
    property var labels: []

    signal reset()

    implicitWidth: VLCStyle.dp(360, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(24, VLCStyle.scale) + (labels.length ? VLCStyle.spacing_8 + labelRow.implicitHeight : 0)

    focusPolicy: Qt.StrongFocus

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: control.hovered
    }

    readonly property real _hw: VLCStyle.icon_xsmall
    readonly property real _track: VLCStyle.heightBar_small
    readonly property real _span: availableWidth - _hw
    readonly property real _pivotX: _hw / 2 + (pivot - from) / (to - from) * _span
    readonly property real _valueX: _hw / 2 + position * _span

    opacity: enabled ? 1.0 : 0.3

    handle: Rectangle {
        x: control.leftPadding + control._valueX - width / 2
        y: control.topPadding + (VLCStyle.dp(24, VLCStyle.scale) - height) / 2

        implicitWidth: control._hw
        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
        radius: VLCStyle.radius_s

        color: control.pressed ? theme.accentDim
                               : (control.hovered || control.visualFocus ? theme.accent : theme.accentDim)

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus

        Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
    }

    background: Item {
        implicitHeight: control.implicitHeight

        Rectangle {
            x: control.leftPadding
            y: control.topPadding + (VLCStyle.dp(24, VLCStyle.scale) - control._track) / 2
            width: control.availableWidth
            height: control._track
            radius: VLCStyle.radius_m
            color: theme.bg.primary

            Rectangle {
                x: Math.min(control._pivotX, control._valueX)
                y: control.fillInset
                width: Math.abs(control._valueX - control._pivotX)
                height: parent.height - 2 * control.fillInset
                radius: VLCStyle.radius_s
                color: theme.fg.primary
            }
        }
    }

    readonly property real fillInset: VLCStyle.spacing_2

    Item {
        id: labelRow

        visible: control.labels.length > 0
        x: control.leftPadding
        y: control.height - implicitHeight
        width: control.availableWidth
        implicitHeight: VLCStyle.text_caption + VLCStyle.spacing_4

        Repeater {
            model: control.labels

            Widgets.LabelExt {
                required property string modelData
                required property int index

                // first label flush left, last flush right, the others centred on their tick
                x: (index / (control.labels.length - 1)) * (parent.width - width)
                text: modelData
                font.pixelSize: VLCStyle.text_caption
                color: control.colorContext.fg.secondary
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onDoubleTapped: control.reset()
    }
}
