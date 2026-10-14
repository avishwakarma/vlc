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
import VLC.Dialogs

// Panels of the library sidebar that need the media library types. The types only exist when the
// media library is available, so this file is loaded on demand by LibrarySidebar.
QtObject {

    // Home with the media library
    property Component homePage: Component {
        HomeSections {
            id: page

            MLRecentVideoModel { id: recentVideos; ml: MediaLib; limit: 3 }
            MLAudioModel { id: recentAudio; ml: MediaLib; limit: 3; sortCriteria: "insertion"; sortOrder: Qt.DescendingOrder }
            MLVideoFoldersModel { id: folders; ml: MediaLib; limit: 3 }
            MLPlaylistListModel { id: playlists; ml: MediaLib; limit: 3 }
            MLArtistModel { id: artists; ml: MediaLib; limit: 3 }

            sections: [
                { title: qsTr("Continue Watching"), model: recentVideos, thumbRole: "thumbnail", progressRole: "progress",
                  newRole: "isNew", mrlRole: "mrl", placeholderIcon: "video",
                  activate: (i, row) => MediaLib.addAndPlay(row.id), seeAll: () => page.nav.push("recentVideos", qsTr("Continue Watching")) },
                { title: qsTr("Listen Again"), model: recentAudio, thumbRole: "cover", subtitleRole: "main_artist",
                  mrlRole: "mrl", placeholderIcon: "songs",
                  activate: (i, row) => MediaLib.addAndPlay(row.id), seeAll: () => page.nav.push("songs", qsTr("Songs")) },
                { title: qsTr("Frequently Visited Folders"), model: folders, placeholderIcon: "folder",
                  activate: (i, row) => page.nav.push("videoFolder", row.title, { parentId: row.id }),
                  seeAll: () => page.nav.showSection("videos") },
                { title: qsTr("Frequently Visited Playlists"), model: playlists, titleRole: "name",
                  placeholderIcon: "playlist",
                  activate: (i, row) => page.nav.push("playlistTracks", row.name, { parentId: row.id }),
                  seeAll: () => page.nav.showSection("playlists") },
                { title: qsTr("Frequently Listened Artists"), model: artists, titleRole: "name",
                  placeholderIcon: "artist",
                  activate: (i, row) => page.nav.push("artistAlbums", row.name, { parentId: row.id }),
                  seeAll: () => page.nav.push("artists", qsTr("Artists")) }
            ]
        }
    }

    // Videos: the folders of the media library
    property Component videoFoldersPage: Component {
        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "title" }, { text: qsTr("Duration"), criteria: "duration" } ]
            searchable: true
            viewOptions: true
            placeholderIcon: "folder"
            leadingActions: [ { text: qsTr("Add"), icon: "add", action: () => DialogsProvider.PLOpenDir() } ]

            model: MLVideoFoldersModel {
                ml: MediaLib
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => page.nav.push("videoFolder", row.title, { parentId: row.id })
        }
    }

    // the videos of a folder
    property Component videoFolderPage: Component {
        SidebarListPage {
            id: page

            property var parentId

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "title" }, { text: qsTr("Duration"), criteria: "duration" } ]
            searchable: true
            viewOptions: true
            thumbRole: "thumbnail"
            progressRole: "progress"
            newRole: "isNew"
            mrlRole: "mrl"
            placeholderIcon: "video"
            contextMenu: fileMenu

            model: MLVideoModel {
                ml: MediaLib
                parentId: page.parentId
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            MLContextMenu { id: fileMenu; model: page.model; showPlayAsAudioAction: true }

            onActivated: (index, row) => MediaLib.addAndPlay(row.id)
        }
    }

    // Music: the entries of the music library
    property Component musicRootPage: Component {
        SidebarListPage {
            id: page

            placeholderIcon: "songs"
            itemCount: 4
            leadingActions: [ { text: qsTr("Add"), icon: "add", action: () => DialogsProvider.PLOpenDir() } ]

            model: ListModel {
                ListElement { title: qsTr("Songs"); kind: "songs"; icon: "songs" }
                ListElement { title: qsTr("Albums"); kind: "albums"; icon: "album" }
                ListElement { title: qsTr("Artists"); kind: "artists"; icon: "artist" }
                ListElement { title: qsTr("Genres"); kind: "genres"; icon: "genre" }
            }

            onActivated: (index, row) => {
                const kinds = ["songs", "albums", "artists", "genres"]
                page.nav.push(kinds[index], row.title)
            }
        }
    }

    property Component songsPage: Component {
        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "title" }, { text: qsTr("Album"), criteria: "album_title" },
                         { text: qsTr("Artist"), criteria: "main_artist" }, { text: qsTr("Duration"), criteria: "duration" } ]
            searchable: true
            viewOptions: true
            thumbRole: "cover"
            subtitleRole: "main_artist"
            mrlRole: "mrl"
            placeholderIcon: "songs"
            contextMenu: fileMenu

            model: MLAudioModel {
                ml: MediaLib
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            MLContextMenu { id: fileMenu; model: page.model }

            onActivated: (index, row) => MediaLib.addAndPlay(row.id)
        }
    }

    property Component albumsPage: Component {
        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "title" }, { text: qsTr("Artist"), criteria: "main_artist" },
                         { text: qsTr("Release Year"), criteria: "release_year" } ]
            searchable: true
            viewOptions: true
            thumbRole: "cover"
            subtitleRole: "main_artist"
            placeholderIcon: "album"

            model: MLAlbumModel {
                ml: MediaLib
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => page.nav.push("albumTracks", row.title, { parentId: row.id })
        }
    }

    property Component albumTracksPage: Component {
        SidebarListPage {
            id: page

            property var parentId

            searchable: true
            thumbRole: "cover"
            subtitleRole: "main_artist"
            mrlRole: "mrl"
            placeholderIcon: "songs"
            contextMenu: fileMenu

            model: MLAudioModel {
                ml: MediaLib
                parentId: page.parentId
                searchPattern: page.searchPattern
            }

            MLContextMenu { id: fileMenu; model: page.model }

            onActivated: (index, row) => MediaLib.addAndPlay(row.id)
        }
    }

    property Component artistsPage: Component {
        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "name" } ]
            searchable: true
            viewOptions: true
            titleRole: "name"
            placeholderIcon: "artist"

            model: MLArtistModel {
                ml: MediaLib
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => page.nav.push("artistAlbums", row.name, { parentId: row.id })
        }
    }

    // the albums of an artist or of a genre
    property Component artistAlbumsPage: Component {
        SidebarListPage {
            id: page

            property var parentId

            searchable: true
            viewOptions: true
            thumbRole: "cover"
            placeholderIcon: "album"

            model: MLAlbumModel {
                ml: MediaLib
                parentId: page.parentId
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => page.nav.push("albumTracks", row.title, { parentId: row.id })
        }
    }

    property Component genresPage: Component {
        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "name" } ]
            searchable: true
            titleRole: "name"
            thumbRole: "cover"
            placeholderIcon: "genre"

            model: MLGenreModel {
                ml: MediaLib
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => page.nav.push("genreAlbums", row.name, { parentId: row.id })
        }
    }

    // Playlists of the media library
    property Component playlistsPage: Component {
        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "title" }, { text: qsTr("Duration"), criteria: "duration" } ]
            searchable: true
            viewOptions: true
            titleRole: "name"
            rowsBright: true
            placeholderIcon: "playlist"
            leadingActions: [ { text: qsTr("Create playlist"), icon: "add", action: () => createPlaylistDialog() } ]

            function createPlaylistDialog() {
                const name = DialogsProvider.getTextDialog(null, qsTr("Create playlist"), qsTr("Name"), qsTr("New playlist"))
                if (name)
                    model.create(name, [])
            }

            model: MLPlaylistListModel {
                ml: MediaLib
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            onActivated: (index, row) => page.nav.push("playlistTracks", row.name, { parentId: row.id })
        }
    }

    property Component playlistTracksPage: Component {
        SidebarListPage {
            id: page

            property var parentId

            searchable: true
            thumbRole: "small_cover"
            mrlRole: "mrl"
            placeholderIcon: "video"
            contextMenu: fileMenu

            moreEntries: [
                { text: qsTr("Play"), icon: "playback-twotone", action: () => MediaLib.addAndPlay(parentId) },
                { text: qsTr("Add to Queue"), icon: "queue-twotone", action: () => MediaLib.addToPlaylist(parentId) }
            ]

            model: MLPlaylistModel {
                ml: MediaLib
                parentId: page.parentId
                searchPattern: page.searchPattern
            }

            MLContextMenu { id: fileMenu; model: page.model }

            onActivated: (index, row) => MediaLib.addAndPlay(row.id)
        }
    }

    // recent videos of the media library ("Continue Watching")
    property Component recentPage: Component {
        SidebarListPage {
            id: page

            sortModel: [ { text: qsTr("Alphabetic"), criteria: "title" }, { text: qsTr("Duration"), criteria: "duration" } ]
            searchable: true
            viewOptions: true
            thumbRole: "thumbnail"
            progressRole: "progress"
            newRole: "isNew"
            mrlRole: "mrl"
            placeholderIcon: "video"
            contextMenu: fileMenu

            model: MLRecentVideoModel {
                ml: MediaLib
                sortCriteria: page.sortCriteria
                sortOrder: page.sortOrder
                searchPattern: page.searchPattern
            }

            MLContextMenu { id: fileMenu; model: page.model; showPlayAsAudioAction: true }

            onActivated: (index, row) => MediaLib.addAndPlay(row.id)
        }
    }
}
