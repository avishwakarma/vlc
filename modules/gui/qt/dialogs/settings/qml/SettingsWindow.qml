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


// Redesigned settings window (Figma 999:5047 and friends).
//
// Shell: header (search | page title | close), nav card (App / Media / System),
// a scrolling page area; the nav card ends with the "Show advanced settings" switch.
// Pages live in pages/ and are registered in `pages` below, see
// SettingsPage.qml and the "how to add a page" note in the W6 report.

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets

Window {
    id: root

    // --- page registry
    //
    // group: 0 = App, 1 = Media, 2 = System
    // key: deep link name (SettingsModel.openSettings). icon/iconActive: SvgIcon names.
    // heading: window header title (same as the nav name).
    // component: the page (a SettingsPage). Add a line here to add a page.
    readonly property var pages: [
        { group: 0, key: "general", name: qsTr("General"), heading: qsTr("General"), icon: "preferences", iconActive: "preferences-active", component: generalPage },
        { group: 0, key: "interface", name: qsTr("Interface"), heading: qsTr("Interface"), icon: "interface",   iconActive: "interface-active",   component: interfacePage },
        { group: 0, key: "privacy", name: qsTr("Privacy"), heading: qsTr("Privacy"), icon: "privacy",     iconActive: "privacy-active",     component: privacyPage },
        { group: 0, key: "controls", name: qsTr("Controls"), heading: qsTr("Controls"), icon: "hotkeys",     iconActive: "hotkeys-active",     component: controlsPage },
        { group: 1, key: "playback", name: qsTr("Playback"), heading: qsTr("Playback"), icon: "play",        iconActive: "playback-active",    component: playbackPage },
        { group: 1, key: "video", name: qsTr("Video"), heading: qsTr("Video"), icon: "video",       iconActive: "video-active",       component: videoPage },
        { group: 1, key: "audio", name: qsTr("Audio"), heading: qsTr("Audio"), icon: "audio",       iconActive: "audio-active",       component: audioPage },
        { group: 1, key: "subtitles", name: qsTr("Subtitles"), heading: qsTr("Subtitles"), icon: "subtitles",   iconActive: "subtitles-active",   component: subtitlesPage },
        { group: 1, key: "library", name: qsTr("Library"), heading: qsTr("Library"), icon: "folder",      iconActive: "folder-active",      component: libraryPage },
        { group: 2, key: "network", name: qsTr("Network"), heading: qsTr("Network"), icon: "streaming",   iconActive: "streaming-active",   component: networkPage },
        { group: 2, key: "performance", name: qsTr("Performance"), heading: qsTr("Performance"), icon: "preferences", iconActive: "preferences-active", component: performancePage },
        { group: 2, key: "recording", name: qsTr("Recording"), heading: qsTr("Recording"), icon: "record",      iconActive: "record-active",      component: recordingPage },
        { group: 2, key: "extensions", name: qsTr("Extensions"), heading: qsTr("Extensions"), icon: "plugins",     iconActive: "plugins-active",     component: extensionsPage },
    ]

    readonly property var groupNames: [qsTr("App"), qsTr("Media"), qsTr("System")]

    property int currentPage: 0

    // text applied to the pages (debounced search field)
    property string searchText: ""
    readonly property bool searching: searchText.trim() !== ""

    // transparent margins around the surface hold the shadow and the resize areas
    readonly property real marginLeft: VLCStyle.dp(15, VLCStyle.scale)
    readonly property real marginRight: VLCStyle.dp(15, VLCStyle.scale)
    readonly property real marginTop: VLCStyle.dp(7, VLCStyle.scale)
    readonly property real marginBottom: VLCStyle.dp(23, VLCStyle.scale)

    readonly property real surfaceWidth: VLCStyle.dp(1048, VLCStyle.scale)
    readonly property real surfaceHeight: VLCStyle.dp(865, VLCStyle.scale)

    title: qsTr("Settings")

    transientParent: MainCtx.intfMainWindow
    flags: Qt.Dialog | Qt.FramelessWindowHint

    width: surfaceWidth + marginLeft + marginRight
    height: surfaceHeight + marginTop + marginBottom
    minimumWidth: VLCStyle.dp(760, VLCStyle.scale) + marginLeft + marginRight
    minimumHeight: VLCStyle.dp(480, VLCStyle.scale) + marginTop + marginBottom

    color: "transparent"

    // WindowDialog compatible API (Dialogs.qml)
    function open() {
        show()
        raise()
        requestActivate()
    }

    function openPage(index) {
        searchField.text = ""
        root.searchText = ""
        currentPage = index
    }

    function setSearch(text) {
        searchField.text = text
        root.searchText = text
    }

    // Deep link: open page `pageKey` (see `pages`) and reveal the row of the VLC option `optionName`
    function openSetting(pageKey, optionName) {
        let idx = -1
        for (let i = 0; i < pages.length; ++i) {
            if (pages[i].key === pageKey)
                idx = i
        }
        openPage(idx >= 0 ? idx : currentPage)
        revealTimer.target = optionName || ""
        revealTimer.tries = 0
        if (revealTimer.target !== "")
            revealTimer.restart()
    }

    function _findRow(item, optionName) {
        if (!item)
            return null
        if (item.isSettingRow && item.option && item.option.name === optionName)
            return item
        const kids = item.children
        for (let i = 0; i < kids.length; ++i) {
            const r = _findRow(kids[i], optionName)
            if (r)
                return r
        }
        return null
    }

    Timer {
        id: revealTimer

        property string target: ""
        property int tries: 0

        interval: 160
        onTriggered: {
            const row = root._findRow(pageLoader.item, target)
            if (!row) {
                if (++tries < 12)
                    restart()
                return
            }
            // an advanced row needs the advanced sections: show them, then scroll once laid out
            if (row._section && row._section.isAdvanced && !SettingsModel.showAdvanced) {
                SettingsModel.showAdvanced = true
                restart()
                return
            }
            flick.scrollTo(row)
            row.highlighted = true
            target = ""
        }
    }

    // modal confirmation inside the window
    function confirm(heading, message, actionText, callback) {
        confirmOverlay.heading = heading
        confirmOverlay.message = message
        confirmOverlay.actionText = actionText
        confirmOverlay.callback = callback
        confirmOverlay.open = true
    }

    onClosing: SettingsModel.flush()

    onVisibleChanged: {
        if (visible) {
            surface.opacity = 0
            surface.scale = 0.98
            showAnimation.restart()
            content.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        if (MainCtx.createWindowWithoutRedirectionSurface) { // Win32
            const ret = MainCtx.createWindowWithoutRedirectionSurface(this)
            if (!ret)
                console.debug("MainCtx::createWindowWithoutRedirectionSurface(): returned false for window", this)
        }
    }

    ParallelAnimation {
        id: showAnimation

        NumberAnimation { target: surface; property: "opacity"; to: 1; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
        NumberAnimation { target: surface; property: "scale"; to: 1; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
    }

    readonly property ColorContext _wellTheme: ColorContext {
        id: wellTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    readonly property ColorContext _fieldTheme: ColorContext {
        id: fieldTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.TextField
    }

    readonly property ColorContext _itemTheme: ColorContext {
        id: itemTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Item
        hovered: true
    }

    // --- resize areas (the transparent margins)

    component EdgeArea : MouseArea {
        required property int edges
        property alias shape: area.cursorShape

        id: area
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton
        onPressed: root.startSystemResize(edges)
    }

    EdgeArea { edges: Qt.TopEdge; shape: Qt.SizeVerCursor; x: root.marginLeft; width: parent.width - root.marginLeft - root.marginRight; height: root.marginTop }
    EdgeArea { edges: Qt.BottomEdge; shape: Qt.SizeVerCursor; x: root.marginLeft; y: parent.height - height; width: parent.width - root.marginLeft - root.marginRight; height: root.marginBottom }
    EdgeArea { edges: Qt.LeftEdge; shape: Qt.SizeHorCursor; y: root.marginTop; width: root.marginLeft; height: parent.height - root.marginTop - root.marginBottom }
    EdgeArea { edges: Qt.RightEdge; shape: Qt.SizeHorCursor; x: parent.width - width; y: root.marginTop; width: root.marginRight; height: parent.height - root.marginTop - root.marginBottom }
    EdgeArea { edges: Qt.TopEdge | Qt.LeftEdge; shape: Qt.SizeFDiagCursor; width: root.marginLeft; height: root.marginTop }
    EdgeArea { edges: Qt.TopEdge | Qt.RightEdge; shape: Qt.SizeBDiagCursor; x: parent.width - width; width: root.marginRight; height: root.marginTop }
    EdgeArea { edges: Qt.BottomEdge | Qt.LeftEdge; shape: Qt.SizeBDiagCursor; y: parent.height - height; width: root.marginLeft; height: root.marginBottom }
    EdgeArea { edges: Qt.BottomEdge | Qt.RightEdge; shape: Qt.SizeFDiagCursor; x: parent.width - width; y: parent.height - height; width: root.marginRight; height: root.marginBottom }

    // --- surface

    Rectangle {
        id: surface

        x: root.marginLeft
        y: root.marginTop
        width: parent.width - root.marginLeft - root.marginRight
        height: parent.height - root.marginTop - root.marginBottom

        radius: VLCStyle.radius_xl
        color: theme.bg.primary

        transformOrigin: Item.Center

        // Items below inherit this palette through the item tree
        // (a Window is not an Item, so it can not carry it)
        readonly property ColorContext colorContext: ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.Pane
        }

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.shadow_floating.blur
            yOffset: VLCStyle.shadow_floating.y
            color: theme.shadow
            z: -1
        }

        FocusScope {
            id: content

            anchors.fill: parent
            focus: true

            Keys.priority: Keys.AfterItem
            Keys.onEscapePressed: (event) => {
                if (confirmOverlay.open) {
                    confirmOverlay.open = false
                } else if (searchField.text !== "") {
                    searchField.text = ""
                    root.searchText = ""
                } else {
                    root.close()
                }
                event.accepted = true
            }

            // --- header

            Item {
                id: header

                width: parent.width
                height: VLCStyle.settingsHeader_h

                // B2 band with rounded top corners
                Rectangle {
                    width: parent.width
                    height: surface.radius * 2
                    radius: surface.radius
                    color: wellTheme.bg.secondary
                }
                Rectangle {
                    y: surface.radius
                    width: parent.width
                    height: parent.height - surface.radius
                    color: wellTheme.bg.secondary
                }

                // drag the window by its header
                DragHandler {
                    target: null
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    onActiveChanged: if (active) root.startSystemMove()
                }

                // search
                Widgets.TextFieldExt {
                    id: searchField

                    x: VLCStyle.spacing_8
                    y: (header.height - height) / 2
                    width: VLCStyle.settingsNav_w
                    height: VLCStyle.input_h

                    leftPadding: VLCStyle.spacing_12 + VLCStyle.icon_normal + VLCStyle.spacing_6
                    rightPadding: clearButton.visible ? VLCStyle.icon_normal + VLCStyle.spacing_12 : VLCStyle.spacing_12
                    backgroundColor: fieldTheme.bg.primary
                    placeholderText: qsTr("Search")
                    selectByMouse: true

                    Accessible.searchEdit: true
                    Accessible.name: qsTr("Search settings")

                    onTextChanged: searchDebounce.restart()

                    Keys.onDownPressed: nav.focusCurrent()
                    Keys.onReturnPressed: nav.focusCurrent()

                    Timer {
                        id: searchDebounce
                        interval: 150
                        onTriggered: root.searchText = searchField.text
                    }

                    Widgets.SvgIcon {
                        x: VLCStyle.spacing_12 - VLCStyle.spacing_2
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: VLCStyle.icon_normal
                        color: searchField.activeFocus ? theme.fg.highlight : theme.fg.primary
                    }

                    Widgets.SvgIcon {
                        id: clearButton

                        visible: searchField.text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.spacing_8
                        anchors.verticalCenter: parent.verticalCenter
                        name: "close-low"
                        size: VLCStyle.icon_normal
                        color: clearArea.containsMouse ? theme.fg.highlight : theme.fg.secondary

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                root.searchText = ""
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }

                // page title
                Text {
                    x: VLCStyle.settingsNav_w + VLCStyle.spacing_8 * 2 + VLCStyle.spacing_24
                    anchors.verticalCenter: parent.verticalCenter
                    width: closeButton.x - x - VLCStyle.spacing_12

                    text: root.searching ? qsTr("Search results")
                                         : root.pages[root.currentPage].heading
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.text_heading
                    font.weight: VLCStyle.fontWeight_medium
                    elide: Text.ElideRight
                    textFormat: Text.PlainText

                    Accessible.role: Accessible.Heading
                }

                // close
                T.AbstractButton {
                    id: closeButton

                    x: parent.width - width - VLCStyle.spacing_14 + VLCStyle.spacing_2
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(32, VLCStyle.scale)
                    height: width

                    hoverEnabled: true
                    onClicked: root.close()

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Close")

                    Keys.priority: Keys.AfterItem
                    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                    background: Rectangle {
                        radius: VLCStyle.radius_s
                        color: closeButton.down ? itemTheme.bg.primary
                                                : (closeButton.hovered ? Qt.alpha(itemTheme.bg.primary, 0.7) : "transparent")
                        border.width: closeButton.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                        border.color: theme.visualFocus
                    }

                    contentItem: Widgets.SvgIcon {
                        name: "close"
                        size: VLCStyle.icon_normal
                        color: closeButton.hovered ? theme.fg.highlight : theme.fg.primary
                    }
                }
            }

            // --- nav card

            Rectangle {
                id: navCard

                x: VLCStyle.spacing_8
                y: header.height + VLCStyle.spacing_8
                width: VLCStyle.settingsNav_w
                height: parent.height - y - VLCStyle.spacing_8

                radius: VLCStyle.radius_m
                color: theme.bg.secondary

                Flickable {
                    id: nav

                    anchors.fill: parent
                    anchors.bottomMargin: advancedSwitch.height
                    anchors.leftMargin: VLCStyle.spacing_6
                    anchors.rightMargin: VLCStyle.spacing_6

                    topMargin: VLCStyle.spacing_8
                    bottomMargin: VLCStyle.spacing_8
                    contentHeight: navColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    function focusCurrent() {
                        const b = navRepeater.itemAt(root.currentPage)
                        if (b)
                            b.forceActiveFocus(Qt.TabFocusReason)
                    }

                    Column {
                        id: navColumn
                        width: parent.width
                        spacing: VLCStyle.spacing_8

                        Repeater {
                            id: navRepeater

                            model: root.pages

                            delegate: Column {
                                id: navEntry

                                required property int index
                                required property var modelData

                                readonly property bool firstOfGroup: index === 0 || root.pages[index - 1].group !== modelData.group

                                width: navColumn.width
                                spacing: VLCStyle.spacing_8

                                // group label (Figma: 14 px, FG/A3, px10 py8, with room around it)
                                Item {
                                    visible: navEntry.firstOfGroup
                                    width: parent.width
                                    height: visible ? VLCStyle.dp(32, VLCStyle.scale) : 0

                                    Text {
                                        x: VLCStyle.spacing_10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.groupNames[navEntry.modelData.group]
                                        color: theme.fg.secondary
                                        font.pixelSize: VLCStyle.text_body
                                        font.weight: VLCStyle.fontWeight_regular
                                    }
                                }

                                SettingsNavButton {
                                    id: navButton

                                    width: parent.width
                                    text: navEntry.modelData.name
                                    iconName: navEntry.modelData.icon
                                    selectedIconName: navEntry.modelData.iconActive
                                    selected: !root.searching && root.currentPage === navEntry.index

                                    activeFocusOnTab: root.currentPage === navEntry.index

                                    onClicked: root.openPage(navEntry.index)

                                    Keys.onUpPressed: root.stepPage(-1)
                                    Keys.onDownPressed: root.stepPage(1)
                                    Keys.onRightPressed: pageArea.focusFirst()
                                    Keys.onReturnPressed: pageArea.focusFirst()
                                    Keys.onEnterPressed: pageArea.focusFirst()
                                }

                                // the last button is followed by the card padding only
                            }
                        }
                    }
                }

                // "Show advanced settings": one switch for every page
                FocusScope {
                    id: advancedSwitch

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: VLCStyle.dp(52, VLCStyle.scale)

                    Rectangle {
                        x: VLCStyle.spacing_10
                        width: parent.width - 2 * x
                        height: VLCStyle.border
                        color: theme.separator
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.spacing_16
                        anchors.right: advancedToggle.left
                        anchors.rightMargin: VLCStyle.spacing_8
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Advanced settings")
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.text_body
                        font.weight: VLCStyle.fontWeight_regular
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Widgets.CheckButton {
                        id: advancedToggle

                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.spacing_10
                        anchors.verticalCenter: parent.verticalCenter
                        focus: true
                        checked: SettingsModel.showAdvanced
                        text: ""
                        onToggled: SettingsModel.showAdvanced = checked

                        Accessible.name: qsTr("Show advanced settings")

                        Keys.onUpPressed: nav.focusCurrent()
                    }
                }
            }

            // --- page area

            Item {
                id: pageArea

                x: navCard.x + navCard.width + VLCStyle.spacing_8
                y: header.height
                width: parent.width - x
                height: parent.height - y

                function focusFirst() {
                    const c = flick.firstFocusable(flick.contentItem)
                    if (c)
                        c.forceActiveFocus(Qt.TabFocusReason)
                }

                Flickable {
                    id: flick

                    anchors.fill: parent

                    topMargin: VLCStyle.spacing_20
                    bottomMargin: VLCStyle.dp(40, VLCStyle.scale)

                    contentWidth: width
                    contentHeight: pageHost.implicitHeight

                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    T.ScrollBar.vertical: Widgets.ScrollBarExt {
                        parent: flick.parent
                        anchors.top: flick.top
                        anchors.bottom: flick.bottom
                        anchors.right: flick.right
                    }

                    // finds the first row control in the page (keyboard entry)
                    function firstFocusable(item) {
                        if (!item || !item.visible)
                            return null
                        if (item.isSettingRow && item.control && item.enabled)
                            return item.control
                        const kids = item.children
                        for (let i = 0; i < kids.length; ++i) {
                            const r = firstFocusable(kids[i])
                            if (r)
                                return r
                        }
                        return null
                    }

                    // puts a row in the upper third of the viewport (deep links)
                    function scrollTo(item) {
                        const p = item.mapToItem(flick.contentItem, 0, 0)
                        const max = Math.max(-flick.topMargin, flick.contentHeight + flick.bottomMargin - flick.height)
                        flick.contentY = Math.max(-flick.topMargin, Math.min(max, p.y - flick.height / 3))
                    }

                    function ensureVisible(item) {
                        if (!item || !flick.contentItem)
                            return
                        const p = item.mapToItem(flick.contentItem, 0, 0)
                        const margin = VLCStyle.spacing_20
                        if (p.y - margin < flick.contentY)
                            flick.contentY = Math.max(-flick.topMargin, p.y - margin)
                        else if (p.y + item.height + margin > flick.contentY + flick.height)
                            flick.contentY = p.y + item.height + margin - flick.height
                    }

                    Connections {
                        target: root

                        function onActiveFocusItemChanged() {
                            const item = root.activeFocusItem
                            if (item && flick.contentItem.contains(flick.contentItem.mapFromItem(item, 0, 0)))
                                flick.ensureVisible(item)
                        }
                    }

                    // page host: the current page, or every page filtered while searching
                    Item {
                        id: pageHost

                        x: VLCStyle.spacing_24
                        width: flick.width - VLCStyle.spacing_24 * 2
                        implicitHeight: pageLoader.visible ? pageLoader.height : results.implicitHeight

                        Loader {
                            id: pageLoader

                            visible: !root.searching
                            active: !root.searching
                            width: parent.width
                            height: item ? item.implicitHeight : 0

                            sourceComponent: root.pages[root.currentPage].component

                            onLoaded: {
                                item.viewport = flick
                                item.showAdvanced = Qt.binding(() => SettingsModel.showAdvanced)
                                flick.contentY = -flick.topMargin
                                pageFade.restart()
                            }

                            SequentialAnimation {
                                id: pageFade

                                ParallelAnimation {
                                    NumberAnimation { target: pageLoader; property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: pageLoader; property: "y"; from: VLCStyle.spacing_8; to: 0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        // search results: all pages, rows filtered
                        ColumnLayout {
                            id: results

                            visible: root.searching
                            width: parent.width
                            spacing: VLCStyle.spacing_20

                            Repeater {
                                model: root.searching ? root.pages : []

                                delegate: ColumnLayout {
                                    id: resultPage

                                    required property int index
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: VLCStyle.spacing_4

                                    visible: loader.item ? loader.item.hasMatches : false

                                    // page the matches live on, click to open it
                                    T.AbstractButton {
                                        id: pageLink

                                        Layout.fillWidth: true
                                        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
                                        hoverEnabled: true
                                        onClicked: root.openPage(resultPage.index)

                                        Keys.priority: Keys.AfterItem
                                        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                                        Accessible.role: Accessible.Link
                                        Accessible.name: resultPage.modelData.name

                                        contentItem: Row {
                                            spacing: VLCStyle.spacing_6

                                            Widgets.SvgIcon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                name: resultPage.modelData.icon
                                                size: VLCStyle.dp(18, VLCStyle.scale)
                                                color: pageLink.hovered ? theme.fg.highlight : theme.fg.secondary
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: resultPage.modelData.name
                                                color: pageLink.hovered ? theme.fg.highlight : theme.fg.secondary
                                                font.pixelSize: VLCStyle.text_body
                                            }
                                        }
                                    }

                                    Loader {
                                        id: loader

                                        Layout.fillWidth: true
                                        sourceComponent: resultPage.modelData.component

                                        onLoaded: {
                                            item.filter = Qt.binding(() => root.searchText)
                                            item.viewport = flick
                                        }
                                    }
                                }
                            }

                            Text {
                                id: noResults

                                visible: {
                                    // nothing matched: every page hides itself
                                    for (let i = 0; i < results.children.length; ++i) {
                                        const c = results.children[i]
                                        if (c !== noResults && c.visible && c.modelData)
                                            return false
                                    }
                                    return true
                                }
                                Layout.fillWidth: true
                                Layout.topMargin: VLCStyle.spacing_20

                                text: qsTr("No settings match \"%1\"").arg(root.searchText)
                                color: theme.fg.secondary
                                font.pixelSize: VLCStyle.text_body
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            // --- restart banner

            Rectangle {
                id: restartBanner

                visible: opacity > 0
                opacity: SettingsModel.restartPending ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: VLCStyle.duration_long }
                }

                anchors.horizontalCenter: pageArea.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: VLCStyle.spacing_12 + VLCStyle.dp(40, VLCStyle.scale)

                width: bannerRow.implicitWidth + VLCStyle.spacing_14 * 2
                height: VLCStyle.dp(40, VLCStyle.scale)
                radius: VLCStyle.radius_m
                color: wellTheme.bg.primary
                border.width: VLCStyle.border
                border.color: theme.separator

                Row {
                    id: bannerRow

                    anchors.centerIn: parent
                    spacing: VLCStyle.spacing_12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Some changes apply after VLC restarts.")
                        color: theme.fg.highlight
                        font.pixelSize: VLCStyle.text_body
                    }

                    Widgets.DialogButton {
                        anchors.verticalCenter: parent.verticalCenter
                        height: VLCStyle.dp(28, VLCStyle.scale)
                        kind: Widgets.DialogButton.Primary
                        text: qsTr("Quit VLC")
                        onClicked: SettingsModel.quitForRestart()
                    }
                }
            }

            // --- confirmation

            Rectangle {
                id: confirmOverlay

                property bool open: false
                property string heading
                property string message
                property string actionText
                property var callback: null

                anchors.fill: parent
                radius: surface.radius
                color: theme.scrim

                visible: opacity > 0
                opacity: open ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: VLCStyle.duration_short }
                }

                onOpenChanged: if (open) cancelButton.forceActiveFocus(); else content.forceActiveFocus()

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: confirmOverlay.open = false
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: VLCStyle.dp(420, VLCStyle.scale)
                    height: confirmColumn.implicitHeight + VLCStyle.spacing_20 * 2
                    radius: VLCStyle.radius_xl
                    color: menuTheme.bg.primary

                    readonly property ColorContext _menu: ColorContext {
                        id: menuTheme
                        palette: VLCStyle.palette
                        colorSet: ColorContext.Menu
                    }

                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        id: confirmColumn

                        anchors.fill: parent
                        anchors.margins: VLCStyle.spacing_20
                        spacing: VLCStyle.spacing_12

                        Text {
                            Layout.fillWidth: true
                            text: confirmOverlay.heading
                            color: menuTheme.fg.heading
                            font.pixelSize: VLCStyle.text_heading
                            font.weight: VLCStyle.fontWeight_medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: confirmOverlay.message
                            color: menuTheme.fg.primary
                            font.pixelSize: VLCStyle.text_body
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            Layout.topMargin: VLCStyle.spacing_8
                            spacing: VLCStyle.spacing_8

                            Widgets.DialogButton {
                                id: cancelButton
                                text: qsTr("Cancel")
                                onClicked: confirmOverlay.open = false
                                KeyNavigation.right: confirmButton
                            }

                            Widgets.DialogButton {
                                id: confirmButton
                                kind: Widgets.DialogButton.Primary
                                text: confirmOverlay.actionText
                                onClicked: {
                                    confirmOverlay.open = false
                                    if (confirmOverlay.callback)
                                        confirmOverlay.callback()
                                }
                                KeyNavigation.left: cancelButton
                            }
                        }
                    }
                }
            }
        }
    }

    function stepPage(delta) {
        const next = Math.max(0, Math.min(pages.length - 1, currentPage + delta))
        if (next === currentPage)
            return
        openPage(next)
        Qt.callLater(() => nav.focusCurrent())
    }

    // --- pages (see pages/)

    Component { id: generalPage; General { } }
    Component { id: interfacePage; Interface { } }
    Component { id: privacyPage; Privacy { } }
    Component { id: controlsPage; Controls { } }
    Component { id: playbackPage; Playback { } }
    Component { id: videoPage; Video { } }
    Component { id: audioPage; Audio { } }
    Component { id: subtitlesPage; Subtitles { } }
    Component { id: libraryPage; Library { } }
    Component { id: networkPage; Network { } }
    Component { id: performancePage; Performance { } }
    Component { id: recordingPage; Recording { } }
    Component { id: extensionsPage; Extensions { } }
}
