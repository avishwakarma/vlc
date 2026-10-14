
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

import VLC.Style
import VLC.Widgets as Widgets

// Settings panel row: label (14, secondary) on the left, the control on the
// right. The control is the default content, it is sized with `controlWidth`.
Item {
    id: root

    property string label: ""
    property real controlWidth: VLCStyle.dp(140, VLCStyle.scale)
    property real rowHeight: VLCStyle.dp(53, VLCStyle.scale)

    // hint for disabled rows
    property string unavailableText: ""

    default property alias control: holder.data

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Layout.fillWidth: true
    implicitHeight: rowHeight

    Widgets.LabelExt {
        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.spacing_24
        anchors.right: holder.left
        anchors.rightMargin: VLCStyle.spacing_10
        anchors.verticalCenter: parent.verticalCenter

        text: root.label
        font.pixelSize: VLCStyle.text_body
        color: theme.fg.secondary
        elide: Text.ElideRight
    }

    Item {
        id: holder

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.spacing_20
        anchors.verticalCenter: parent.verticalCenter

        width: root.controlWidth
        height: childrenRect.height
    }

    Widgets.ToolTipExt {
        visible: root.unavailableText !== "" && hover.hovered
        text: root.unavailableText
    }

    HoverHandler {
        id: hover
        enabled: root.unavailableText !== ""
    }
}
