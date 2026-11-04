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
// scrolling area; the page lays out its sections, then the advanced sections
// (only while the window's "Show advanced settings" switch is on, or when
// searching).
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

    // the Flickable the page scrolls in
    property Flickable viewport: null

    // "Show advanced settings" switch of the window (SettingsModel.showAdvanced), set by the shell
    property bool showAdvanced: false

    // the column holding the advanced sections (SettingSection marks itself with it)
    readonly property Item advancedHost: advancedColumn

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

    readonly property bool _showAdvanced: searching || showAdvanced

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
