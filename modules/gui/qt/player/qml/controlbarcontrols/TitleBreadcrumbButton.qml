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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// Breadcrumb link of the title bar: folder icon + label, goes back to the library
T.Button {
    id: root

    property bool paintOnly: false

    signal requestLockUnlockAutoHide(bool lock)

    readonly property bool keepSize: true

    readonly property string breadcrumb: (PlayerHost.breadcrumb !== "" || !paintOnly) ? PlayerHost.breadcrumb : qsTr("Folder")

    readonly property ColorContext toolColorContext: ColorContext {
        id: toolTheme
        colorSet: ColorContext.ToolButton
    }

    readonly property ColorContext itemColorContext: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
        hovered: root.hovered
        pressed: root.down
    }

    implicitHeight: VLCStyle.windowButton_h
    implicitWidth: VLCStyle.windowButton_h + VLCStyle.spacing_4 + Math.min(crumbLabel.implicitWidth, VLCStyle.dp(220, VLCStyle.scale)) + rightPadding

    padding: 0
    rightPadding: VLCStyle.spacing_4
    hoverEnabled: true
    enabled: !paintOnly

    Accessible.name: qsTr("Back to %1").arg(root.breadcrumb)
    AccessibleCompat.id: "topBarBreadcrumb"

    T.ToolTip.visible: (hovered || visualFocus)
    T.ToolTip.delay: VLCStyle.delayToolTipAppear
    T.ToolTip.text: qsTr("Back to %1").arg(root.breadcrumb)

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event)) {
            event.accepted = true
            root.clicked()
        } else {
            Navigation.defaultKeyAction(event)
        }
    }

    onClicked: PlayerHost.breadcrumbClicked()

    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

    background: Widgets.AnimatedBackground {
        radius: VLCStyle.radius_m
        enabled: toolTheme.initialized

        color: (root.hovered || root.down) ? itemTheme.bg.primary : "transparent"

        border.color: root.visualFocus ? toolTheme.visualFocus : "transparent"
    }

    contentItem: Row {
        spacing: VLCStyle.spacing_4

        // folder icon cell: 28x28, 24px glyph
        Item {
            width: VLCStyle.windowButton_h
            height: VLCStyle.windowButton_h

            Widgets.SvgIcon {
                anchors.centerIn: parent
                name: "folder"
                size: VLCStyle.icon_normal
                color: toolTheme.fg.primary
            }
        }

        Text {
            id: crumbLabel

            height: VLCStyle.windowButton_h
            width: Math.min(implicitWidth, VLCStyle.dp(220, VLCStyle.scale))

            text: root.breadcrumb
            color: toolTheme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
