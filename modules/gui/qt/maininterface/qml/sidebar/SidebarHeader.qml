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
import QtQuick.Layouts
import QtQuick.Shapes

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Header of a library sidebar panel (Figma 848:1995): back/forward arrows, breadcrumb,
// "more" and "open in library" buttons; below it the item count with the sort, view and
// search buttons; a divider closes the header.
FocusScope {
    id: root

    // Properties

    // titles of the path, the last one is the current page
    property var crumbs: []

    // number of items of the page, negative hides the label
    property int itemCount: -1

    property bool canGoBack: false
    property bool canGoForward: false

    property bool sortAvailable: false

    // a sort criteria was chosen: the sort icon gets the accent dot
    property bool sortActive: false
    property bool viewAvailable: false
    property bool searchAvailable: false
    property bool moreAvailable: true

    property bool searchOpen: false

    property alias searchText: searchField.text

    // Signals

    signal backClicked()
    signal forwardClicked()
    signal moreClicked(point globalPos)
    signal openLibraryClicked()
    signal sortClicked(point globalPos)
    signal viewClicked(point globalPos)
    signal searchToggled()

    // Settings

    readonly property real _button: VLCStyle.windowButton_h
    readonly property real _side: VLCStyle.dp(18, VLCStyle.scale)

    // crumbs that are drawn: the last two, preceded by an ellipsis when the path is deeper
    readonly property var _shown: crumbs.length > 2 ? ["...", crumbs[crumbs.length - 2], crumbs[crumbs.length - 1]]
                                                    : crumbs

    implicitWidth: VLCStyle.sidebarPanel_w
    implicitHeight: VLCStyle.dp(106, VLCStyle.scale) + searchRow.height

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    ColorContext {
        id: dimTheme
        colorSet: ColorContext.Pane
        enabled: false
    }

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Panel header")

    // Row 1: navigation and breadcrumb
    Item {
        id: row1

        x: 0
        y: VLCStyle.dp(14, VLCStyle.scale)
        width: parent.width
        height: VLCStyle.dp(34, VLCStyle.scale)

        Widgets.IconToolButton {
            id: backButton

            x: root._side
            anchors.verticalCenter: parent.verticalCenter
            width: root._button
            height: root._button

            iconName: "arrow-left"
            text: VLCIcons.back
            description: qsTr("Previous")
            enabled: root.canGoBack

            Navigation.parentItem: root
            Navigation.rightItem: forwardButton
            Navigation.downItem: sortButton

            onClicked: root.backClicked()
        }

        Widgets.IconToolButton {
            id: forwardButton

            x: root._side + VLCStyle.dp(36, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: root._button
            height: root._button

            iconName: "arrow-right"
            text: VLCIcons.back
            description: qsTr("Next")
            enabled: root.canGoForward

            Navigation.parentItem: root
            Navigation.leftItem: backButton
            Navigation.rightItem: moreButton
            Navigation.downItem: sortButton

            onClicked: root.forwardClicked()
        }

        // breadcrumb
        RowLayout {
            id: crumbRow

            x: root._side + VLCStyle.dp(36, VLCStyle.scale) * 2 - VLCStyle.dp(2, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter

            width: moreButton.x - x - VLCStyle.spacing_8
            height: parent.height

            spacing: VLCStyle.spacing_8

            Repeater {
                model: root._shown

                delegate: RowLayout {
                    id: crumb

                    required property int index
                    required property string modelData

                    readonly property bool isLast: index === root._shown.length - 1

                    // the last crumb takes the remaining width and elides
                    Layout.fillWidth: isLast
                    Layout.fillHeight: true

                    spacing: VLCStyle.spacing_8

                    Text {
                        Layout.fillWidth: crumb.isLast
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0

                        text: crumb.modelData
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter

                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.text_heading
                        font.weight: VLCStyle.fontWeight_regular
                    }

                    // separator triangle
                    Item {
                        visible: !crumb.isLast
                        Layout.preferredWidth: VLCStyle.dp(8, VLCStyle.scale)
                        Layout.fillHeight: true

                        Shape {
                            anchors.centerIn: parent
                            width: VLCStyle.dp(5, VLCStyle.scale)
                            height: VLCStyle.dp(7, VLCStyle.scale)

                            ShapePath {
                                strokeWidth: 0
                                fillColor: dimTheme.fg.primary

                                startX: 0
                                startY: 0

                                PathLine { x: VLCStyle.dp(5, VLCStyle.scale); y: VLCStyle.dp(3.5, VLCStyle.scale) }
                                PathLine { x: 0; y: VLCStyle.dp(7, VLCStyle.scale) }
                            }
                        }
                    }
                }
            }
        }

        Widgets.IconToolButton {
            id: moreButton

            x: parent.width - root._side - width - VLCStyle.dp(36, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: root._button
            height: root._button

            visible: root.moreAvailable

            iconName: "more"
            text: VLCIcons.more
            description: qsTr("More")

            Navigation.parentItem: root
            Navigation.leftItem: forwardButton
            Navigation.rightItem: openButton
            Navigation.downItem: searchButton

            onClicked: root.moreClicked(mapToGlobal(0, height))
        }

        Widgets.IconToolButton {
            id: openButton

            x: parent.width - root._side - width
            anchors.verticalCenter: parent.verticalCenter
            width: root._button
            height: root._button

            iconName: "open"
            text: VLCIcons.more
            description: qsTr("Open in library")

            Navigation.parentItem: root
            Navigation.leftItem: moreButton
            Navigation.downItem: searchButton

            onClicked: root.openLibraryClicked()
        }
    }

    // Row 2: item count, sort, view, search
    Item {
        id: row2

        y: VLCStyle.dp(59, VLCStyle.scale)
        width: parent.width
        height: VLCStyle.dp(34, VLCStyle.scale)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.spacing_20
            anchors.verticalCenter: parent.verticalCenter

            visible: root.itemCount >= 0

            text: root.itemCount === 1 ? qsTr("1 item") : qsTr("%1 items").arg(root.itemCount)
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
        }

        Widgets.IconToolButton {
            id: sortButton

            x: parent.width - root._side - width - VLCStyle.dp(36, VLCStyle.scale) * 2
            anchors.verticalCenter: parent.verticalCenter
            width: root._button
            height: root._button

            enabled: root.sortAvailable

            iconName: root.sortActive ? "sort-active" : "sort"
            text: VLCIcons.topbar_sort
            description: qsTr("Sort")

            Navigation.parentItem: root
            Navigation.upItem: backButton
            Navigation.rightItem: viewButton

            onClicked: root.sortClicked(mapToGlobal(0, height))
        }

        Widgets.IconToolButton {
            id: viewButton

            x: parent.width - root._side - width - VLCStyle.dp(36, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: root._button
            height: root._button

            enabled: root.viewAvailable

            iconName: "list"
            text: VLCIcons.list
            description: qsTr("View options")

            Navigation.parentItem: root
            Navigation.upItem: moreButton
            Navigation.leftItem: sortButton
            Navigation.rightItem: searchButton

            onClicked: root.viewClicked(mapToGlobal(0, height))
        }

        Widgets.IconToolButton {
            id: searchButton

            x: parent.width - root._side - width
            anchors.verticalCenter: parent.verticalCenter
            width: root._button
            height: root._button

            enabled: root.searchAvailable
            checked: root.searchOpen

            iconName: "search"
            text: VLCIcons.search
            description: qsTr("Search")

            Navigation.parentItem: root
            Navigation.upItem: openButton
            Navigation.leftItem: viewButton

            onClicked: root.searchToggled()
        }
    }

    // optional search field
    Item {
        id: searchRow

        y: row2.y + row2.height + VLCStyle.spacing_6
        x: VLCStyle.spacing_20
        width: parent.width - VLCStyle.spacing_20 * 2
        height: root.searchOpen ? VLCStyle.input_h + VLCStyle.spacing_6 : 0
        clip: true

        visible: height > 0

        Behavior on height {
            NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.InOutSine }
        }

        Widgets.TextFieldExt {
            id: searchField

            width: parent.width
            height: VLCStyle.input_h

            placeholderText: qsTr("Search")

            Navigation.parentItem: root

            Keys.onEscapePressed: root.searchToggled()
        }
    }

    // divider
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: VLCStyle.spacing_20
        anchors.rightMargin: VLCStyle.spacing_20
        anchors.bottom: parent.bottom

        height: VLCStyle.dp(1, VLCStyle.scale)
        color: theme.separator
    }

    function focusSearch() {
        searchField.forceActiveFocus(Qt.ShortcutFocusReason)
    }
}
