/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
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
import QtQml.Models

import VLC.Style
import VLC.Widgets as Widgets

import VLC.MainInterface
import VLC.Dialogs
import VLC.Menus as Menus
import VLC.Util

T.Pane {
    id: root

    signal itemClicked(uri : var, item : Item)

    //safe area margins for delegate content,
    //so the background of the delegates fills the available space
    //but the content remains within the safe area
    property int safeAreaLeftMargin: 0
    property int safeAreaRightMargin: 0

    property bool useAcrylic: true

    property bool delegateShowText: true

    property alias model: navigationModel

    // Figma navigation card (970:2703): 201px card + 8px inset
    readonly property int minimumWidth: VLCStyle.dp(209, VLCStyle.scale) + safeAreaLeftMargin + safeAreaRightMargin

    // Figma icon (pixmaps/svg_icons) of a navigation entry, empty when there is none
    function svgIcon(uri, depth, selected) {
        if (!uri || uri.length === 0)
            return ""

        if (depth === 0) {
            switch (uri[0]) {
            case "home": return selected ? "home-selected" : "home"
            case "video": return selected ? "videos-selected" : "videos"
            case "music": return selected ? "songs-selected" : "songs"
            case "network": return selected ? "streaming-selected" : "streaming"
            case "discover": return selected ? "link-active" : "link"
            }
            return ""
        }

        switch (uri[uri.length - 1]) {
        case "playlists": return "playlist"
        case "albums": return "album"
        case "artists": return "artist"
        case "genres": return "genre"
        case "tracks": return "songs"
        }
        return "folder"
    }

    // Figma labels of the top level entries
    function label(title, uri, depth) {
        if (depth === 0 && uri && uri.length > 0) {
            switch (uri[0]) {
            case "video": return qsTr("Videos")
            case "network": return qsTr("Network")
            }
        }
        return title
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: VLCStyle.margin_normal

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    ColorContext {
        id: cardTheme
        colorSet: ColorContext.Pane
    }

    Accessible.name: qsTr("Sidebar")

    NavigationModel {
        id: navigationModel
        hasMedialib: MainCtx.mediaLibraryAvailable
    }

    Connections {
        target: History

        // NOTE: handles cases where the path changes not by clicking in the sidebar
        function onViewPathChanged(viewPath) {
            for (let i = 0; i < listView.count; ++i) {
                const rowIndex = navigationModel.index(i, 0)
                const uri = navigationModel.data(rowIndex, NavigationModel.URI)

                if (uri && History.match(viewPath, uri)) {
                    // handle back button
                    listView.currentIndex = i

                    // handle keyboard navigation
                    if (!navigationModel.data(rowIndex, NavigationModel.EXPANDED))
                        navigationModel.setData(rowIndex, true, NavigationModel.EXPANDED)

                    return
                }
            }
        }
    }

    // the card floats over the window, nothing is drawn behind it
    background: Rectangle {
        color: "transparent"
    }

    contentItem:  Item {
        id: contentItemId

        // navigation card (Pane secondary, radius 10, 8px inset)
        Rectangle {
            id: card

            anchors.fill: parent
            anchors.leftMargin: VLCStyle.spacing_8 + root.safeAreaLeftMargin
            anchors.topMargin: VLCStyle.spacing_8
            anchors.bottomMargin: VLCStyle.spacing_8

            radius: VLCStyle.radius_l
            color: cardTheme.bg.secondary
        }

        //don't use Layout as top item as items put as children of the Control
        //would be parented (and layouted) to the Layout
        ColumnLayout {
            anchors.fill: card
            anchors.margins: VLCStyle.spacing_8
            anchors.topMargin: VLCStyle.spacing_4
            spacing: 0

            Widgets.ListViewExt {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: contentHeight
                Layout.maximumHeight: parent.height

                clip: !fadingEdge.implicitClipping && (height < contentHeight)
                focus: true

                model: navigationModel

                Binding {
                    target: listView.T.ScrollBar.vertical
                    property: "policy"
                    when: listView.T.ScrollBar.vertical?.size > (1.0 - Number.EPSILON)
                    value: T.ScrollBar.AlwaysOff
                }

                colorContext.colorSet: ColorContext.Window

                fadingEdge.backgroundColor: cardTheme.bg.secondary

                component DelegateAnimation : NumberAnimation {
                    easing.type: Easing.InOutSine
                    duration: VLCStyle.duration_long
                }

                reuseItems: false // Not relevant here, we disable it because of QTBUG-131106 when transition is involved.

                // As the docs note, `ListView` transitions do not seem to handle height animation. For that reason,
                // we animate the height directly in the delegate (Qt's recommended workaround). Because of this, we
                // do not need to have `addDisplaced` transition here, but we can have `removeDisplaced` here:
                removeDisplaced: Transition {
                    DelegateAnimation { property: "y" }
                }

                onCurrentIndexChanged: {
                    const rowIndex = navigationModel.index(currentIndex, 0)

                    if (rowIndex.valid && !navigationModel.data(rowIndex, NavigationModel.EXPANDED)
                            && History.match(History.viewPath, navigationModel.data(rowIndex, NavigationModel.URI)))
                        navigationModel.setData(rowIndex, true, NavigationModel.EXPANDED)
                }

                property bool readyForAnimations: false

                onModelChanged: {
                    if (!listView.readyForAnimations)
                        Qt.callLater(() => { listView.readyForAnimations = true })
                }

                Navigation.parentItem: root
                Navigation.downItem: preferenceButton

                delegate: SideNavigationDelegate {
                    id: delegate

                    width: ListView.view.contentWidth
                    height: preferredHeight

                    property real preferredHeight: shouldShow ? VLCStyle.dp(46, VLCStyle.scale) : 0.0

                    leftPadding: VLCStyle.spacing_10 + (depth > 0 ? VLCStyle.spacing_20 : 0)
                    rightPadding: VLCStyle.spacing_8

                    leftInset: 0
                    rightInset: 0
                    topInset: VLCStyle.spacing_2
                    bottomInset: VLCStyle.spacing_2

                    radius: VLCStyle.radius_m

                    iconTxt: icon_alias
                    iconName: root.svgIcon(uri, depth, false)
                    iconNameSelected: root.svgIcon(uri, depth, true)
                    text: root.label(title, uri, depth)

                    showText: root.delegateShowText

                    required property string title
                    required property var uri
                    required property int depth
                    // TODO: Qt 6.2 has property `icon` marked final, so we can't override it:
                    required property string icon_alias
                    required property bool expandable
                    required property bool expanded

                    required property int index

                    visible: (height > 0.0)

                    property bool shouldShow: showText || (iconTxt.length > 0)

                    onShouldShowChanged: {
                        if (listView.readyForAnimations)
                            heightBehavior.enabled = true // At this point, it can keep being enabled for good.
                    }

                    Binding on highlighted {
                        when: !!uri && History.match(History.viewPath, uri)
                        value: true
                    }
                    checked: (!showText || !expanded) && highlighted

                    onClicked: {
                        itemClicked(uri, this)
                        listView.currentIndex = index
                        listView.forceActiveFocus(focusReason)
                    }

                    Behavior on height {
                        id: heightBehavior

                        enabled: false

                        DelegateAnimation {
                            onRunningChanged: {
                                if (running) {
                                    delegate.clip = true
                                } else {
                                    delegate.clip = false
                                }
                            }
                        }
                    }

                    ListView.onAdd: {
                        if (listView.readyForAnimations && delegate.showText) {
                            heightBehavior.enabled = false
                            delegate.height = 0.0
                            heightBehavior.enabled = true
                            delegate.height = Qt.binding(() => delegate.preferredHeight)
                            heightBehavior.enabled = false
                        }
                    }
                }
            }

            Loader {
                id: loaderProgress

                Layout.fillWidth: true

                active: (MainCtx.mediaLibraryAvailable && MainCtx.mediaLibrary.idle === false)
                visible: active

                source: "qrc:///qt/qml/VLC/MediaLibrary/ScanProgressBar.qml"

                onLoaded: {
                    if (item.background) {
                        item.background.opacity = 0.6
                        item.background.radius = Qt.binding(() => VLCStyle.dp(4, VLCStyle.scale))
                    }

                    item.leftPadding = Qt.binding(function() { return root.safeAreaLeftMargin + VLCStyle.margin_small })
                    item.rightPadding = Qt.binding(function() { return root.safeAreaRightMargin + VLCStyle.margin_small })

                    item.leftInset = Qt.binding(() => { return VLCStyle.margin_xxsmall + root.safeAreaLeftMargin })
                    item.rightInset = Qt.binding(() => { return VLCStyle.margin_xxsmall + root.safeAreaRightMargin })
                }
            }

            SideNavigationDelegate {
                id: preferenceButton

                AccessibleCompat.id: "addItemButton"

                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(46, VLCStyle.scale)

                leftPadding: VLCStyle.spacing_10
                rightPadding: VLCStyle.spacing_8

                leftInset: 0
                rightInset: 0
                topInset: VLCStyle.spacing_2
                bottomInset: VLCStyle.spacing_2

                radius: VLCStyle.radius_m
                iconName: "add"
                text: qsTr("Add Item")

                showText: root.delegateShowText

                onClicked: DialogsProvider.simpleOpenDialog()

                //SideNavigationDelegate is an ItemDelegate and has NoFocus by default
                focusPolicy: Qt.StrongFocus

                Navigation.parentItem: root
                Navigation.upItem: listView

                Keys.priority: Keys.AfterItem
                Keys.onPressed: (e) => Navigation.defaultKeyAction(e)
                Keys.onReleased: (e) => Navigation.defaultKeyReleaseAction(e)
            }

            // keeps the entries at the top of the card
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // pinned to the bottom of the card: Settings and the main menu
            component FooterButton: SideNavigationDelegate {
                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(46, VLCStyle.scale)

                leftPadding: VLCStyle.spacing_10
                rightPadding: VLCStyle.spacing_8

                leftInset: 0
                rightInset: 0
                topInset: VLCStyle.spacing_2
                bottomInset: VLCStyle.spacing_2

                radius: VLCStyle.radius_m

                showText: root.delegateShowText

                focusPolicy: Qt.StrongFocus

                Navigation.parentItem: root

                Keys.priority: Keys.AfterItem
                Keys.onPressed: (e) => Navigation.defaultKeyAction(e)
                Keys.onReleased: (e) => Navigation.defaultKeyReleaseAction(e)
            }

            FooterButton {
                id: settingsButton

                iconName: "settings"
                text: qsTr("Settings")

                Navigation.upItem: preferenceButton
                Navigation.downItem: moreButton

                onClicked: DialogsProvider.prefsDialog()
            }

            FooterButton {
                id: moreButton

                iconName: "more"
                text: qsTr("More")

                Navigation.upItem: settingsButton

                onClicked: mainMenu.popup(moreButton.mapToGlobal(moreButton.width, 0))
            }
        }
    }

    // the main menu of the title bar ("...")
    Menus.QmlGlobalMenu {
        id: mainMenu

        ctx: MainCtx
    }
}
