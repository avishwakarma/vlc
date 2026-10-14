
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

import VLC.Style
import VLC.Widgets as Widgets

// Small B2 input with an optional unit suffix ("12.0 dB", "0 px"). The text is
// plain while editing and the unit is added back when the edit is committed.
Widgets.TextFieldExt {
    id: control

    // current value as a number and how to show it
    property real value: 0
    property int decimals: 1
    property string unit: ""
    property real from: -Infinity
    property real to: Infinity
    property real multiplier: 1

    // the unit is drawn in the secondary colour (Figma 543:990)
    property bool dimUnit: false

    signal committed(real value)

    property bool trimZeros: false

    readonly property string _plain: trimZeros ? String(Number((value * multiplier).toFixed(decimals))) : (value * multiplier).toFixed(decimals)

    implicitWidth: VLCStyle.dp(138, VLCStyle.scale)
    implicitHeight: VLCStyle.input_h

    font.pixelSize: VLCStyle.text_caption
    selectByMouse: true
    inputMethodHints: Qt.ImhFormattedNumbersOnly
    validator: DoubleValidator { notation: DoubleValidator.StandardNotation }

    text: activeFocus || dimUnit ? _plain : _plain + unit

    onActiveFocusChanged: {
        if (activeFocus)
            selectAll()
        else
            text = Qt.binding(() => (control.activeFocus || control.dimUnit) ? control._plain : control._plain + control.unit)
    }

    onEditingFinished: {
        const v = Number(text.replace(",", "."))
        if (!isNaN(v))
            committed(Math.max(from, Math.min(to, v / multiplier)))
        text = Qt.binding(() => (control.activeFocus || control.dimUnit) ? control._plain : control._plain + control.unit)
    }

    Keys.onEscapePressed: (event) => {
        text = Qt.binding(() => (control.activeFocus || control.dimUnit) ? control._plain : control._plain + control.unit)
        control.focus = false
        event.accepted = true
    }
}
