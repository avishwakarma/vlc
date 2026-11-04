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
import QtQuick.Shapes

import VLC.Style

// 1 px dashed outline (Figma customize mode: drop zones and palette items)
Item {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    property color color: theme.fg.secondary
    property real radius: 0
    property real lineWidth: 1
    // dash and gap lengths, in line widths
    property var dashPattern: [4, 3]

    Shape {
        anchors.fill: parent

        // thin dashes need anti-aliasing
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: root.dashPattern
            capStyle: ShapePath.FlatCap

            // the stroke is centred on the path: keep it inside the item
            PathRectangle {
                x: root.lineWidth / 2
                y: root.lineWidth / 2
                width: Math.max(0, root.width - root.lineWidth)
                height: Math.max(0, root.height - root.lineWidth)
                radius: Math.max(0, root.radius - root.lineWidth / 2)
            }
        }
    }
}
