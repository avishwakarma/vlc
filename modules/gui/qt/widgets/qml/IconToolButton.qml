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
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

T.ToolButton {
    id: control

    // Properties

    property bool paintOnly: false

    required property string description

    // Opt-in SVG icon (name of a file in pixmaps/svg_icons, e.g. "home").
    // When empty the font glyph `text` is used. For toggle buttons use the
    // plain name for the unchecked state and `iconNameChecked` (e.g.
    // "home-active") for the checked one; if the latter is empty the same
    // icon is used and recoloured with the accent color.
    property string iconName: ""
    property string iconNameChecked: ""
    property real iconSize: VLCStyle.icon_normal

    readonly property bool _svg: (iconName !== "")

    property color color: (control.checked) ? theme.accent : theme.fg.primary

    property color backgroundColor: (_svg && (control.hovered || control.down)) ? hoverTheme.bg.primary
                                                                                : theme.bg.primary

    property real radius: VLCStyle.button_radius

    // Settings

    padding: 0

    enabled: !paintOnly

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    baselineOffset: contentItem.y + contentItem.baselineOffset

    font.pixelSize: VLCStyle.icon_toolbar
    font.family: VLCIcons.fontFamily

    // Keys

    Keys.priority: Keys.AfterItem

    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // Accessible

    Accessible.onPressAction: control.clicked()

    Accessible.name: description

    // Tooltip

    T.ToolTip.visible: (hovered || visualFocus)

    T.ToolTip.delay: VLCStyle.delayToolTipAppear

    T.ToolTip.text: description

    // Events

    Component.onCompleted: console.assert(text !== "", "text is empty")

    // Children

    readonly property ColorContext colorContext : ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton

        enabled: control.paintOnly || control.enabled
        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
    }

    background: Widgets.AnimatedBackground {
        implicitWidth: control.font.pixelSize
        implicitHeight: control.font.pixelSize

        enabled: theme.initialized

        color: control.backgroundColor

        border.color: visualFocus ? theme.visualFocus : theme.border

        radius: control.radius
    }

    readonly property ColorContext hoverColorContext: ColorContext {
        id: hoverTheme
        colorSet: ColorContext.Item

        hovered: control.hovered
        pressed: control.down
    }

    contentItem: control._svg ? svgHolder : glyphLabel

    Widgets.IconLabel {
        id: glyphLabel

        visible: !control._svg

        text: control.text

        color: control.color

        DelayedBehavior on color {
            delayedEnabled: theme.initialized

            ColorAnimation {
                duration: VLCStyle.duration_long
            }
        }

        font: control.font
    }

    // the icon keeps its own (logical) size and is centered in the button
    Item {
        id: svgHolder

        visible: control._svg

        implicitWidth: svgIcon.implicitWidth
        implicitHeight: svgIcon.implicitHeight

        Widgets.SvgIcon {
            id: svgIcon

            anchors.centerIn: parent

            width: size
            height: size

            name: (control.checked && control.iconNameChecked !== "") ? control.iconNameChecked : control.iconName
            size: control.iconSize

            // hover/pressed/focus/disabled variants come from the ToolButton color set
            color: (control.checked && control.iconNameChecked !== "") ? theme.fg.primary : control.color
            accentColor: theme.accent
        }
    }
}
