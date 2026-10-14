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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

// Figma dialog/onboarding button, 100x32, radius 6.
//   DialogButton { text: qsTr("Cancel") }                           // secondary
//   DialogButton { kind: DialogButton.Primary; text: qsTr("Save") }  // tonal accent
//   DialogButton { kind: DialogButton.Accent; text: qsTr("Next") }   // solid accent, 16 px
T.Button {
    id: control

    enum Kind {
        Secondary,
        Primary,
        Accent
    }

    property int kind: DialogButton.Secondary

    implicitWidth: Math.max(VLCStyle.dp(100, VLCStyle.scale),
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: VLCStyle.toggle_h

    leftPadding: VLCStyle.spacing_12
    rightPadding: VLCStyle.spacing_12

    font.pixelSize: (kind === DialogButton.Accent) ? VLCStyle.text_heading : VLCStyle.text_body
    font.weight: VLCStyle.fontWeight_semibold

    opacity: enabled ? 1.0 : 0.5

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    Accessible.onPressAction: control.clicked()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: (control.kind === DialogButton.Accent) ? ColorContext.ButtonAccent
                : (control.kind === DialogButton.Primary) ? ColorContext.ButtonTonal
                : ColorContext.Window

        enabled: control.enabled
        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
    }

    readonly property ColorContext _itemTheme: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item

        hovered: control.hovered
        pressed: control.down
    }

    readonly property ColorContext _viewTheme: ColorContext {
        id: viewTheme
        colorSet: ColorContext.View
    }

    readonly property color _bg: (kind === DialogButton.Secondary)
                                 ? ((hovered || down) ? itemTheme.bg.primary : theme.bg.primary)
                                 : theme.bg.primary

    readonly property color _fg: (kind === DialogButton.Secondary) ? viewTheme.fg.primary
                                                                     : theme.fg.primary

    background: Rectangle {
        radius: VLCStyle.radius_m
        color: control._bg

        border.width: control.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: theme.visualFocus

        Behavior on color {
            ColorAnimation { duration: VLCStyle.duration_short }
        }
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: control._fg
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText

        Accessible.ignored: true
    }
}
