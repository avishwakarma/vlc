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

// A titled group of SettingRows. Hides itself while none of its rows is shown
// (unavailable options, search filter).
//
//   SettingSection {
//       title: qsTr("Window")
//       SettingRow { ... }
//   }
ColumnLayout {
    id: section

    readonly property bool isSettingSection: true

    property string title

    // rows (or any item) go here
    default property alias content: rows.data

    property bool hasRows: false

    function update() {
        let any = false
        for (let i = 0; i < rows.children.length; ++i) {
            const c = rows.children[i]
            if (c.isSettingRow ? c.shown : c.visible) {
                any = true
                break
            }
        }
        hasRows = any
    }

    readonly property Item _page: {
        let p = section.parent
        while (p && !p.isSettingsPage)
            p = p.parent
        return p
    }

    onHasRowsChanged: if (_page) _page.sectionsChanged()

    Component.onCompleted: update()

    // stubs of pages that are still to be written list their sections anyway
    property bool showWhenEmpty: false

    visible: hasRows || showWhenEmpty
    Layout.fillWidth: true
    spacing: 0

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    Text {
        visible: section.title !== ""

        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.spacing_10
        Layout.bottomMargin: VLCStyle.spacing_10

        text: section.title
        color: theme.fg.heading
        font.pixelSize: VLCStyle.text_heading
        font.weight: VLCStyle.fontWeight_medium
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }

    ColumnLayout {
        id: rows

        Layout.fillWidth: true
        spacing: 0
    }
}
