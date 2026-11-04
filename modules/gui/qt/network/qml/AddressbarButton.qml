
/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Network
import VLC.Util

T.Button {
    id: button

    // Properties

    property color foregroundColor: theme.fg.primary
    property color backgroundColor: theme.bg.primary

    // SVG icon (from /svgicons) shown when display is IconOnly
    property string iconName: ""

    // Settings

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    baselineOffset: contentItem ? contentItem.y + contentItem.baselineOffset : 0


    padding: VLCStyle.margin_xxsmall

    font.pixelSize: (display === T.Button.IconOnly) ? VLCStyle.icon_normal
                                                    : VLCStyle.text_body

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.ButtonStandard

        enabled: button.enabled
        focused: button.visualFocus
        hovered: button.hovered || button.highlighted
        pressed: button.down
    }


    background: Widgets.AnimatedBackground {
        enabled: theme.initialized
        color: button.backgroundColor
        border.color: visualFocus ? theme.visualFocus : Qt.alpha(theme.visualFocus, 0.0)
    }

    contentItem: contentLoader.item

    Loader {
        id: contentLoader

        sourceComponent: (button.display === T.Button.IconOnly) ? iconTextContent
                                                                : textContent
    }

    Component {
        id: iconTextContent

        Widgets.SvgIcon {
            name: button.iconName
            size: VLCStyle.icon_normal

            color: button.foregroundColor

            DelayedBehavior on color {
                delayedEnabled: theme.initialized

                ColorAnimation {
                    duration: VLCStyle.duration_long
                }
            }
        }
    }

    Component {
        id: textContent

        Widgets.SubtitleLabel {
            verticalAlignment: Text.AlignVCenter

            text: button.text

            color: button.foregroundColor

            font.weight: (highlighted) ? VLCStyle.fontWeight_semibold : VLCStyle.fontWeight_regular
        }
    }
}
