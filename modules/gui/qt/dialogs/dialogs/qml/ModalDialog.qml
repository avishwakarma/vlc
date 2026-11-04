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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

// In-window modal card used by the login / question / progress / custom dialogs.
// Same look as the form dialogs (DialogShell): rounded card (radius_xl), B2 title band,
// content area with 20 px padding and a footer of DialogButtons (see ModalFooter).
Dialog {
    id: control

    property Item rootWindow: null

    focus: true
    modal: true

    anchors.centerIn: T.Overlay.overlay

    padding: VLCStyle.spacing_20
    topPadding: VLCStyle.spacing_20
    bottomPadding: VLCStyle.spacing_20
    margins: VLCStyle.margin_large

    readonly property real minCardWidth: VLCStyle.dp(420, VLCStyle.scale)
    readonly property real maxCardWidth: VLCStyle.dp(560, VLCStyle.scale)

    implicitWidth: Math.min(maxCardWidth, Math.max(minCardWidth, contentWidth + leftPadding + rightPadding))
    implicitHeight: (header && header.visible ? header.implicitHeight : 0)
                    + (footer && footer.visible ? footer.implicitHeight : 0)
                    + (contentHeight > 0 ? contentHeight + topPadding + bottomPadding : 0)

    closePolicy: Popup.CloseOnEscape

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    T.Overlay.modal: Item {
        Widgets.DualKawaseBlur {
            id: blur

            anchors.fill: parent
            anchors.margins: MainCtx.windowExtendedMargin

            visible: MainCtx.backdropBlurRequested() && blur.available

            mode: Widgets.DualKawaseBlur.Mode.SixPass

            source: ShaderEffectSource {
                sourceItem: blur.visible ? control.rootWindow : null
                live: true
                hideSource: true
            }

            radius: 2
        }

        // dimming scrim above the (optional) blur so bright content never glows around the card
        Rectangle {
            anchors.fill: parent
            anchors.margins: MainCtx.windowExtendedMargin

            color: theme.bg.primary

            opacity: blur.visible ? 0.75 : 0.6
        }
    }

    background: Rectangle {
        radius: VLCStyle.radius_xl
        color: theme.bg.primary

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.shadow_floating.blur
            yOffset: VLCStyle.shadow_floating.y
            color: Qt.rgba(0, 0, 0, VLCStyle.shadow_floating.alpha)
            z: -1
        }
    }

    header: Item {
        visible: control.title !== ""
        implicitHeight: visible ? titleRow.height + 2 * VLCStyle.dp(9, VLCStyle.scale) : 0

        // B2 band with rounded top corners
        Rectangle {
            width: parent.width
            height: VLCStyle.radius_xl * 2
            radius: VLCStyle.radius_xl
            color: theme.bg.secondary
        }
        Rectangle {
            y: VLCStyle.radius_xl
            width: parent.width
            height: parent.height - VLCStyle.radius_xl
            color: theme.bg.secondary
        }

        Item {
            id: titleRow

            x: VLCStyle.dp(9, VLCStyle.scale)
            y: VLCStyle.dp(9, VLCStyle.scale)
            width: parent.width - 2 * x
            height: VLCStyle.toggle_h

            Text {
                x: VLCStyle.spacing_10
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                text: control.title
                color: theme.fg.primary
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.text_body
                font.weight: VLCStyle.fontWeight_regular
                textFormat: Text.PlainText

                Accessible.role: Accessible.Heading
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: VLCStyle.duration_short; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.98; duration: VLCStyle.duration_short; easing.type: Easing.InCubic }
        }
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.98; to: 1.0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
        }
    }
}
