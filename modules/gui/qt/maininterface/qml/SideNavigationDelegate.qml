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
import QtQuick.Layouts


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

T.ItemDelegate {
    id: control

    // Properties

    property string iconTxt: ""

    // Figma icon (pixmaps/svg_icons name); when set it replaces the icon font glyph.
    // `iconNameSelected` is the filled variant used for the current page.
    property string iconName: ""
    property string iconNameSelected: iconName

    property bool showText: true

    property real radius: VLCStyle.button_radius

    // Settings

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: VLCStyle.margin_xxsmall

    leftInset: implicitLeftInset
    rightInset: implicitRightInset

    topInset: implicitTopInset
    bottomInset: implicitBottomInset

    property real implicitLeftInset: VLCStyle.margin_xxsmall
    property real implicitRightInset: VLCStyle.margin_xxsmall

    property real implicitTopInset: VLCStyle.margin_xxxsmall
    property real implicitBottomInset: VLCStyle.margin_xxxsmall

    // Figma navigation card row: 24px icon, 16px label, 10px gap, no accent
    readonly property bool figmaStyle: iconName !== ""

    // Accessible

    Accessible.onPressAction: control.clicked()
    AccessibleCompat.id: {
        if (model.depth !== 0 || !model.uri || model.uri.length === 0) return "";
        const navBarIds = {
            "home": "homeNavBar",
            "video": "videoNavBar",
            "music": "musicNavBar",
            "network": "browseNavBar",
            "discover": "discoverNavBar"
        }
        const id = navBarIds[model.uri[0]]
        if (id !== undefined)
            return id
        else
            return ""
    }

    // Tooltip

    T.ToolTip.visible: (showText === false && T.ToolTip.text && (hovered || visualFocus))

    T.ToolTip.delay: VLCStyle.delayToolTipAppear

    T.ToolTip.text: text

    // Childs

    ColorContext {
        id: theme
        colorSet: ColorContext.TabButton

        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
        enabled: control.enabled
    }

    background: Widgets.AnimatedBackground {
        enabled: theme.initialized
        color: theme.bg.primary
        border.color: visualFocus ? theme.visualFocus : "transparent"

        radius: control.radius

        Widgets.CurrentIndicator {
            visible: control.checked && !control.figmaStyle
            anchors {
                left: parent.left
                leftMargin: VLCStyle.margin_xxxsmall
                verticalCenter: parent.verticalCenter
            }
            implicitHeight: parent.height / 2

            radius: control.radius / 2
        }
    }

    contentItem: RowLayout {
        spacing: control.figmaStyle ? VLCStyle.spacing_10 : VLCStyle.margin_xsmall

        Item {
            Layout.preferredWidth: control.figmaStyle ? VLCStyle.icon_normal : VLCStyle.icon_banner
            Layout.fillHeight: true

            Widgets.SvgIcon {
                visible: control.figmaStyle

                anchors.centerIn: parent

                name: control.checked ? control.iconNameSelected : control.iconName
                size: VLCStyle.icon_normal
                color: theme.fg.primary
            }

            Widgets.IconLabel {
                id: iconLabel

                visible: !control.figmaStyle && text.length > 0

                anchors.centerIn: parent

                text: control.iconTxt

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                color: (control.highlighted || control.checked) ? theme.accentText : theme.fg.primary

                font.pixelSize: VLCStyle.icon_banner
            }
        }

        T.Label {
            id: label

            Layout.fillWidth: true
            Layout.fillHeight: true

            text: control.text

            verticalAlignment: Text.AlignVCenter

            color: (control.checked && !control.figmaStyle) ? theme.fg.secondary : theme.fg.primary

            elide: Text.ElideRight

            visible: control.showText

            font.pixelSize: control.figmaStyle ? VLCStyle.text_heading : VLCStyle.text_body

            font.weight: (control.checked && !control.figmaStyle) ? VLCStyle.fontWeight_semibold : Font.Normal

            //button text is already exposed
            Accessible.ignored: true

            Behavior on color {
                enabled: theme.initialized

                ColorAnimation {
                    duration: VLCStyle.duration_short
                }
            }
        }
    }
}
