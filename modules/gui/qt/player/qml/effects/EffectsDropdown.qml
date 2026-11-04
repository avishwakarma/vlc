
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
import QtQuick.Controls.Basic
import QtQuick.Templates as T

import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// Figma "Dropdown" for the panels: the canonical Dropdown with an optional icon per
// option (equalizer presets, audio visualizer) and a list that can open
// upwards (the preset selector pinned at the bottom of the settings panel).
Widgets.Dropdown {
    id: control

    // name of the role holding an SvgIcon name for each option
    property string iconRole: ""
    // role holding a text prefix style: "dots" draws the "..." marker of custom presets
    property bool openUp: false
    // role of options shown dimmed (e.g. "New Preset")
    property string dimRole: ""

    implicitWidth: VLCStyle.popoverPanel_w - 2 * VLCStyle.popoverPanel_margin

    delegate: T.ItemDelegate {
        id: optionDelegate

        required property var model
        required property int index

        width: ListView.view ? ListView.view.width : control.width
        height: control.optionHeight

        leftPadding: VLCStyle.spacing_14
        rightPadding: VLCStyle.spacing_14
        topPadding: VLCStyle.spacing_2
        bottomPadding: VLCStyle.spacing_2
        spacing: VLCStyle.spacing_10

        highlighted: control.highlightedIndex === index

        readonly property bool selected: control.currentIndex === index
        readonly property var entry: Helpers.isArray(control.model) ? control.model[index] : model
        readonly property string iconName: (control.iconRole !== "" && entry) ? (entry[control.iconRole] ?? "") : ""
        readonly property bool dim: (control.dimRole !== "" && entry) ? !!entry[control.dimRole] : false

        readonly property ColorContext colorContext: ColorContext {
            id: optionTheme
            colorSet: ColorContext.Item

            palette: control.colorContext.palette

            hovered: optionDelegate.hovered
            pressed: optionDelegate.down
            focused: optionDelegate.highlighted
        }

        contentItem: Item {
            implicitHeight: optionLabel.implicitHeight

            Widgets.SvgIcon {
                id: optionIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                visible: optionDelegate.iconName !== ""
                name: optionDelegate.iconName
                size: VLCStyle.icon_normal
                color: optionTheme.fg.primary
                accentColor: optionTheme.accent
            }

            Widgets.ListLabel {
                id: optionLabel

                anchors.left: optionIcon.visible ? optionIcon.right : parent.left
                anchors.leftMargin: optionIcon.visible ? VLCStyle.spacing_10 : 0
                anchors.right: check.left
                anchors.rightMargin: VLCStyle.spacing_10
                anchors.verticalCenter: parent.verticalCenter

                font.weight: VLCStyle.fontWeight_regular
                text: control.textRole ? (optionDelegate.entry ? optionDelegate.entry[control.textRole] : "") : modelData
                color: optionDelegate.dim ? optionTheme.fg.secondary
                                          : (optionDelegate.hovered ? optionTheme.fg.highlight : control.color)
                font.pixelSize: control.font.pixelSize
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Widgets.SvgIcon {
                id: check

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                name: "check-active"
                size: VLCStyle.icon_normal
                color: optionTheme.fg.primary
                accentColor: optionTheme.accent
                visible: optionDelegate.selected
            }
        }

        background: Rectangle {
            radius: VLCStyle.radius_s
            color: optionDelegate.down ? optionTheme.bg.primary
                 : (optionDelegate.highlighted || optionDelegate.hovered || optionDelegate.selected) ? control._hoverTheme.bg.primary
                 : "transparent"
        }
    }

    popup: Popup {
        y: control.openUp ? -height - VLCStyle.spacing_4 : control.height + VLCStyle.spacing_4

        z: 100

        width: control.width
        padding: VLCStyle.spacing_2

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: VLCStyle.duration_short }
                NumberAnimation { property: "scale"; from: 0.97; to: 1.0; duration: VLCStyle.duration_short }
            }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: VLCStyle.duration_veryShort }
        }

        contentItem: ListView {
            clip: true
            implicitHeight: Math.min(contentHeight, control.optionHeight * 8)
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            spacing: VLCStyle.spacing_2

            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: control.bgColor
            radius: VLCStyle.radius_m

            Widgets.RoundedRectangleShadow {
                blurRadius: VLCStyle.shadow_popup.blur
                yOffset: VLCStyle.shadow_popup.y
                color: VLCStyle.shadowColor(VLCStyle.shadow_popup.alpha)
            }
        }
    }
}
