
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

// Playback speed slider 0.25 - 2 with tick labels (Figma 2238:9432). The
// slider position is linear in the displayed values; 1x snaps in place.
ColumnLayout {
    id: root

    spacing: VLCStyle.dp(10, VLCStyle.scale)

    readonly property var stops: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Widgets.SliderExt {
        id: slider

        Layout.fillWidth: true

        handleColor: Qt.darker(colorContext.accent, 1.23)
        handleHeight: VLCStyle.dp(24, VLCStyle.scale)
        from: 0.25
        to: 2
        stepSize: 0
        enabled: Player.ratechangable
        value: Math.max(from, Math.min(to, Player.rate))
        Accessible.name: qsTr("Playback speed")

        onMoved: {
            // snap to the ticks when close
            let v = value
            for (const s of root.stops)
                if (Math.abs(v - s) < 0.04)
                    v = s
            Player.rate = Math.round(v * 100) / 100
        }

        Widgets.PointingToolTipAttached.visible: false

        Repeater {
            model: root.stops.length

            Rectangle {
                required property int index

                x: slider.leftPadding + slider.handleWidth / 2 + index / (root.stops.length - 1) * (slider.availableWidth - slider.handleWidth) - width / 2
                y: (slider.height - height) / 2
                z: -0.5
                width: VLCStyle.dp(1, VLCStyle.scale)
                height: VLCStyle.spacing_6
                color: theme.fg.secondary
                opacity: 0.45
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onDoubleTapped: Player.rate = 1
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.text_caption + VLCStyle.spacing_4

        Repeater {
            model: root.stops

            Widgets.LabelExt {
                required property real modelData
                required property int index

                x: (index / (root.stops.length - 1)) * (parent.width - width)
                text: modelData
                font.pixelSize: VLCStyle.text_caption
                color: theme.fg.secondary
            }
        }
    }
}
