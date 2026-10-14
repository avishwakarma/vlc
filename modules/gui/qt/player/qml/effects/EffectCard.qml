
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

// Collapsible "Expand Settings" / "Collapse Settings" block of the effect
// panels (Figma 536:1513): a B2 bar when collapsed, a card with the controls
// when expanded.
FocusScope {
    id: root

    default property alias content: contentColumn.data

    property bool expanded: false
    property real rowSpacing: VLCStyle.dp(21, VLCStyle.scale)
    // gap between the header and the first row
    property real topGap: VLCStyle.dp(26, VLCStyle.scale)

    property string expandText: qsTr("Expand Settings")
    property string collapseText: qsTr("Collapse Settings")

    implicitWidth: VLCStyle.popoverPanel_w - 2 * VLCStyle.popoverPanel_margin
    implicitHeight: expanded ? cardHeight : VLCStyle.effectHeader_h

    readonly property real cardHeight: VLCStyle.effectCard_padding + header.implicitHeight + topGap
                                       + contentWrapper.height + VLCStyle.dp(21, VLCStyle.scale)

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight

    clip: true

    // animate only the user's expand / collapse, not the layout of the content
    property bool _animate: false

    Behavior on implicitHeight {
        enabled: root._animate

        NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property ColorContext _item: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
        hovered: headerArea.containsMouse
    }

    // collapsed bar (B2) fades into the card (A3)
    Rectangle {
        anchors.fill: parent

        radius: VLCStyle.radius_m
        color: root.expanded ? theme.bg.primary : theme.bg.secondary

        Behavior on color {
            ColorAnimation { duration: VLCStyle.duration_long }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.radius_m
        color: itemTheme.bg.primary
        opacity: (headerArea.containsMouse && !root.expanded) ? 0.6 : 0

        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
    }

    Item {
        id: header

        x: VLCStyle.effectCard_padding
        y: root.expanded ? VLCStyle.effectCard_padding : (VLCStyle.effectHeader_h - implicitHeight) / 2
        width: parent.width - 2 * VLCStyle.effectCard_padding
        implicitHeight: headerLabel.implicitHeight

        Behavior on y { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine } }

        Widgets.LabelExt {
            id: headerLabel

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: root.expanded ? root.collapseText : root.expandText
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
        }

        Widgets.SvgIcon {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            name: "chevron-right"
            size: VLCStyle.icon_normal
            color: theme.fg.secondary
            rotation: root.expanded ? 90 : 0

            Behavior on rotation { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine } }
        }
    }

    MouseArea {
        id: headerArea

        x: 0
        y: 0
        width: parent.width
        height: root.expanded ? VLCStyle.effectCard_padding + header.implicitHeight + VLCStyle.spacing_8 : VLCStyle.effectHeader_h

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

    Item {
        id: contentWrapper

        x: VLCStyle.effectCard_padding
        y: VLCStyle.effectCard_padding + header.implicitHeight + root.topGap
        width: parent.width - 2 * VLCStyle.effectCard_padding
        height: contentColumn.implicitHeight

        opacity: root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_long } }

        ColumnLayout {
            id: contentColumn

            width: parent.width
            spacing: root.rowSpacing
        }
    }

    function toggle() {
        _animate = true
        expanded = !expanded
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.toggle()
            event.accepted = true
        }
    }
}
