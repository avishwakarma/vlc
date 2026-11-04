/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQuick.Layouts

import VLC.Widgets as Widgets
import VLC.MainInterface
import VLC.Style

// Window button of the slim title bar (Figma: 36x28 cell, 24px SVG icon, radius 6)
T.Button {
    id: control

    property color color
    property color hoverColor
    property color hoverIconColor: control.color
    property string iconName: ""
    property bool showHovered: false
    property bool externalPressed: false

    // kept for API compatibility with the previous glyph based button
    property string iconTxt: ""
    property bool isThemeDark: false

    readonly property bool _paintHovered: control.hovered || showHovered

    padding: 0
    width: VLCStyle.windowButton_w
    height: VLCStyle.windowButton_h

    implicitWidth: VLCStyle.windowButton_w
    implicitHeight: VLCStyle.windowButton_h

    focusPolicy: Qt.NoFocus

    Accessible.name: iconName

    background: Rectangle {
        radius: VLCStyle.radius_m

        color: {
            if (control.pressed || (control.externalPressed && control._paintHovered))
                return Qt.alpha(control.hoverColor, 0.8)

            if (control._paintHovered)
                return control.hoverColor

            return Qt.alpha(control.hoverColor, 0.0)
        }

        Behavior on color {
            ColorAnimation {
                duration: VLCStyle.duration_veryShort
            }
        }
    }

    contentItem: Item {
        Widgets.SvgIcon {
            anchors.centerIn: parent

            name: control.iconName
            size: VLCStyle.icon_normal
            color: control._paintHovered ? control.hoverIconColor : control.color
        }
    }
}
