/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Figma "Dropdown": a well (bg.secondary) holding an inset trigger (bg.primary),
// and a floating option list. See also `Dropdown.qml` (non-compact default).
T.ComboBox {
    id: control

    // 32 px inset trigger (settings rows) when true, 44 px when false
    property bool compact: true

    readonly property real optionHeight: compact ? VLCStyle.dropdownCompact_h : VLCStyle.dropdown_h

    // well padding
    readonly property real wellPadding: VLCStyle.spacing_2

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + spacing + implicitIndicatorWidth + leftPadding + rightPadding)
    implicitHeight: optionHeight + 2 * wellPadding

    topPadding: wellPadding
    bottomPadding: wellPadding
    leftPadding: wellPadding + VLCStyle.spacing_14
    rightPadding: wellPadding + VLCStyle.spacing_14

    spacing: VLCStyle.spacing_10

    font.pixelSize: VLCStyle.text_body

    opacity: enabled ? 1.0 : 0.3

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ComboBox

        focused: control.activeFocus
        enabled: control.enabled
        hovered: control.hovered
        pressed: control.pressed
    }

    // always-hovered item colors (hovered/selected option, hovered trigger)
    readonly property ColorContext _hoverTheme: ColorContext {
        id: itemHover
        colorSet: ColorContext.Item
        hovered: true
    }

    readonly property ColorContext _itemTheme: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item

        hovered: control.hovered
        pressed: control.pressed
    }

    property color color: theme.fg.primary
    property color bgColor: theme.bg.primary          // inset trigger / option list
    property color wellColor: theme.bg.secondary
    property color borderColor: theme.border

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    delegate: T.ItemDelegate {
        id: optionDelegate

        width: ListView.view ? ListView.view.width : control.width
        height: control.optionHeight

        leftPadding: VLCStyle.spacing_14
        rightPadding: VLCStyle.spacing_14
        topPadding: VLCStyle.spacing_2
        bottomPadding: VLCStyle.spacing_2
        spacing: VLCStyle.spacing_10

        highlighted: control.highlightedIndex === index

        readonly property bool selected: control.currentIndex === index

        readonly property ColorContext colorContext: ColorContext {
            id: optionTheme
            colorSet: ColorContext.Item

            // the popup lives in the overlay, outside the control's item tree
            palette: theme.palette

            hovered: optionDelegate.hovered
            pressed: optionDelegate.down
            focused: optionDelegate.highlighted
        }

        contentItem: Item {
            implicitHeight: optionLabel.implicitHeight

            Widgets.ListLabel {
                id: optionLabel

                font.weight: VLCStyle.fontWeight_regular

                anchors.left: parent.left
                anchors.right: check.left
                anchors.rightMargin: VLCStyle.spacing_10
                anchors.verticalCenter: parent.verticalCenter

                text: control.textRole ? (Helpers.isArray(control.model) ? modelData[control.textRole] : model[control.textRole]) : modelData
                color: optionDelegate.hovered ? optionTheme.fg.highlight : control.color
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
                 : (optionDelegate.highlighted || optionDelegate.hovered || optionDelegate.selected) ? itemHover.bg.primary
                 : "transparent"
        }
    }

    indicator: Widgets.SvgIcon {
        x: control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2

        name: control.popup.visible ? "chevron-up" : "chevron-down"
        size: VLCStyle.icon_normal
        color: control.color
    }

    contentItem: Widgets.ListLabel {
        font.weight: VLCStyle.fontWeight_regular

        rightPadding: control.spacing + control.indicator.width

        text: control.displayText
        color: control.color
        font.pixelSize: control.font.pixelSize
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: VLCStyle.radius_m
        color: control.wellColor

        border.width: VLCStyle.border
        border.color: control.visualFocus ? theme.visualFocus : theme.border

        Rectangle {
            anchors.fill: parent
            anchors.margins: control.wellPadding

            radius: VLCStyle.radius_s

            color: (control.hovered || control.pressed || control.popup.visible) ? itemHover.bg.primary
                                                                                 : control.bgColor

            border.width: control.activeFocus ? VLCStyle.border : 0
            border.color: theme.border

            Behavior on color {
                ColorAnimation { duration: VLCStyle.duration_short }
            }
        }
    }

    popup: Popup {
        y: control.height + VLCStyle.spacing_4

        // NOTE: This Popup should be on top of other Popup(s) most of the time.
        z: 100

        width: control.width
        padding: VLCStyle.spacing_2

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: VLCStyle.duration_short }
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
