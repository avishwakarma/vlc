
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

import VLC.Style
import VLC.Player

// Dropdown over a VLCVarChoiceModel of the player (zoom, aspect ratio, crop,
// stereo mode, audio visualization): the {display, checked} rows are mirrored
// into a plain list so that the options can carry an icon.
EffectsDropdown {
    id: control

    property var choiceModel: null
    // function(text) -> SvgIcon name
    property var iconFor: null

    property var items: []

    visible: items.length > 0

    function rebuild() {
        const m = choiceModel
        const list = []
        if (m) {
            for (let i = 0; i < m.rowCount(); ++i) {
                const idx = m.index(i, 0)
                const name = m.data(idx, Qt.DisplayRole)
                list.push({ text: name, iconName: iconFor ? iconFor(name) : "", checked: m.data(idx, Qt.CheckStateRole) === Qt.Checked })
            }
        }
        items = list
    }

    onChoiceModelChanged: rebuild()
    Component.onCompleted: rebuild()

    Connections {
        target: control.choiceModel
        function onDataChanged() { control.rebuild() }
        function onModelReset() { control.rebuild() }
        function onRowsInserted() { control.rebuild() }
        function onRowsRemoved() { control.rebuild() }
    }

    iconRole: "iconName"
    textRole: "text"
    model: items

    currentIndex: {
        for (let i = 0; i < items.length; ++i)
            if (items[i].checked)
                return i
        return items.length > 0 ? 0 : -1
    }
    displayText: currentIndex >= 0 ? items[currentIndex].text : ""

    onActivated: (i) => choiceModel.toggleIndex(i)
}
