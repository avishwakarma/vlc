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


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

// Play queue toggle of the control bar (Figma 491:1928, "lists")
Widgets.IconToolButton {
    id: playlistBtn

    text: VLCIcons.playlist
    iconName: "lists"
    iconNameChecked: "lists-active"

    checked: PlayerHost.playlistVisible
    enabled: !paintOnly

    description: qsTr("Queue")

    T.ToolTip.text: PlayerAux.tip(description, "")

    AccessibleCompat.id: "playqueueButton"

    onClicked: PlayerHost.toggleQueue()

    onHoveredChanged: PlayerHost.requestLockUnlockAutoHide(hovered)

    // dropping media on the button opens the queue after a while
    DropArea {
        anchors.fill: parent

        enabled: !playlistBtn.paintOnly

        onContainsDragChanged: {
            if (containsDrag) {
                _timer.restart()

                if (PlayerHost.plListView)
                    MainCtx.setCursor(Qt.DragCopyCursor)
            } else {
                _timer.stop()

                if (PlayerHost.plListView)
                    MainCtx.restoreCursor()
            }
        }

        onEntered: (drag) => {
            const plListView = PlayerHost.plListView
            if (plListView && plListView.isDropAcceptableFunc(drag, plListView.model.count))
                drag.accept()
            else
                drag.accepted = false
        }

        onDropped: (drop) => {
            const plListView = PlayerHost.plListView
            if (plListView)
                plListView.acceptDropFunc(plListView.model.count, drop)
        }

        Timer {
            id: _timer
            interval: VLCStyle.duration_humanMoment

            onTriggered: {
                if (!PlayerHost.playlistVisible)
                    PlayerHost.toggleQueue()
            }
        }
    }
}
