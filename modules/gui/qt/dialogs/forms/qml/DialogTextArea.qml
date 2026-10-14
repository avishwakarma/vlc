/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Controls.Basic as C

import VLC.Style

// Multi-line input of the form dialogs (Figma: B2 well, 2 px A4 border, r6, padding 8/18/8/12).
Rectangle {
    id: root

    property alias text: area.text
    property alias placeholderText: area.placeholderText
    property alias textArea: area

    implicitHeight: VLCStyle.dp(194, VLCStyle.scale)

    radius: VLCStyle.radius_m
    color: fieldTheme.bg.secondary
    border.width: VLCStyle.dp(2, VLCStyle.scale)
    border.color: fieldTheme.border

    ColorContext {
        id: fieldTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.TextField
        focused: area.activeFocus
        hovered: hover.hovered
    }

    ColorContext {
        id: placeholderTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
        enabled: false
    }

    Behavior on border.color { ColorAnimation { duration: VLCStyle.duration_short } }

    HoverHandler { id: hover }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: root.border.width
        clip: true
        contentWidth: width
        contentHeight: area.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        function ensureVisible(r) {
            if (contentY >= r.y)
                contentY = r.y
            else if (contentY + height <= r.y + r.height)
                contentY = r.y + r.height - height
        }

        C.TextArea.flickable: C.TextArea {
            id: area

            leftPadding: VLCStyle.spacing_12 - root.border.width
            rightPadding: VLCStyle.spacing_16 - root.border.width
            topPadding: VLCStyle.spacing_8 - root.border.width
            bottomPadding: VLCStyle.spacing_8 - root.border.width

            background: null
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            persistentSelection: true

            color: fieldTheme.fg.primary
            selectedTextColor: fieldTheme.fg.highlight
            selectionColor: fieldTheme.bg.highlight
            placeholderTextColor: placeholderTheme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular

            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)

            Accessible.role: Accessible.EditableText
        }
    }
}
