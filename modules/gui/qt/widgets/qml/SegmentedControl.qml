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

// Figma "Values" segmented control: a well (bg.secondary) holding equal-width
// segments. The active segment uses the tonal accent colors.
//
// model: list of strings, or of objects with `textRole` (default "text")
// and an optional `iconName` (SvgIcon name) per entry.
//
//   SegmentedControl {
//       model: [qsTr("Dark"), qsTr("Light"), qsTr("System")]
//       currentIndex: 0
//       onActivated: (index) => ...
//   }
T.Control {
    id: control

    // Properties

    property var model: []

    property string textRole: "text"

    property int currentIndex: 0

    // 36 px (true) or 44 px (false) high
    property bool compact: false

    readonly property int count: model ? (model.length ?? model.count ?? 0) : 0

    // emitted when the user selects a segment
    signal activated(int index)

    // Settings

    implicitWidth: VLCStyle.size_segmented_w
    implicitHeight: compact ? VLCStyle.segmentedCompact_h : VLCStyle.segmented_h

    padding: VLCStyle.spacing_2

    focusPolicy: Qt.StrongFocus

    opacity: enabled ? 1.0 : 0.3

    // Keys

    Keys.priority: Keys.AfterItem

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            const delta = (event.key === Qt.Key_Right) === !control.mirrored ? 1 : -1
            const next = control.currentIndex + delta
            if (next >= 0 && next < control.count) {
                control.currentIndex = next
                control.activated(next)
                event.accepted = true
                return
            }
        }
        Navigation.defaultKeyAction(event)
    }

    Accessible.role: Accessible.RadioButton

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ComboBox // bg.secondary = well, bg.primary = inactive segment, fg.primary = text

        enabled: control.enabled
        focused: control.visualFocus
    }

    readonly property ColorContext _viewTheme: ColorContext {
        id: viewTheme
        colorSet: ColorContext.View
    }

    background: Rectangle {
        radius: VLCStyle.radius_m
        color: theme.bg.secondary

        border.width: VLCStyle.border
        border.color: control.visualFocus ? theme.visualFocus : theme.border
    }

    contentItem: Row {
        spacing: VLCStyle.spacing_2

        Repeater {
            model: control.model

            delegate: T.AbstractButton {
                id: segment

                required property int index
                required property var modelData

                readonly property bool active: control.currentIndex === index

                readonly property string label: (typeof modelData === "string") ? modelData
                                                                                 : (modelData[control.textRole] ?? "")
                readonly property string iconName: (typeof modelData === "string") ? "" : (modelData.iconName ?? "")

                width: (control.availableWidth - (control.count - 1) * VLCStyle.spacing_2) / Math.max(1, control.count)
                height: control.availableHeight

                text: label

                focusPolicy: Qt.NoFocus

                onClicked: {
                    if (control.currentIndex !== index)
                        control.currentIndex = index
                    control.activated(index)
                }

                Accessible.role: Accessible.RadioButton
                Accessible.checked: active

                readonly property ColorContext colorContext: ColorContext {
                    id: tonal
                    colorSet: ColorContext.ButtonTonal

                    enabled: segment.enabled
                    hovered: segment.hovered
                    pressed: segment.down
                }

                readonly property ColorContext _itemTheme: ColorContext {
                    id: itemTheme
                    colorSet: ColorContext.Item

                    hovered: segment.hovered
                    pressed: segment.down
                }

                background: Rectangle {
                    radius: VLCStyle.radius_s

                    color: segment.active ? tonal.bg.primary
                                          : ((segment.hovered || segment.down) ? itemTheme.bg.primary
                                                                               : theme.bg.primary)

                    Behavior on color {
                        ColorAnimation { duration: VLCStyle.duration_short }
                    }
                }

                contentItem: Item {
                  Row {
                    anchors.centerIn: parent
                    spacing: VLCStyle.spacing_6

                    SvgIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: segment.iconName !== ""
                        name: segment.iconName
                        size: VLCStyle.icon_normal
                        color: segment.active ? tonal.fg.primary : viewTheme.fg.secondary
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text: segment.label
                        color: segment.active ? tonal.fg.primary
                                              : ((segment.hovered || segment.down) ? viewTheme.fg.highlight
                                                                                    : viewTheme.fg.secondary)
                        font.pixelSize: VLCStyle.text_body
                        font.weight: VLCStyle.fontWeight_regular
                        elide: Text.ElideRight

                        Behavior on color {
                            ColorAnimation { duration: VLCStyle.duration_short }
                        }
                    }
                  }
                }
            }
        }
    }
}
