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
import VLC.Widgets as Widgets

// Base of every settings page (see pages/). The shell puts a page in a
// scrolling area; the page lays out its sections, then the sticky
// "Advanced Options" bar and the advanced sections.
//
//   SettingsPage {
//       SettingSection { title: ...; SettingRow { ... } }
//       advanced: [ SettingSection { ... } ]
//   }
//
// The Figma row -> VLC option map of a page belongs in the header of its file.
ColumnLayout {
    id: page

    readonly property bool isSettingsPage: true

    // set by the shell: the text typed in the search field ("" = none)
    property string filter: ""
    readonly property bool searching: filter.trim() !== ""

    // the Flickable the page scrolls in (for the sticky bar)
    property Flickable viewport: null

    property bool advancedExpanded: false

    // sections of the main part
    default property alias content: mainColumn.data
    // sections only shown after "Advanced Options" is expanded
    property alias advanced: advancedColumn.data

    // emitted by the sections when they appear or disappear
    signal sectionsChanged()

    function _anyShown(column) {
        for (let i = 0; i < column.children.length; ++i) {
            const c = column.children[i]
            if (c.isSettingSection ? c.hasRows : c.visible)
                return true
        }
        return false
    }

    // true when at least one section is visible (search results)
    property bool hasMatches: false
    property bool hasAdvancedRows: false

    onSectionsChanged: {
        hasMatches = _anyShown(mainColumn) || _anyShown(advancedColumn)
        hasAdvancedRows = _anyShown(advancedColumn)
    }

    Component.onCompleted: sectionsChanged()

    readonly property bool _showAdvanced: searching || advancedExpanded

    Layout.fillWidth: true
    spacing: VLCStyle.spacing_20

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    ColumnLayout {
        id: mainColumn

        Layout.fillWidth: true
        spacing: VLCStyle.spacing_20
    }

    // sticky bar: stays at the bottom of the viewport until its natural place
    // is reached
    Item {
        id: barSlot

        visible: page.hasAdvancedRows && !page.searching

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(38, VLCStyle.scale)

        Item {
            id: bar

            width: parent.width
            height: parent.height
            z: 10

            y: page.viewport
               ? Math.min(0, page.viewport.contentY + page.viewport.height - page.y - barSlot.y - barSlot.height)
               : 0

            Behavior on y {
                enabled: false
            }

            Rectangle {
                id: barBg

                anchors.fill: parent
                radius: VLCStyle.radius_xxs
                color: barButton.hovered || barButton.visualFocus ? barTheme.bg.primary : theme.bg.secondary

                Behavior on color {
                    ColorAnimation { duration: VLCStyle.duration_short }
                }

                border.width: barButton.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                border.color: theme.visualFocus
            }

            readonly property ColorContext _barTheme: ColorContext {
                id: barTheme
                colorSet: ColorContext.Item
                hovered: true
            }

            MouseArea {
                // hover/press target only
                id: barButton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                readonly property bool hovered: containsMouse
                readonly property bool visualFocus: false

                onClicked: page.advancedExpanded = !page.advancedExpanded
            }

            Row {
                anchors.centerIn: parent
                spacing: VLCStyle.spacing_10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Advanced Options")
                    color: barButton.hovered ? theme.fg.highlight : theme.fg.primary
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular

                    Behavior on color {
                        ColorAnimation { duration: VLCStyle.duration_short }
                    }
                }

                Widgets.SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron-right"
                    size: VLCStyle.icon_normal
                    color: barButton.hovered ? theme.fg.highlight : theme.fg.primary
                    rotation: page.advancedExpanded ? 90 : 0

                    Behavior on rotation {
                        NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
                    }
                }
            }

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Advanced Options")
            Accessible.onPressAction: page.advancedExpanded = !page.advancedExpanded
        }
    }

    // collapsible advanced part
    Item {
        id: advancedClip

        visible: page.hasAdvancedRows && (page._showAdvanced || shownHeight > 0.5)

        Layout.fillWidth: true
        property real shownHeight: page._showAdvanced ? advancedColumn.implicitHeight : 0

        Behavior on shownHeight {
            NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
        }

        Layout.preferredHeight: shownHeight

        clip: true
        opacity: page._showAdvanced ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: VLCStyle.duration_long }
        }

        ColumnLayout {
            id: advancedColumn

            width: parent.width
            spacing: VLCStyle.spacing_20
        }
    }
}
