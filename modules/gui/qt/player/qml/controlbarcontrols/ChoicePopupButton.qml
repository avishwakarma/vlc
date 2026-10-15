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
import VLC.Playlist
import VLC.Util

// Icon button opening a popup list of the entries of a model (display / checked roles).
// Used by the zoom and chapters items.
Widgets.PopupIconToolButton {
    id: root

    property alias model: list.model
    // optional item shown above the entries
    property alias header: list.header
    property string emptyText: ""

    // called with the index of the clicked entry
    property var activate: function(index) {}

    readonly property real _rowHeight: VLCStyle.dp(36, VLCStyle.scale)

    popup.width: VLCStyle.dp(240, VLCStyle.scale)

    popup.contentItem: ListView {
        id: list

        implicitHeight: Math.min(contentHeight, root._rowHeight * 9)

        clip: true
        focus: true
        currentIndex: -1

        T.ScrollBar.vertical: Widgets.ScrollBarExt {}

        delegate: T.ItemDelegate {
            id: delegate

            required property int index
            required property var model

            width: ListView.view.width
            height: root._rowHeight

            padding: 0

            hoverEnabled: true

            readonly property ColorContext colorContext: ColorContext {
                id: rowTheme
                colorSet: ColorContext.Item
                hovered: delegate.hovered
                pressed: delegate.down
            }

            background: Rectangle {
                radius: VLCStyle.radius_m
                color: (delegate.hovered || delegate.down) ? rowTheme.bg.primary : "transparent"
            }

            contentItem: Row {
                spacing: VLCStyle.spacing_8
                leftPadding: VLCStyle.spacing_8

                Widgets.SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check-active"
                    size: VLCStyle.dp(16, VLCStyle.scale)
                    accentColor: rowTheme.accent
                    color: rowTheme.accent
                    opacity: delegate.model.checked ? 1.0 : 0.0
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: delegate.width - VLCStyle.dp(40, VLCStyle.scale)
                    text: delegate.model.display
                    color: rowTheme.fg.primary
                    font.pixelSize: VLCStyle.text_body
                    elide: Text.ElideRight
                }
            }

            onClicked: {
                root.activate(delegate.index)
                root.popup.close()
            }
        }
    }
}
