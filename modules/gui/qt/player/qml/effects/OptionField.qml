
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
import VLC.Dialogs
import VLC.Widgets as Widgets

// Text field bound to a ConfigOption (written when the edit is finished).
Widgets.TextFieldExt {
    id: control

    property ConfigOption option: null
    property bool numeric: false

    implicitWidth: VLCStyle.dp(140, VLCStyle.scale)
    implicitHeight: VLCStyle.input_h

    selectByMouse: true
    inputMethodHints: numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
    validator: numeric ? intValidator : null

    IntValidator { id: intValidator }

    text: (option && option.value !== undefined) ? String(option.value) : ""

    onEditingFinished: {
        if (!option)
            return
        if (numeric) {
            const v = parseInt(text)
            if (!isNaN(v))
                option.value = v
        } else if (text !== String(option.value ?? "")) {
            option.value = text
        }
        text = Qt.binding(() => (control.option && control.option.value !== undefined) ? String(control.option.value) : "")
    }
}
