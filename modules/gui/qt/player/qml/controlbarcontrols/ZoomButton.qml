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

// Zoom: choose one of the zoom levels of the video output (vout "zoom" variable)
ChoicePopupButton {
    id: root

    enabled: !paintOnly && Player.hasVideoOutput

    text: VLCIcons.aspect_ratio
    iconName: "zoom"

    description: qsTr("Zoom")

    T.ToolTip.text: PlayerAux.tip(description, "zoom")

    AccessibleCompat.id: "zoomButton"

    model: Player.zoom

    // "Fill": crop the picture to cover the whole viewport (vout fit mode "Outside Window"),
    // the other entries are the zoom levels. Fit modes are listed by Player.fit in the order
    // None, Inside Window, Outside Window, Window Width, Window Height.
    readonly property int _fitInside: 1
    readonly property int _fitOutside: 2
    readonly property bool _fill: _fillCheck.checkedRow === _fitOutside

    Item {
        id: _fillCheck

        property int checkedRow: -1

        Repeater {
            model: Player.fit
            delegate: Item {
                required property int index
                required property var model
                readonly property bool isChecked: model.checked
                onIsCheckedChanged: if (isChecked) _fillCheck.checkedRow = index
                Component.onCompleted: if (isChecked) _fillCheck.checkedRow = index
            }
        }
    }

    header: T.ItemDelegate {
        id: fillRow

        width: ListView.view ? ListView.view.width : 0
        height: VLCStyle.dp(36, VLCStyle.scale)
        padding: 0
        hoverEnabled: true

        readonly property ColorContext colorContext: ColorContext {
            id: fillTheme
            colorSet: ColorContext.Item
            hovered: fillRow.hovered
            pressed: fillRow.down
        }

        background: Rectangle {
            radius: VLCStyle.radius_m
            color: (fillRow.hovered || fillRow.down) ? fillTheme.bg.primary : "transparent"
        }

        contentItem: Row {
            spacing: VLCStyle.spacing_8
            leftPadding: VLCStyle.spacing_8

            Widgets.SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "check-active"
                size: VLCStyle.dp(16, VLCStyle.scale)
                accentColor: fillTheme.accent
                color: fillTheme.accent
                opacity: root._fill ? 1.0 : 0.0
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Fill (crop to viewport)")
                color: fillTheme.fg.primary
                font.pixelSize: VLCStyle.text_body
            }
        }

        onClicked: {
            Player.fit.toggleIndex(root._fill ? root._fitInside : root._fitOutside)
            root.popup.close()
        }
    }

    activate: function(index) { Player.zoom.toggleIndex(index) }
}
