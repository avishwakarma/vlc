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

import VLC.Style

// Field heading of the form dialogs: 16 px label (FG/2) over a 14 px helper line (FG/A3),
// both with the 1.75 line height of the Figma text styles.
//   DialogHeading { label: qsTr("Network URL"); helper: qsTr("You can enter multiple links.") }
Column {
    id: root

    property string label
    // greyed text appended to the label, e.g. "(optional)"
    property string labelSuffix
    property string helper

    spacing: VLCStyle.dp(5, VLCStyle.scale)

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    component Line : Text {
        width: root.width

        // CSS centres the glyphs in the 1.75 line box, Qt puts them at the top
        lineHeightMode: Text.FixedHeight
        lineHeight: font.pixelSize * 1.75
        transform: Translate { y: font.pixelSize * 0.27 }
        font.weight: VLCStyle.fontWeight_regular
        textFormat: Text.StyledText
        wrapMode: Text.WordWrap
    }

    Line {
        visible: root.label !== ""
        font.pixelSize: VLCStyle.text_heading
        color: theme.fg.heading
        text: root.label.replace(/&/g, "&amp;").replace(/</g, "&lt;")
              + (root.labelSuffix !== "" ? " <font color=\"" + theme.fg.secondary + "\">"
                                           + root.labelSuffix.replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>" : "")
    }

    Line {
        visible: root.helper !== ""
        font.pixelSize: VLCStyle.text_body
        color: theme.fg.secondary
        text: root.helper.replace(/&/g, "&amp;").replace(/</g, "&lt;")
    }
}
