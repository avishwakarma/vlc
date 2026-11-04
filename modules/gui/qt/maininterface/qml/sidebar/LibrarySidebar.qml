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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Network
import VLC.Playlist
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Util

// Library sidebar (Figma 848:1995): a 50 px icon rail and a 377 px panel that drills down into the
// library (Home, Videos, Music, Network, Playlists). It is backed by the media library models when
// the library is available; without it the panels show what VLC can still browse (folders, network
// sources, the play queue).
FocusScope {
    id: root

    // Properties

    // key of the section selected in the rail
    property string section: "home"

    // test/demo hook: function(descriptor) returning a Component that replaces the page of `descriptor`
    property var pageOverride: null

    readonly property bool mlAvailable: MainCtx.mediaLibraryAvailable

    // navigation state: descriptors of the pages of the stack, pages popped by "back" that can be restored
    property var descriptors: []
    property var forwardDescriptors: []

    // paths of the sections that were left, "back" restores them once the current path is at its root
    property var backDescriptors: []

    readonly property bool canGoBack: descriptors.length > 1 || backDescriptors.length > 0
    readonly property bool canGoForward: forwardDescriptors.length > 0

    // rows (default) or tiles, shared by all panels
    property bool gridView: String(MainCtx.settingValue("LibrarySidebar/grid-view", false)) === "true"

    onGridViewChanged: MainCtx.setSettingValue("LibrarySidebar/grid-view", gridView)

    // Signals

    // the "open in library" button: the library window shows the same section
    signal openLibraryRequested(var path)

    // Settings

    implicitWidth: VLCStyle.sidebarRail_w + VLCStyle.sidebarPanel_w

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Library sidebar")

    // Functions

    function showSection(key) {
        if (descriptors.length > 0 && !(descriptors.length === 1 && descriptors[0].kind === key))
            backDescriptors = [...backDescriptors, descriptors]

        _showSection(key)
    }

    function _showSection(key) {
        section = key
        forwardDescriptors = []

        const desc = _rootDescriptor(key)
        descriptors = [desc]
        if (stack.depth === 0)
            stack.push(_componentFor(desc), _properties(desc), T.StackView.Immediate)
        else
            stack.replace(null, _componentFor(desc), _properties(desc))
    }

    function push(kind, title, args) {
        _pushDescriptor({ kind: kind, title: title, args: args ?? {} })
        forwardDescriptors = []
    }

    function goBack() {
        if (!canGoBack)
            return

        // at the root of a section: return to the previously visited path
        if (descriptors.length <= 1) {
            const list = backDescriptors.slice()
            const previous = list.pop()
            backDescriptors = list

            _showSection(previous[0].kind)
            for (let i = 1; i < previous.length; ++i)
                _pushDescriptor(previous[i])
            return
        }

        const list = descriptors.slice()
        const last = list.pop()
        forwardDescriptors = [...forwardDescriptors, last]
        descriptors = list
        stack.pop()
    }

    function goForward() {
        if (!canGoForward)
            return

        const list = forwardDescriptors.slice()
        const desc = list.pop()
        _pushDescriptor(desc)
        forwardDescriptors = list
    }

    function openLibrary(path) {
        openLibraryRequested(path)
    }

    function setCurrentItemFocus(reason) {
        stack.forceActiveFocus(reason)
    }

    // Private

    // the pages that depend on the media library types, loaded on demand
    property var mlPages: null

    readonly property var _sectionTitles: ({
        "home": qsTr("Home"), "videos": qsTr("Videos"), "music": qsTr("Music"),
        "network": qsTr("Network"), "playlists": qsTr("Playlists"), "recent": qsTr("Recent")
    })

    // path of the library window matching a section
    readonly property var _libraryPaths: ({
        "home": ["home"], "videos": ["video"], "music": ["music"],
        "network": ["network"], "playlists": ["video", "playlists"], "recent": ["home"]
    })

    function _rootDescriptor(key) {
        return { kind: key, title: _sectionTitles[key] ?? key, args: {} }
    }

    function _pushDescriptor(desc) {
        descriptors = [...descriptors, desc]
        stack.push(_componentFor(desc), _properties(desc))
    }

    function _properties(desc) {
        return Object.assign({
            "nav": root,
            "crumbs": root.descriptors.map((d) => d.title),
            "libraryPath": root._libraryPaths[root.section] ?? ["home"]
        }, desc.args)
    }

    function _componentFor(desc) {
        if (pageOverride) {
            const override = pageOverride(desc)
            if (override)
                return override
        }

        const ml = mlAvailable && mlPages
        switch (desc.kind) {
        case "home": return ml ? mlPages.homePage : homePagePlain
        case "videos": return ml ? mlPages.videoFoldersPage : standardFolderPage
        case "videoFolder": return mlPages?.videoFolderPage ?? queuePage
        case "music": return ml ? mlPages.musicRootPage : standardFolderPage
        case "songs": return mlPages?.songsPage ?? queuePage
        case "albums": return mlPages?.albumsPage ?? queuePage
        case "albumTracks": return mlPages?.albumTracksPage ?? queuePage
        case "artists": return mlPages?.artistsPage ?? queuePage
        case "artistAlbums": return mlPages?.artistAlbumsPage ?? queuePage
        case "genres": return mlPages?.genresPage ?? queuePage
        case "genreAlbums": return mlPages?.artistAlbumsPage ?? queuePage
        case "network": return networkPage
        case "browse": return browsePage
        case "playlists": return ml ? mlPages.playlistsPage : queuePage
        case "playlistTracks": return mlPages?.playlistTracksPage ?? queuePage
        case "recent": return ml ? mlPages.recentPage : emptyRecentPage
        case "recentVideos": return mlPages?.recentPage ?? queuePage
        }
        return queuePage
    }

    // Children

    IconRail {
        id: rail

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left

        focus: true

        currentKey: root.section

        Navigation.parentItem: root
        Navigation.rightItem: stack

        onSectionRequested: (key) => root.showSection(key)
        onAddRequested: DialogsProvider.simpleOpenDialog()
    }

    // panel surface
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: rail.right
        anchors.right: parent.right

        color: theme.bg.primary
    }

    T.StackView {
        id: stack

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: rail.right
        anchors.right: parent.right

        clip: true

        Navigation.parentItem: root
        Navigation.leftItem: rail

        // panels slide in when drilling down and slide back when going back
        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: VLCStyle.dp(48, VLCStyle.scale); to: 0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long }
            }
        }
        pushExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 0; to: -VLCStyle.dp(48, VLCStyle.scale); duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_long }
            }
        }
        popEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: -VLCStyle.dp(48, VLCStyle.scale); to: 0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long }
            }
        }
        popExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 0; to: VLCStyle.dp(48, VLCStyle.scale); duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_long }
            }
        }
        replaceEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long }
        }
        replaceExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_short }
        }

        onCurrentItemChanged: {
            if (currentItem)
                currentItem.forceActiveFocus(Qt.OtherFocusReason)
        }
    }

    Component.onCompleted: {
        if (mlAvailable) {
            const component = Qt.createComponent("qrc:///qt/qml/VLC/MainInterface/MediaLibraryPages.qml")
            if (component.status === Component.Ready)
                mlPages = component.createObject(root)
            else
                console.warn("library sidebar:", component.errorString())
        }

        showSection(section)
    }

    // ---------------------------------------------------------------------------------------
    // Pages
    // ---------------------------------------------------------------------------------------

    // Home without the media library: the play queue
    Component {
        id: homePagePlain

        HomeSections {
            PlaylistListModel { id: queue; playlist: MainPlaylistController.playlist }

            sections: [
                { title: qsTr("Play Queue"), model: queue, limit: 8, thumbRole: "artwork", mrlRole: "url",
                  placeholderIcon: "video",
                  activate: (i, row) => MainPlaylistController.goTo(i, true),
                  seeAll: () => root.showSection("playlists") }
            ]
        }
    }

    // Network: add a stream, browse folders and the sources found on the network
    Component {
        id: networkPage

        HomeSections {
            id: networkHome

            StandardPathModel { id: folders }
            NetworkDeviceModel { id: lan; ctx: MainCtx; sd_source: NetworkDeviceModel.CAT_LAN; source_name: "*" }
            NetworkDeviceModel { id: internet; ctx: MainCtx; sd_source: NetworkDeviceModel.CAT_INTERNET; source_name: "*" }

            leadingActions: [ { text: qsTr("Add Network Stream"), icon: "add", action: () => DialogsProvider.openNetDialog() } ]

            moreEntries: [
                { text: qsTr("Add Network Stream"), icon: "streaming-twotone", action: () => DialogsProvider.openNetDialog() },
                { text: qsTr("Open Folder"), icon: "new-folder-twotone", action: () => DialogsProvider.PLOpenDir() }
            ]

            sections: [
                { title: qsTr("Folders"), model: folders, titleRole: "name", thumbRole: "artwork", limit: 8,
                  placeholderIcon: "folder",
                  activate: (i, row) => root.push("browse", row.name, { tree: row.tree }) },
                { title: qsTr("Computer and Network"), model: lan, titleRole: "name", thumbRole: "artwork", limit: 8,
                  placeholderIcon: "streaming",
                  activate: (i, row) => root.push("browse", row.name, { tree: row.tree }) },
                { title: qsTr("Podcasts and Radio"), model: internet, titleRole: "name", thumbRole: "artwork", limit: 8,
                  placeholderIcon: "streaming",
                  activate: (i, row) => root.push("browse", row.name, { tree: row.tree }) }
            ]
        }
    }

    // the content of a folder or of a network source
    Component {
        id: browsePage

        SidebarListPage {
            id: page

            property var tree

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "name" }, { text: qsTr("Url"), criteria: "mrl" } ]
            searchable: true
            viewOptions: true
            titleRole: "name"
            thumbRole: "artwork"
            mrlRole: "mrl"
            placeholderIcon: "folder"

            model: NetworkMediaModel {
                ctx: MainCtx
                tree: page.tree
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => {
                const type = row.type
                if (type === NetworkMediaModel.TYPE_DIRECTORY || type === NetworkMediaModel.TYPE_NODE
                        || type === NetworkMediaModel.TYPE_PLAYLIST)
                    root.push("browse", row.name, { tree: row.tree })
                else
                    model.addAndPlay(index)
            }
        }
    }

    // Videos/Music without the media library: the standard folders of the user
    Component {
        id: standardFolderPage

        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "name" } ]
            searchable: true
            viewOptions: true
            titleRole: "name"
            thumbRole: "artwork"
            placeholderIcon: "folder"
            leadingActions: [ { text: qsTr("Add"), icon: "add", action: () => DialogsProvider.simpleOpenDialog() } ]

            model: StandardPathModel {
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => root.push("browse", row.name, { tree: row.tree })
        }
    }

    // Playlists without the media library: the play queue
    Component {
        id: queuePage

        SidebarListPage {
            id: page

            rowsBright: true
            thumbRole: "artwork"
            subtitleRole: "artist"
            mrlRole: "url"
            placeholderIcon: "video"
            emptyText: qsTr("The play queue is empty")
            emptyIllustration: "queue"
            leadingActions: [ { text: qsTr("Add"), icon: "add", action: () => DialogsProvider.simpleOpenDialog() } ]

            moreEntries: [
                { text: qsTr("Add File"), icon: "add", action: () => DialogsProvider.simpleOpenDialog() },
                { text: qsTr("Play Folder..."), icon: "new-folder-twotone", action: () => DialogsProvider.PLOpenDir() },
                { text: qsTr("Save Playlist..."), icon: "save-twotone", action: () => DialogsProvider.savePlayingToPlaylist() },
                { text: qsTr("Clear"), icon: "remove", action: () => MainPlaylistController.clear() }
            ]

            model: PlaylistListModel { playlist: MainPlaylistController.playlist }

            onActivated: (index, row) => MainPlaylistController.goTo(index, true)
        }
    }

    Component {
        id: emptyRecentPage

        SidebarListPage {
            id: page

            emptyText: qsTr("Recent items need the media library")
            emptyIllustration: "video"
            model: ListModel {}
        }
    }
}
