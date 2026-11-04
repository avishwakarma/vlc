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

// Figma "Toggle" (68x32): a well (Switch bg.primary) holding a label area and
// a thumb. The label area always sits opposite to the thumb.
T.Switch {
    id: root

    // Style

    property int animationDuration: VLCStyle.duration_short

    // show the "ON"/"OFF" label
    property bool showLabel: true

    property color color: theme.bg.primary                 // well
    property color colorOn: theme.bg.secondary             // label area, ON
    property color colorOff: offTheme.bg.primary           // label area, OFF
    property color colorHandle: (checked) ? theme.fg.secondary
                                          : theme.fg.primary
    property color colorLabelOn: theme.accentText
    property color colorLabelOff: viewTheme.fg.secondary

    // Settings

    implicitWidth: VLCStyle.toggle_w
    implicitHeight: VLCStyle.toggle_h

    width: implicitWidth
    height: implicitHeight

    opacity: enabled ? 1.0 : 0.3

    T.ToolTip.visible: (T.ToolTip.text && (hovered || visualFocus))
    T.ToolTip.text: text
    T.ToolTip.delay: VLCStyle.delayToolTipAppear

    // Keys

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // Accessible

    Accessible.onPressAction: root.toggle()
    Accessible.onToggleAction: root.toggle()

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Switch

        enabled: root.enabled
        focused: root.visualFocus
        hovered: root.hovered
        pressed: root.down
    }

    readonly property ColorContext _offTheme: ColorContext {
        id: offTheme
        colorSet: ColorContext.ComboBox
    }

    readonly property ColorContext _viewTheme: ColorContext {
        id: viewTheme
        colorSet: ColorContext.View
    }

    readonly property real _inset: VLCStyle.spacing_2 + VLCStyle.spacing_2 / 2 // 3
    readonly property real _thumb: height - 2 * _inset                         // 26
    readonly property real _area: width - 3 * _inset - _thumb  // 33

    background: Rectangle {
        radius: VLCStyle.radius_m
        color: root.color

        border.width: VLCStyle.border
        border.color: root.visualFocus ? theme.visualFocus
                                       : (root.hovered ? theme.fg.primary : theme.separator)

        Behavior on border.color {
            ColorAnimation { duration: root.animationDuration }
        }
    }

    indicator: Item {
        anchors.fill: parent

        Rectangle {
            id: area

            y: root._inset
            width: root._area
            height: root._thumb
            radius: VLCStyle.radius_xs

            x: root.checked ? root._inset : (root.width - root._inset - width)

            color: root.checked ? root.colorOn : root.colorOff

            Behavior on x {
                NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutQuad }
            }

            Behavior on color {
                ColorAnimation { duration: root.animationDuration }
            }

            Text {
                anchors.centerIn: parent
                visible: root.showLabel

                text: root.checked ? qsTr("ON") : qsTr("OFF")
                color: root.checked ? root.colorLabelOn : root.colorLabelOff
                font.pixelSize: VLCStyle.text_caption

                Accessible.ignored: true
            }
        }

        Rectangle {
            id: thumb

            y: root._inset
            width: root._thumb
            height: root._thumb
            radius: VLCStyle.radius_xs

            x: root.checked ? (root.width - root._inset - width) : root._inset

            color: root.down ? (root.checked ? theme.accent : theme.fg.highlight) : root.colorHandle

            Behavior on x {
                NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutQuad }
            }

            Behavior on color {
                ColorAnimation { duration: root.animationDuration }
            }
        }
    }
}
