/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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
import VLC.Util

// Themed SVG icon from the /svgicons/ resource prefix (pixmaps/svg_icons).
// color replaces #FF00FF, accentColor #FF8800 and accentDimColor #00FFFF.
Image {
    id: root

    // file name without extension, e.g. "home-active"
    property string name

    // logical size in device independent pixels
    property real size: VLCStyle.icon_normal

    property color color: _theme.fg.primary
    property color accentColor: _theme.accent
    property color accentDimColor: Qt.darker(accentColor, 1.3)

    readonly property ColorContext _theme: ColorContext {
        colorSet: ColorContext.ToolButton
    }

    implicitWidth: size
    implicitHeight: size

    sourceSize: Qt.size(size * Screen.devicePixelRatio, size * Screen.devicePixelRatio)

    fillMode: Image.PreserveAspectFit
    asynchronous: false
    cache: true
    smooth: true
    mipmap: true

    source: (name === "")
        ? ""
        : SVGColorImage.colorize("qrc:///svgicons/" + name + ".svg")
                       .color1(color)
                       .accent(accentColor)
                       .color2(accentDimColor)
                       .uri()

    Accessible.ignored: true
}
