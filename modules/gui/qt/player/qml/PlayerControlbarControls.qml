/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

pragma Singleton

import QtQml


import VLC.MainInterface
import VLC.PlayerControls
import VLC.Widgets as Widgets
import VLC.Style

QtObject {
    readonly property string controlPath : "qrc:///qt/qml/VLC/PlayerControls/"

    readonly property var controlList: [
        { id: ControlListModel.PLAY_BUTTON, file: "PlayButton.qml", label: VLCIcons.play_filled, text: qsTr("Play") , icon: "play" },
        { id: ControlListModel.STOP_BUTTON, file: "StopButton.qml", label: VLCIcons.stop, text: qsTr("Stop") , icon: "stop" },
        { id: ControlListModel.OPEN_BUTTON, file: "OpenButton.qml", label: VLCIcons.eject, text: qsTr("Open") },
        { id: ControlListModel.PREVIOUS_BUTTON, file: "PreviousButton.qml", label: VLCIcons.previous, text: qsTr("Previous") , icon: "previous" },
        { id: ControlListModel.NEXT_BUTTON, file: "NextButton.qml", label: VLCIcons.next, text: qsTr("Next") , icon: "next" },
        { id: ControlListModel.SLOWER_BUTTON, file: "SlowerButton.qml", label: VLCIcons.slower, text: qsTr("Slower") },
        { id: ControlListModel.FASTER_BUTTON, file: "FasterButton.qml", label: VLCIcons.faster, text: qsTr("Faster") },
        { id: ControlListModel.FULLSCREEN_BUTTON, file: "FullscreenButton.qml", label: VLCIcons.fullscreen, text: qsTr("Fullscreen") , icon: "fullscreen" },
        { id: ControlListModel.EXTENDED_BUTTON, file: "ExtendedSettingsButton.qml", label: VLCIcons.effect_filter, text: qsTr("Extended panel") , icon: "playback-settings" },
        { id: ControlListModel.PLAYLIST_BUTTON, file: "PlaylistButton.qml", label: VLCIcons.playlist, text: qsTr("Play Queue") , icon: "lists" },
        { id: ControlListModel.SNAPSHOT_BUTTON, file: "SnapshotButton.qml", label: VLCIcons.snapshot, text: qsTr("Snapshot") , icon: "snapshot" },
        { id: ControlListModel.RECORD_BUTTON, file: "RecordButton.qml", label: VLCIcons.record, text: qsTr("Record") , icon: "record" },
        { id: ControlListModel.ATOB_BUTTON, file: "AtoBButton.qml", label: VLCIcons.atob, text: qsTr("A-B Loop") },
        { id: ControlListModel.FRAME_PREV_BUTTON, file: "FrameNextButton.qml", label: VLCIcons.next_frame, text: qsTr("Next Frame") },
        { id: ControlListModel.FRAME_NEXT_BUTTON, file: "FramePrevButton.qml", label: VLCIcons.previous_frame, text: qsTr("Previous Frame") },
        { id: ControlListModel.REVERSE_BUTTON, file: "ReverseButton.qml", label: VLCIcons.play_reverse, text: qsTr("Trickplay Reverse") },
        { id: ControlListModel.SKIP_BACK_BUTTON, file: "SkipBackButton.qml", label: VLCIcons.skip_back, text: qsTr("Step backward") },
        { id: ControlListModel.SKIP_FW_BUTTON, file: "SkipForwardButton.qml", label: VLCIcons.skip_for, text: qsTr("Step forward") },
        { id: ControlListModel.QUIT_BUTTON, file: "QuitButton.qml", label: VLCIcons.clear, text: qsTr("Quit") , icon: "quit" },
        { id: ControlListModel.RANDOM_BUTTON, file: "RandomButton.qml", label: VLCIcons.shuffle, text: qsTr("Random") , icon: "shuffle-right" },
        { id: ControlListModel.LOOP_BUTTON, file: "LoopButton.qml", label: VLCIcons.repeat_all, text: qsTr("Loop") , icon: "repeat-right" },
        { id: ControlListModel.INFO_BUTTON, file: "InfoButton.qml", label: VLCIcons.info, text: qsTr("Information") , icon: "info" },
        { id: ControlListModel.LANG_BUTTON, file: "LangButton.qml", label: VLCIcons.audiosub, text: qsTr("Open subtitles") , icon: "subtitles" },
        { id: ControlListModel.BOOKMARK_BUTTON, file: "BookmarkButton.qml", label: VLCIcons.bookmark, text: qsTr("Bookmark Button") , icon: "bookmark" },
        { id: ControlListModel.CHAPTER_PREVIOUS_BUTTON, file: "ChapterPreviousButton.qml", label: VLCIcons.dvd_prev, text: qsTr("Previous chapter") },
        { id: ControlListModel.CHAPTER_NEXT_BUTTON, file: "ChapterNextButton.qml", label: VLCIcons.dvd_next, text: qsTr("Next chapter") },
        { id: ControlListModel.VOLUME, file: "VolumeWidget.qml", label: VLCIcons.volume_high, text: qsTr("Volume Widget") , icon: "volume-high" },
        { id: ControlListModel.NAVIGATION_BOX, file: "NavigationBoxButton.qml", label: VLCIcons.ic_fluent_arrow_move, text: qsTr("Navigation Box") },
        { id: ControlListModel.NAVIGATION_BUTTONS, file: "NavigationWidget.qml", label: VLCIcons.dvd_menu, text: qsTr("Navigation") },
        { id: ControlListModel.DVD_MENUS_BUTTON, file: "DvdMenuButton.qml", label: VLCIcons.dvd_menu, text: qsTr("DVD menus") },
        { id: ControlListModel.PROGRAM_BUTTON, file: "ProgramButton.qml", label: VLCIcons.tv, text: qsTr("Program Button") },
        { id: ControlListModel.TELETEXT_BUTTONS, file: "TeletextButton.qml", label: VLCIcons.tvtelx, text: qsTr("Teletext") },
        { id: ControlListModel.RENDERER_BUTTON, file: "RendererButton.qml", label: VLCIcons.renderer, text: qsTr("Renderer Button") },
        { id: ControlListModel.ASPECT_RATIO_COMBOBOX, file: "AspectRatioWidget.qml", label: VLCIcons.aspect_ratio, text: qsTr("Aspect Ratio") },
        { id: ControlListModel.WIDGET_SPACER, file: "SpacerWidget.qml", label: VLCIcons.space, text: qsTr("Spacer") , icon: "" },
        { id: ControlListModel.WIDGET_SPACER_EXTEND, file: "ExpandingSpacerWidget.qml", label: VLCIcons.space, text: qsTr("Expanding Spacer") , icon: "" },
        { id: ControlListModel.PLAYER_SWITCH_BUTTON, file: "PlayerSwitchButton.qml", label: VLCIcons.fullscreen, text: qsTr("Switch Player") },
        { id: ControlListModel.ARTWORK_INFO, file: "ArtworkInfoWidget.qml", label: VLCIcons.info, text: qsTr("Artwork Info") },
        { id: ControlListModel.PLAYBACK_SPEED_BUTTON, file: "PlaybackSpeedButton.qml", label: "1x", text: qsTr("Playback Speed") , icon: "speed" },
        { id: ControlListModel.HIGH_RESOLUTION_TIME_WIDGET, file: "HighResolutionTimeWidget.qml", label: VLCIcons.time, text: qsTr("High Resolution Time") },
        { id: ControlListModel.TIMELINE, file: "TimelineWidget.qml", label: "", text: qsTr("Seek bar"), icon: "" },
        { id: ControlListModel.JUMP_10_FWD_BUTTON, file: "Jump10FwdButton.qml", label: "", text: qsTr("Forward 10s"), icon: "forward-10-sec" },
        { id: ControlListModel.JUMP_10_BACK_BUTTON, file: "Jump10BackButton.qml", label: "", text: qsTr("Backward 10s"), icon: "backward-10-sec" },
        { id: ControlListModel.JUMP_15_FWD_BUTTON, file: "Jump15FwdButton.qml", label: "", text: qsTr("Forward 15s"), icon: "forward-15-sec" },
        { id: ControlListModel.JUMP_15_BACK_BUTTON, file: "Jump15BackButton.qml", label: "", text: qsTr("Backward 15s"), icon: "backward-15-sec" },
        { id: ControlListModel.REPLAY_BUTTON, file: "ReplayButton.qml", label: "", text: qsTr("Replay"), icon: "replay" },
        { id: ControlListModel.HDR_BUTTON, file: "HdrButton.qml", label: "", text: qsTr("HDR"), icon: "HDR" },
        { id: ControlListModel.PIP_BUTTON, file: "PipButton.qml", label: "", text: qsTr("Picture in Picture"), icon: "PiP" },
        { id: ControlListModel.ZOOM_BUTTON, file: "ZoomButton.qml", label: "", text: qsTr("Zoom"), icon: "zoom" },
        { id: ControlListModel.CHAPTERS_BUTTON, file: "ChaptersButton.qml", label: "", text: qsTr("Chapters"), icon: "chapters" },
        { id: ControlListModel.BOOKMARKS_LIST_BUTTON, file: "BookmarksListButton.qml", label: "", text: qsTr("Bookmarks"), icon: "bookmarks" },
        { id: ControlListModel.FAVORITE_BUTTON, file: "FavoriteButton.qml", label: "", text: qsTr("Favorite"), icon: "favorite" },
        { id: ControlListModel.PLAYLISTS_BUTTON, file: "PlaylistsButton.qml", label: "", text: qsTr("Playlists"), icon: "playlist" },
        { id: ControlListModel.SETTINGS_BUTTON, file: "SettingsButton.qml", label: "", text: qsTr("VLC Settings"), icon: "settings" },
        { id: ControlListModel.HOME_BUTTON, file: "HomeButton.qml", label: "", text: qsTr("Go Home"), icon: "home" },
        { id: ControlListModel.THUMBNAIL_WIDGET, file: "ThumbnailWidget.qml", label: "", text: qsTr("Thumbnail"), icon: "thumbnail" },
        { id: ControlListModel.FILE_NAME_WIDGET, file: "FileNameWidget.qml", label: "", text: qsTr("File Name"), icon: "info" },
        { id: ControlListModel.ARTIST_NAME_WIDGET, file: "ArtistNameWidget.qml", label: "", text: qsTr("Artist Name"), icon: "info" },
        { id: ControlListModel.FOLDER_NAME_WIDGET, file: "FolderNameWidget.qml", label: "", text: qsTr("Folder Name"), icon: "info" },
        { id: ControlListModel.PLAYLIST_NAME_WIDGET, file: "PlaylistNameWidget.qml", label: "", text: qsTr("Playlist Name"), icon: "info" },
        { id: ControlListModel.PROPERTIES_BUTTON, file: "PropertiesButton.qml", label: "", text: qsTr("Properties"), icon: "info" },
        { id: ControlListModel.DIVIDER_WIDGET, file: "DividerWidget.qml", label: "", text: qsTr("Divider"), icon: "divider" },
        { id: ControlListModel.RIGHT_SIDEBAR_BUTTON, file: "RightSidebarButton.qml", label: "", text: qsTr("Right Sidebar"), icon: "sidebar-right" },
        { id: ControlListModel.TITLE_MENU_BUTTON, file: "TitleMenuButton.qml", label: "", text: qsTr("Menu"), icon: "more" },
        { id: ControlListModel.TITLE_SIDEBAR_BUTTON, file: "TitleSidebarButton.qml", label: "", text: qsTr("Sidebar"), icon: "sidebar-left" },
        { id: ControlListModel.TITLE_BREADCRUMB_BUTTON, file: "TitleBreadcrumbButton.qml", label: "", text: qsTr("Back to library"), icon: "folder" },
        { id: ControlListModel.TITLE_TEXT_WIDGET, file: "TitleTextWidget.qml", label: "", text: qsTr("Title"), icon: "" },
        { id: ControlListModel.WINDOW_MINIMIZE_BUTTON, file: "WindowMinimizeButton.qml", label: "", text: qsTr("Minimize"), icon: "minimize" },
        { id: ControlListModel.WINDOW_MAXIMIZE_BUTTON, file: "WindowMaximizeButton.qml", label: "", text: qsTr("Maximize"), icon: "maximize" },
        { id: ControlListModel.WINDOW_CLOSE_BUTTON, file: "WindowCloseButton.qml", label: "", text: qsTr("Close"), icon: "close" },
        { id: ControlListModel.AUDIO_TRACKS_BUTTON, file: "AudioTracksButton.qml", label: "", text: qsTr("Audio tracks"), icon: "audio" },
        { id: ControlListModel.SUBTITLE_TRACKS_BUTTON, file: "SubtitleTracksButton.qml", label: "", text: qsTr("Subtitles"), icon: "subtitles" }
    ]

    // Space before an item of the control bar (Figma 491:1928): 8 inside the transport group,
    // 20 around the wide widgets (seek bar, volume, queue), 12 otherwise.
    // In the title bar (Figma 247:447) the cells already include their padding.
    function gap(titleBar, previousId, id) {
        if (previousId === undefined || previousId < 0)
            return 0

        if (titleBar)
            return (previousId === ControlListModel.TITLE_MENU_BUTTON) ? VLCStyle.spacing_10 : 0

        const transport = [ControlListModel.PREVIOUS_BUTTON, ControlListModel.PLAY_BUTTON, ControlListModel.NEXT_BUTTON,
                           ControlListModel.JUMP_15_BACK_BUTTON, ControlListModel.JUMP_15_FWD_BUTTON,
                           ControlListModel.JUMP_10_BACK_BUTTON, ControlListModel.JUMP_10_FWD_BUTTON]
        if (transport.indexOf(previousId) !== -1 && transport.indexOf(id) !== -1)
            return VLCStyle.spacing_8

        const wide = [ControlListModel.VOLUME, ControlListModel.TIMELINE, ControlListModel.PLAYLIST_BUTTON]
        if (wide.indexOf(previousId) !== -1 || wide.indexOf(id) !== -1)
            return VLCStyle.spacing_20

        return VLCStyle.spacing_12
    }

    function control(id) {
        const entry = controlList.find( function(e) { return ( e.id === id ) } )

        if (entry === undefined) {
            console.warn("control delegate id " + id +  " doesn't exist")
            return { source: controlPath + "Fallback.qml" }
        }

        entry.source = controlPath + entry.file

        return entry
    }
}
