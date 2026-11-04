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

// Footer of ModalDialog: DialogButtons right aligned, 20 px padding like the DialogShell footer.
//   footer: ModalFooter { DialogButton { text: qsTr("Cancel") } DialogButton { kind: ...Primary } }
FocusScope {
    id: root

    default property alias buttons: row.data

    // palette for the buttons (a Popup is outside the ColorContext chain of the window)
    readonly property ColorContext colorContext: ColorContext {
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    implicitHeight: VLCStyle.spacing_20 * 2 + VLCStyle.toggle_h

    // Enter activates the focused button (T.Button only reacts to Space)
    Keys.onReturnPressed: (event) => activateFocused(event)
    Keys.onEnterPressed: (event) => activateFocused(event)

    function activateFocused(event) {
        for (let i = 0; i < row.children.length; ++i) {
            const b = row.children[i]
            if (b.visible && b.activeFocus) {
                b.clicked()
                event.accepted = true
                return
            }
        }
    }

    Row {
        id: row

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.spacing_20
        y: VLCStyle.spacing_20
        spacing: VLCStyle.spacing_8
    }
}
