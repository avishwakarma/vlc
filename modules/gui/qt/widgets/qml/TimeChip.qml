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

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// Time chip of the player control bar (Figma "current time" / "duration"):
// 76x28, radius 6, 15px text. Optionally clickable (duration toggles remaining time).
T.Button {
    id: root

    property bool clickable: false

    // text colour override (default: ToolButton Fg.Primary)
    property color textColor: theme.fg.primary

    implicitWidth: VLCStyle.timeChip_w
    implicitHeight: VLCStyle.seek_height

    padding: 0
    leftPadding: VLCStyle.spacing_8
    rightPadding: VLCStyle.spacing_8
    topPadding: VLCStyle.spacing_2
    bottomPadding: VLCStyle.spacing_2

    activeFocusOnTab: clickable
    focusPolicy: clickable ? Qt.StrongFocus : Qt.NoFocus
    hoverEnabled: clickable

    Accessible.role: clickable ? Accessible.Button : Accessible.StaticText
    Accessible.name: text

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton

        enabled: root.enabled
        focused: root.visualFocus
        hovered: root.clickable && root.hovered
        pressed: root.down
    }

    readonly property ColorContext itemColorContext: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item

        hovered: root.clickable && root.hovered
        pressed: root.clickable && root.down
    }

    background: Widgets.AnimatedBackground {
        radius: VLCStyle.radius_m
        enabled: theme.initialized
        color: (root.clickable && (root.hovered || root.down)) ? itemTheme.bg.primary : "transparent"
        border.color: root.visualFocus ? theme.visualFocus : "transparent"
    }

    contentItem: Text {
        text: root.text
        font.pixelSize: VLCStyle.text_time
        font.weight: VLCStyle.fontWeight_regular
        color: root.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideNone
        wrapMode: Text.NoWrap
    }
}
