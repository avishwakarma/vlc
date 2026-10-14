/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
 *
 * Authors: Prince Gupta <guptaprince8832@gmail.com>
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

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

T.Slider {
    id: control

    // helper to set colors based on given particular theme
    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: control.hovered
    }

    // colors based on different parts and states
    // played fill (accent bright), track (well) and thumb (accent)
    property color color: theme.fg.primary
    property color bgColor: theme.bg.primary
    property color handleColor: theme.accent

    // Figma: 8 px wide thumb pill, taller than the track
    property real handleWidth: VLCStyle.icon_xsmall
    property real handleHeight: VLCStyle.heightBar_small + VLCStyle.spacing_4
    property real trackHeight: VLCStyle.heightBar_small

    // inset of the played fill inside the track
    property real fillInset: VLCStyle.spacing_2

    property real radius: VLCStyle.radius_m

    // when set the tooltip will follow the mouse when control is hoverred
    // else tooltip will always be shown at current value.
    property bool toolTipFollowsMouse: false

    // toolTipTextProvider -> function(value)
    // arg "value" is between from and to, this is "value"
    // at which pointing tool tip is currently shown
    //
    // returns the text for the given value
    property var toolTipTextProvider: function (value) {
        return value
    }

    readonly property real _tooltipX: {
        if (toolTipFollowsMouse && hoverHandler.hovered)
            return  hoverHandler.point.position.x

        return (handle.x + handle.width / 2) // handle center
    }

    // find position under given x, can be used with Slider::valueAt()
    // x is coordinate in this control's coordinate space
    function positionAt(x) {
        // taken from qt sources QQuickSlider.cpp
        // TODO: support vertical slider
        const hw = control.handle.width
        const offset = control.leftPadding + hw / 2
        const extend = control.availableWidth - hw
        return (x - offset) / extend
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitHandleWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitHandleHeight + topPadding + bottomPadding)

    opacity: enabled ? 1.0 : 0.3

    handle: Rectangle {
        x: control.leftPadding + (control.horizontal
                                  ? control.visualPosition * (control.availableWidth - width)
                                  : (control.availableWidth - width) / 2)

        y: control.topPadding + (control.horizontal
                                 ? (control.availableHeight - height) / 2
                                 : control.visualPosition * (control.availableHeight - height))

        implicitWidth: control.horizontal ? control.handleWidth : control.handleHeight
        implicitHeight: control.horizontal ? control.handleHeight : control.handleWidth

        radius: VLCStyle.radius_s

        color: control.pressed ? Qt.darker(control.handleColor, 1.2)
                               : (control.hovered || control.visualFocus ? Qt.lighter(control.handleColor, 1.15)
                                                                          : control.handleColor)

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus

        Behavior on color {
            ColorAnimation { duration: VLCStyle.duration_short }
        }
    }

    background: Rectangle {
        x: control.leftPadding + (control.horizontal ? 0 : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2 : 0)

        implicitWidth: control.horizontal ? VLCStyle.heightBar_xlarge : control.trackHeight
        implicitHeight: control.horizontal ? control.trackHeight : VLCStyle.heightBar_xlarge

        width: control.horizontal ? control.availableWidth : implicitWidth
        height: control.horizontal ? implicitHeight : control.availableHeight

        radius: control.radius

        color: control.bgColor
        scale: control.horizontal && control.mirrored ? -1 : 1

        Rectangle {
            x: control.horizontal ? control.fillInset : control.fillInset
            y: control.horizontal ? control.fillInset
                                  : control.visualPosition * parent.height + control.fillInset

            width: control.horizontal ? Math.max(0, control.position * (parent.width - control.handleWidth)
                                                    + control.handleWidth / 2 - control.fillInset)
                                      : parent.width - 2 * control.fillInset
            height: control.horizontal ? parent.height - 2 * control.fillInset
                                       : Math.max(0, control.position * parent.height - control.fillInset)

            radius: VLCStyle.radius_s
            color: control.color
        }
    }

    HoverHandler {
        id: hoverHandler

        enabled: true

        target: background
    }

    Widgets.PointingToolTipAttached.pos: Qt.point(control._tooltipX, control.handle.height / 2)
    Widgets.PointingToolTipAttached.visible: (hoverHandler.hovered || control.visualFocus || control.pressed)
    Widgets.PointingToolTipAttached.text: {
        if (!Widgets.PointingToolTipAttached.instance?.visible)
            return ""

        // position is only measured till half of handle width
        // pos.x may go beyond the position at the edges
        const p = Helpers.clamp(control.positionAt(Widgets.PointingToolTipAttached.instance.pos.x), 0.0, 1.0)
        const v = control.valueAt(p)
        return control.toolTipTextProvider(v)
    }

}
