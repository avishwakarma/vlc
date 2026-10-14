/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Dialogs
import VLC.Util

// A panel of the library sidebar: header (breadcrumb, count, sort, view, search buttons) and a
// content area. The sort, view and "more" popups are native menus (Figma 856:2215, 858:3290, 2139:8935).
FocusScope {
    id: root

    // Properties

    // the sidebar, provides the navigation state
    property var nav: null

    // titles of the path including this page
    property var crumbs: []

    property int itemCount: -1

    // [{text, criteria}], same format as the library views
    property var sortModel: null
    property string sortCriteria: ""
    property int sortOrder: Qt.AscendingOrder

    property bool searchable: false
    property bool viewOptions: false

    // library path opened by the "open in library" button
    property var libraryPath: []

    // entries of the "more" menu: [{text, icon, action}], defaults to the folder menu
    property var moreEntries: defaultMoreEntries

    readonly property alias searchPattern: header.searchText

    readonly property var defaultMoreEntries: {
        const entries = [
            { text: qsTr("Add File"), icon: "add", action: () => DialogsProvider.simpleOpenDialog() },
            { text: qsTr("Add Folder"), icon: "new-folder-twotone", action: () => DialogsProvider.PLOpenDir() }
        ]
        if (MainCtx.mediaLibraryAvailable)
            entries.push({ text: qsTr("Resync"), icon: "refresh-twotone", action: () => MediaLib.reload() })
        return entries
    }

    default property alias content: contentArea.data
    property alias contentArea: contentArea

    // Settings

    focus: true

    readonly property ColorContext colorContext: ColorContext {
        colorSet: ColorContext.Pane
    }

    function focusContent() {
        contentArea.forceActiveFocus(Qt.TabFocusReason)
    }

    // Children

    SidebarHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        crumbs: root.crumbs
        itemCount: root.itemCount

        canGoBack: root.nav ? root.nav.canGoBack : false
        canGoForward: root.nav ? root.nav.canGoForward : false

        sortAvailable: Helpers.isArray(root.sortModel) && root.sortModel.length > 0
        sortActive: root.sortCriteria !== ""
        viewAvailable: root.viewOptions
        searchAvailable: root.searchable

        Navigation.parentItem: root
        Navigation.downItem: contentArea

        onBackClicked: root.nav.goBack()
        onForwardClicked: root.nav.goForward()
        onOpenLibraryClicked: root.nav.openLibrary(root.libraryPath)
        onMoreClicked: (pos) => moreMenu.popupEntries(pos)
        onSortClicked: (pos) => sortMenu.popupModel(pos)
        onViewClicked: (pos) => viewMenu.popupEntries(pos)
        onSearchToggled: {
            searchOpen = !searchOpen
            if (searchOpen)
                focusSearch()
            else {
                searchText = ""
                root.focusContent()
            }
        }
    }

    FocusScope {
        id: contentArea

        anchors.top: header.bottom
        anchors.topMargin: VLCStyle.dp(14, VLCStyle.scale)
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: VLCStyle.spacing_20
        anchors.rightMargin: VLCStyle.spacing_20

        focus: true

        Navigation.parentItem: root
        Navigation.upItem: header
    }

    // Popups

    Menus.SortMenu {
        id: sortMenu

        ctx: MainCtx

        function popupModel(pos) {
            const model = root.sortModel.map((entry) => {
                const checked = entry.criteria === root.sortCriteria
                return { "text": entry.text, "checked": checked, "order": checked ? root.sortOrder : undefined }
            })
            popup(pos, false, model)
        }

        onSelected: (index) => {
            const key = root.sortModel[index].criteria
            if (key !== root.sortCriteria) {
                root.sortCriteria = key
                root.sortOrder = Qt.AscendingOrder
            } else {
                root.sortOrder = (root.sortOrder === Qt.AscendingOrder) ? Qt.DescendingOrder : Qt.AscendingOrder
            }
        }
    }

    Menus.StringListMenu {
        id: viewMenu

        ctx: MainCtx
        rightCheck: true

        function popupEntries(pos) {
            popup(pos, [
                { text: qsTr("Grid View"), icon: "grid", checked: root.nav?.gridView ?? false },
                { text: qsTr("List View"), icon: "list", checked: !(root.nav?.gridView ?? false) }
            ])
        }

        onSelected: (index) => { if (root.nav) root.nav.gridView = (index === 0) }
    }

    Menus.StringListMenu {
        id: moreMenu

        ctx: MainCtx

        function popupEntries(pos) {
            popup(pos, root.moreEntries.map((entry) => ({ text: entry.text, icon: entry.icon })))
        }

        onSelected: (index) => { root.moreEntries[index].action() }
    }
}
