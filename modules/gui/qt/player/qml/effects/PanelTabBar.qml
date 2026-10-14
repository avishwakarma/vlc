
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
import QtQuick.Templates as T

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Tab header of the popover panels (Figma control-bar variants): B2 strip,
// 50 px high, equal width tabs with a 20 px icon, a 12 px label and a 2 px
// accent underline below the active tab.
//   model: [{ text, icon }]  (icon: SvgIcon name, "<icon>-active" is used for the active tab)
FocusScope {
    id: control

    property var model: []
    property int currentIndex: 0

    implicitWidth: VLCStyle.popoverPanel_w
    implicitHeight: VLCStyle.popoverTab_h

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.fill: parent

        color: theme.bg.secondary
        topLeftRadius: VLCStyle.radius_l
        topRightRadius: VLCStyle.radius_l
    }

    // Left / Right move between the tabs
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left && control.currentIndex > 0) {
            control.currentIndex--
            event.accepted = true
        } else if (event.key === Qt.Key_Right && control.currentIndex < control.model.length - 1) {
            control.currentIndex++
            event.accepted = true
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: VLCStyle.spacing_6
        anchors.rightMargin: VLCStyle.spacing_6

        spacing: VLCStyle.dp(1, VLCStyle.scale)

        Repeater {
            model: control.model

            T.AbstractButton {
                id: tab

                required property var modelData
                required property int index

                readonly property bool current: control.currentIndex === index

                width: (parent.width - (control.model.length - 1) * parent.spacing) / control.model.length
                height: parent.height

                focusPolicy: Qt.StrongFocus

                Accessible.name: modelData.text
                Accessible.role: Accessible.PageTab

                onClicked: {
                    control.currentIndex = index
                    control.forceActiveFocus()
                }

                readonly property ColorContext itemTheme: ColorContext {
                    id: tabTheme
                    colorSet: ColorContext.Item

                    focused: tab.visualFocus
                    hovered: tab.hovered
                    pressed: tab.down
                    enabled: tab.enabled
                }

                contentItem: Item {
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: VLCStyle.dp(14, VLCStyle.scale)

                        spacing: VLCStyle.spacing_8

                        Widgets.SvgIcon {
                            name: tab.current ? (modelData.icon + "-twotone") : modelData.icon
                            size: VLCStyle.dp(20, VLCStyle.scale)
                            color: (tab.current || tab.hovered) ? theme.fg.primary : theme.fg.secondary
                            accentColor: theme.accent
                        }

                        Widgets.LabelExt {
                            anchors.verticalCenter: parent.verticalCenter

                            text: modelData.text
                            font.pixelSize: VLCStyle.text_caption
                            color: (tab.current || tab.hovered) ? theme.fg.primary : theme.fg.secondary

                            Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
                        }
                    }
                }

                background: Item {
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: VLCStyle.spacing_4
                        anchors.topMargin: VLCStyle.spacing_2
                        radius: VLCStyle.radius_s
                        color: tabTheme.bg.primary
                        opacity: (tab.hovered || tab.visualFocus) && !tab.current ? 0.7 : 0

                        border.width: tab.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                        border.color: theme.visualFocus

                        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: VLCStyle.spacing_8
                        anchors.rightMargin: VLCStyle.spacing_8

                        height: VLCStyle.dp(2, VLCStyle.scale)

                        color: tab.current ? theme.accent : "transparent"

                        Behavior on color { ColorAnimation { duration: VLCStyle.duration_long } }
                    }
                }
            }
        }
    }
}
