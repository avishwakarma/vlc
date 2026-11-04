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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Menus
import VLC.Util

T.Page {
    id: root

    //path of the current page loader
    property var pagePrefix: []

    //note that T.Page introduce an intermediate Item, so to access our delegate,
    //we need to use contentChildren[0] rather than contentItem
    readonly property Item _firstChild: contentChildren[0] ?? null

    //indicates whether the subview support grid/list mode
    property bool hasGridListMode: _firstChild?.hasGridListMode ?? false

    // vertical scroll offset of the page content (0 when at the beginning)
    readonly property real _scrollOffset: {
        const c = _firstChild
        if (!c)
            return 0
        const y = c.contentY ?? c.currentView?.contentY ?? c.view?.contentY ?? 0
        const o = c.originY ?? c.currentView?.originY ?? c.view?.originY ?? 0
        return y - o
    }

    // set by a child table view that draws its own divider below its sticky column header
    property bool headerDividerSuppressed: false

    property bool isSearchable: _firstChild?.isSearchable ?? false

    property var sortModel: _firstChild?.sortModel ?? null

    //property is *not* readOnly, a PageLoader may define a localMenuDelegate common for its subviews (music, video)
    property SortMenu sortMenu: null

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    readonly property SearchCtx search: _searchCtx
    readonly property SortCtx sort: _sortCtx


    SearchCtx {
        id: _searchCtx
        available: root.isSearchable
    }

    SortCtx {
        id: _sortCtx

        readonly property string _sortCriteriaKey: ["sortCriteria", ...root.pagePrefix].join("/")
        readonly property string _sortOrderKey:  ["sortOrder", ...root.pagePrefix].join("/")

        available: Helpers.isArray(root.sortModel) && (root.sortModel).length > 0
        model: root.sortModel

        //save & restore setting of the page
        Component.onCompleted: {
            const criteria = MainCtx.settingValue(_sortCriteriaKey, undefined)
            if (criteria !== undefined)
                _sortCtx.criteria = criteria

            const order = MainCtx.settingValue(_sortOrderKey, undefined)
            if (order !== undefined)
                _sortCtx.order = parseInt(order)
        }

        Component.onDestruction: {
            MainCtx.setSettingValue(_sortCriteriaKey, _sortCtx.criteria)
            MainCtx.setSettingValue(_sortOrderKey, _sortCtx.order)
        }
    }

    Binding {
        target: MainCtx
        property: "hasGridListMode";
        value: root.hasGridListMode
    }

    on_FirstChildChanged: {
        if (!_firstChild)
            return
        _firstChild.Navigation.parentItem = root
        _firstChild.Navigation.upItem = root.header
    }

    function positionContentAtBeginning() {
        _firstChild?.positionContentAtBeginning?.()
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding
                             + (implicitHeaderHeight > 0 ? implicitHeaderHeight + spacing : 0)
                             + (implicitFooterHeight > 0 ? implicitFooterHeight + spacing : 0))

    header: DefaultPageHeader {
        text: root.title

        pagePrefix: root.pagePrefix
        itemCount: root._firstChild?.model?.count ?? -1

        leftPadding: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_left_margin + root.leftPadding
        rightPadding: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_right_margin + root.rightPadding

        sortMenu: root.sortMenu

        search: _searchCtx
        sort: _sortCtx

        Navigation.parentItem: root
        Navigation.downAction: function() {
            if (typeof root.setCurrentItemFocus === "function")
                root.setCurrentItemFocus(Qt.TabFocusReason)
            else if (typeof root._firstChild?.setCurrentItemFocus === "function")
             root._firstChild.setCurrentItemFocus(Qt.TabFocusReason)
            else if (root._firstChild)
                root._firstChild.forceActiveFocus(Qt.TabFocusReason)
        }
    }

    component DefaultPageHeader: T.ToolBar {
        id: defaultPageHeader

        // Properties
        property string text

        property var pagePrefix: []

        // number of items of the page model, negative when unknown
        property int itemCount: -1

        // path entries of the page loader (without the "home" sub page) followed by the page title
        readonly property var crumbs: {
            const out = []
            for (let i = 0; i < pagePrefix.length; ++i) {
                // only the entries that have a label are crumbs ("browse", "all", ... are not)
                if (i > 0 && pagePrefix[i] === "home")
                    continue
                if (crumbLabel(pagePrefix[i]) === pagePrefix[i])
                    continue
                out.push(crumbLabel(pagePrefix[i]))
            }

            // the network root page is titled "Browse", the Figma title is "Network"
            if (!(pagePrefix[0] === "network" && text === qsTr("Browse") && out.length === 1) && text !== ""
                    && out[out.length - 1] !== text)
                out.push(text)
            return out
        }

        // Figma labels of the path entries of the page loader
        function crumbLabel(name) {
            const names = {
                "home": qsTr("Home"), "video": qsTr("Videos"), "music": qsTr("Music"),
                "network": qsTr("Network"), "playlists": qsTr("Playlists"), "discover": qsTr("Discover"),
                "albums": qsTr("Albums"), "artists": qsTr("Artists"), "genres": qsTr("Genres"),
                "tracks": qsTr("Songs"), "videos": qsTr("Videos"), "groups": qsTr("Shows")
            }
            return names[name] ?? name
        }

        property alias sortMenu: gridSortFilter.sortMenu

        property alias search: gridSortFilter.search
        property alias sort: gridSortFilter.sort

        position: T.ToolBar.Header

        topPadding: VLCStyle.layoutTitle_top_padding
        bottomPadding: VLCStyle.layoutTitle_bottom_padding

        // FIXME: `GridItem`'s background extends beyond its
        //        bounding rect, violating the hypothetical
        //        clip test (see 7e6b23db).
        bottomInset: (MainCtx.hasGridListMode && MainCtx.gridView) ? VLCStyle.gridItemSelectedBorder : undefined

        // Settings

        implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                 implicitContentHeight + topPadding + bottomPadding)

        Navigation.navigable: gridSortFilter.enabled

        // Children

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            colorSet: ColorContext.View
        }

        // The header is an opaque surface on the Pane colour (the colour of the library window),
        // drawn above the page content so that scrolling content never shows through it. A subtle
        // divider fades in when content is scrolled underneath.
        z: 10

        readonly property ColorContext paneContext: ColorContext {
            id: paneTheme
            colorSet: ColorContext.Pane
        }

        // true when the page content is scrolled below its beginning, i.e. content is under the header
        readonly property bool contentUnderHeader: (root._scrollOffset > 1)

        background: Rectangle {
            // the Pane colour is translucent (a=0.95), the header must be opaque
            color: Qt.alpha(paneTheme.bg.primary, 1.0)

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.bottom
                }

                height: VLCStyle.dp(1, VLCStyle.scale)
                color: theme.fg.secondary
                opacity: (defaultPageHeader.contentUnderHeader && !root.headerDividerSuppressed) ? 0.2 : 0

                Behavior on opacity {
                    NumberAnimation { duration: VLCStyle.duration_short }
                }
            }
        }

        RowLayout {
            id: row

            anchors.fill: parent

            // back / forward arrows (the history has no forward stack: the arrow is drawn disabled)
            IconToolButton {
                id: backButton

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                iconName: "arrow-left"
                text: VLCIcons.back
                description: qsTr("Previous")
                enabled: !History.previousEmpty

                onClicked: History.previous()

                Navigation.parentItem: defaultPageHeader
                Navigation.rightItem: forwardButton
            }

            IconToolButton {
                id: forwardButton

                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: VLCStyle.spacing_8
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                iconName: "arrow-right"
                text: VLCIcons.back
                description: qsTr("Next")
                enabled: false
            }

            // breadcrumb: path entries, the current page in semibold
            Row {
                id: crumbRow

                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.spacing_12
                Layout.alignment: Qt.AlignVCenter

                spacing: VLCStyle.spacing_8

                Repeater {
                    model: defaultPageHeader.crumbs

                    delegate: Row {
                        id: crumb

                        required property int index
                        required property string modelData

                        readonly property bool isLast: (index === defaultPageHeader.crumbs.length - 1)

                        spacing: VLCStyle.spacing_8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            text: crumb.modelData
                            color: crumb.isLast ? theme.fg.highlight : theme.fg.primary
                            font.pixelSize: VLCStyle.text_heading
                            font.weight: crumb.isLast ? VLCStyle.fontWeight_semibold : VLCStyle.fontWeight_regular
                            textFormat: Text.PlainText
                        }

                        SvgIcon {
                            anchors.verticalCenter: parent.verticalCenter

                            visible: !crumb.isLast
                            name: "chevron-right"
                            size: VLCStyle.icon_xsmall
                            color: theme.fg.secondary
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter

                visible: defaultPageHeader.itemCount >= 0
                text: defaultPageHeader.itemCount === 1 ? qsTr("1 item") : qsTr("%1 items").arg(defaultPageHeader.itemCount)
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }

            GridSortFilterControls {
                id: gridSortFilter
                focus: true
                sort: _sortCtx
                search: _searchCtx
                Navigation.parentItem: defaultPageHeader
            }
        }
    }
}
