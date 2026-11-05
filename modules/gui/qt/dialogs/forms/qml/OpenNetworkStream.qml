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

// Open Network Stream (Figma 6216:13614). One location per line; "Play" starts the first one,
// "Add to Queue" only appends. The optional name becomes the title of the queued entry.
DialogShell {
    id: root

    heading: qsTr("Open Network Stream")
    cardWidth: 1048
    cardHeight: 631

    acceptText: qsTr("Play")
    acceptEnabled: form.count > 0
    initialFocusItem: form.initialFocusItem

    onAccepted: submit(false)

    function submit(enqueue) {
        if (forms.openLocations(form.text, form.name, enqueue) > 0)
            close()
    }

    DialogForms {
        id: forms
        ctx: MainCtx
    }

    onVisibleChanged: {
        if (visible) {
            // like the legacy dialog: preselect the URLs of the clipboard
            form.reset(forms.clipboardLocations())
        }
    }

    footerData: [
        Widgets.DialogButton {
            text: qsTr("Add to Queue")
            enabled: root.acceptEnabled
            onClicked: root.submit(true)
        }
    ]

    NetworkStreamForm {
        id: form

        x: VLCStyle.spacing_20
        y: VLCStyle.dp(22, VLCStyle.scale)
        width: root.body.width - 2 * VLCStyle.spacing_20

        onSubmitRequested: root.accept()
    }
}
