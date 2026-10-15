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

import VLC.MainInterface
import VLC.Style
import VLC.Util

// Title of the playing media, centred in the title bar
Item {
    id: root

    // used by the control rows when they look for the next item to focus
    property int focusReason: Qt.OtherFocusReason

    property bool paintOnly: false

    // takes the width of the zone (the text is centred and elided)
    readonly property bool fillWidth: true

    readonly property bool keepSize: true

    implicitWidth: Math.min(label.implicitWidth, VLCStyle.dp(600, VLCStyle.scale))
    implicitHeight: VLCStyle.windowButton_h

    Layout.minimumWidth: VLCStyle.dp(40, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton
    }

    Text {
        id: label

        anchors.fill: parent

        text: (PlayerHost.title !== "" || !root.paintOnly) ? PlayerHost.title : qsTr("Title")
        color: theme.fg.primary

        // briefly highlight the name when a media starts: accent fading to the normal color
        onTextChanged: {
            if (root.paintOnly || PlayerHost.title === "")
                return
            highlight.restart()
        }

        SequentialAnimation {
            id: highlight

            ColorAnimation {
                target: label
                property: "color"
                from: theme.accent
                to: theme.fg.primary
                duration: 1800
                easing.type: Easing.OutCubic
            }
        }

        font.pixelSize: VLCStyle.text_body
        font.weight: VLCStyle.fontWeight_regular
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Accessible.role: Accessible.Heading
        Accessible.name: text
    }
}
