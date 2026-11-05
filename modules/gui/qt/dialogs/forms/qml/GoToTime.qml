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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// Go to Time: type h:mm:ss (or m:ss, or plain seconds) and press Enter to jump.
DialogShell {
    id: root

    heading: qsTr("Go to Time")
    cardWidth: 440
    cardHeight: 300

    acceptText: qsTr("Go")
    acceptEnabled: valid
    initialFocusItem: timeField

    // total length in ms, 0 when unknown (live streams)
    property real length: 0
    readonly property real parsed: parseTime(timeField.text)
    readonly property bool valid: parsed >= 0 && (length <= 0 || parsed <= length)

    // "1:02:03", "62:03", "3723" or "1h2m3s" to ms, -1 when invalid
    function parseTime(text) {
        const t = text.trim()
        if (t === "")
            return -1
        let m = /^(\d+)[hH]\s*(?:(\d+)[mM]\s*)?(?:(\d+)[sS]?)?$/.exec(t)
        if (m)
            return ((Number(m[1]) * 60 + Number(m[2] || 0)) * 60 + Number(m[3] || 0)) * 1000
        m = /^(\d+)[mM]\s*(?:(\d+)[sS]?)?$/.exec(t)
        if (m)
            return (Number(m[1]) * 60 + Number(m[2] || 0)) * 1000
        if (!/^\d+(:\d{1,2}){0,2}$/.test(t))
            return -1
        const parts = t.split(":").map(Number)
        if (parts.length > 1 && parts.slice(1).some(p => p > 59))
            return -1
        let s = 0
        for (const p of parts)
            s = s * 60 + p
        return s * 1000
    }

    function format(ms) {
        const total = Math.floor(ms / 1000)
        const h = Math.floor(total / 3600)
        const mm = Math.floor(total / 60) % 60
        const ss = total % 60
        const two = v => (v < 10 ? "0" : "") + v
        return h + ":" + two(mm) + ":" + two(ss)
    }

    function present() {
        length = forms.lengthMs()
        timeField.text = format(forms.currentTimeMs())
        if (!visible)
            open()
        else {
            raise()
            requestActivate()
        }
        timeField.forceActiveFocus()
        timeField.selectAll()
    }

    onAccepted: {
        forms.seekToMs(parsed)
        close()
    }

    DialogForms {
        id: forms
        ctx: MainCtx
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    Column {
        x: VLCStyle.spacing_20
        y: VLCStyle.dp(22, VLCStyle.scale)
        width: root.body.width - 2 * VLCStyle.spacing_20
        spacing: VLCStyle.spacing_16

        DialogHeading {
            width: parent.width
            label: qsTr("Jump to")
            helper: root.length > 0 ? qsTr("Hours, minutes and seconds, e.g. 1:23:45. The media is %1 long.").arg(root.format(root.length))
                                    : qsTr("Hours, minutes and seconds, e.g. 1:23:45.")
        }

        Widgets.TextFieldExt {
            id: timeField

            width: parent.width
            height: VLCStyle.dp(48, VLCStyle.scale)
            font.pixelSize: VLCStyle.text_subtitle
            font.features: { "tnum": 1 }
            horizontalAlignment: Text.AlignHCenter
            selectByMouse: true
            placeholderText: "0:00:00"
            inputMethodHints: Qt.ImhNoPredictiveText

            // invalid input is flagged with the negative colour
            color: (text !== "" && !root.valid) ? theme.fg.negative : theme.fg.primary

            onAccepted: root.accept()

            Accessible.name: qsTr("Time")
        }

        Text {
            width: parent.width
            height: VLCStyle.dp(20, VLCStyle.scale)
            text: timeField.text === "" ? ""
                  : root.parsed < 0 ? qsTr("Enter a time like 1:23:45")
                  : !root.valid ? qsTr("Past the end of the media")
                  : ""
            color: theme.fg.negative
            font.pixelSize: VLCStyle.text_body
            textFormat: Text.PlainText
        }
    }
}
