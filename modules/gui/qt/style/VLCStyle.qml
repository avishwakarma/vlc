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
import QtQuick

import VLC.MainInterface
import VLC.Style

QtObject {
    id: vlc_style

    readonly property real scale: MainCtx.intfScaleFactor

    // Legacy font-size names are aliases of the single redesign text scale (text_* below):
    //   xxsmall/xsmall/small -> text_caption 12, normal/large -> text_body 14, xlarge -> text_heading 16,
    //   xxlarge -> text_subtitle 20, xxxlarge -> text_title 24.
    // New code uses text_* directly; fontSize_* / fontMetrics_* stay for files owned by other batches.
    readonly property FontMetrics fontMetrics_xxsmall  : FontMetrics { font.pixelSize: vlc_style.text_caption }
    readonly property FontMetrics fontMetrics_xsmall   : FontMetrics { font.pixelSize: vlc_style.text_caption }
    readonly property FontMetrics fontMetrics_small    : FontMetrics { font.pixelSize: vlc_style.text_caption }
    readonly property FontMetrics fontMetrics_normal   : FontMetrics { font.pixelSize: vlc_style.text_body }
    readonly property FontMetrics fontMetrics_large    : FontMetrics { font.pixelSize: vlc_style.text_body }
    readonly property FontMetrics fontMetrics_xlarge   : FontMetrics { font.pixelSize: vlc_style.text_heading }
    readonly property FontMetrics fontMetrics_xxlarge  : FontMetrics { font.pixelSize: vlc_style.text_subtitle }
    readonly property FontMetrics fontMetrics_xxxlarge : FontMetrics { font.pixelSize: vlc_style.text_title }

    readonly property SystemPalette palette:  SystemPalette {
        objectName: "themePalette"
        source: MainCtx.colorScheme.scheme
        ctx: MainCtx
    }

    readonly property SystemPalette darkPalette: SystemPalette {
        objectName: "darkPalette"
        source: ColorSchemeModel.Night
        ctx: MainCtx
    }

    readonly property real highPixelDensityThreshold: 5.9 // 150 dpi (dpmm)

    // Sizes
    readonly property double margin_xxxsmall: MainCtx.dp(2, scale);
    readonly property double margin_xxsmall: MainCtx.dp(4, scale);
    readonly property double margin_xsmall: MainCtx.dp(8, scale);
    readonly property double margin_small: MainCtx.dp(12, scale);
    readonly property double margin_normal: MainCtx.dp(16, scale);
    readonly property double margin_large: MainCtx.dp(24, scale);
    readonly property double margin_xlarge: MainCtx.dp(32, scale);
    readonly property double margin_xxlarge: MainCtx.dp(36, scale);

    readonly property real resizeHandleWidth: (scrollBarInteractingSize / 2)

    readonly property real touchHandlerMargin: margin_large

    // Borders
    readonly property int border: MainCtx.dp(1, scale)
    readonly property int focus_border: border
    readonly property int focusRing_width: MainCtx.dp(2, scale)

    readonly property int fontSize_xsmall: fontMetrics_xsmall.font.pixelSize
    readonly property int fontSize_small:  fontMetrics_small.font.pixelSize
    readonly property int fontSize_normal: fontMetrics_normal.font.pixelSize
    readonly property int fontSize_large:  fontMetrics_large.font.pixelSize
    readonly property int fontSize_xlarge: fontMetrics_xlarge.font.pixelSize
    readonly property int fontSize_xxlarge: fontMetrics_xxlarge.font.pixelSize
    readonly property int fontSize_xxxlarge: fontMetrics_xxxlarge.font.pixelSize

    readonly property int fontHeight_xsmall: Math.ceil(fontMetrics_xsmall.lineSpacing)
    readonly property int fontHeight_small:  Math.ceil(fontMetrics_small.lineSpacing)
    readonly property int fontHeight_normal: Math.ceil(fontMetrics_normal.lineSpacing)
    readonly property int fontHeight_large:  Math.ceil(fontMetrics_large.lineSpacing)
    readonly property int fontHeight_xlarge: Math.ceil(fontMetrics_xlarge.lineSpacing)
    readonly property int fontHeight_xxlarge: Math.ceil(fontMetrics_xxlarge.lineSpacing)
    readonly property int fontHeight_xxxlarge: Math.ceil(fontMetrics_xxxlarge.lineSpacing)


    readonly property int heightAlbumCover_xsmall: MainCtx.dp(32, scale);
    readonly property int heightAlbumCover_small: MainCtx.dp(64, scale);
    readonly property int heightAlbumCover_normal: MainCtx.dp(128, scale);
    readonly property int heightAlbumCover_large: MainCtx.dp(255, scale);
    readonly property int heightAlbumCover_xlarge: MainCtx.dp(512, scale);

    readonly property int listAlbumCover_height: MainCtx.dp(36, scale)
    readonly property int listAlbumCover_width: listAlbumCover_height * 16.0/9
    readonly property int listAlbumCover_radius: MainCtx.dp(6, scale)
    readonly property int trackListAlbumCover_width: MainCtx.dp(32, scale)
    readonly property int trackListAlbumCover_heigth: MainCtx.dp(32, scale)
    readonly property int trackListAlbumCover_radius: MainCtx.dp(3, scale)

    readonly property int tableCoverRow_height: Math.max(listAlbumCover_height, fontHeight_normal) + spacing_10 * 2
    readonly property int tableRow_height: fontHeight_normal + margin_small * 2

    readonly property int icon_xsmall: MainCtx.dp(8, scale);
    readonly property int icon_small: MainCtx.dp(12, scale);
    readonly property int icon_normal: MainCtx.dp(24, scale);
    readonly property int icon_medium: MainCtx.dp(48, scale);
    readonly property int icon_large: MainCtx.dp(64, scale);
    readonly property int icon_xlarge: MainCtx.dp(128, scale);

    readonly property int icon_dragItem: MainCtx.dp(32, scale);
    readonly property int icon_topbar: icon_normal
    readonly property int icon_toolbar: icon_normal
    readonly property int icon_audioPlayerButton: MainCtx.dp(32, scale)
    readonly property int icon_playlist: icon_normal
    readonly property int icon_track: icon_normal
    readonly property int icon_tableHeader: icon_normal
    readonly property int icon_playlistHeader: icon_normal
    readonly property int icon_banner: MainCtx.dp(28, scale)
    readonly property int icon_play: MainCtx.dp(28, scale)
    readonly property int icon_addressBar: icon_normal
    readonly property int icon_actionButton: icon_normal
    readonly property int icon_PIP: icon_normal
    readonly property int icon_CSD: icon_small
    readonly property int icon_playlistArt: MainCtx.dp(40, scale)

    readonly property int play_cover_small: MainCtx.dp(24, scale)
    readonly property int play_cover_normal: MainCtx.dp(48, scale)

    readonly property int cover_xxsmall: MainCtx.dp(32, scale);
    readonly property int cover_xsmall: MainCtx.dp(64, scale);
    readonly property int cover_small: MainCtx.dp(96, scale);
    readonly property int cover_normal: MainCtx.dp(128, scale);
    readonly property int cover_large: MainCtx.dp(160, scale);
    readonly property int cover_xlarge: MainCtx.dp(192, scale);

    readonly property int heightBar_xxxsmall: MainCtx.dp(2, scale);
    readonly property int heightBar_xxsmall: MainCtx.dp(4, scale);
    readonly property int heightBar_xsmall: MainCtx.dp(8, scale);
    readonly property int heightBar_small: MainCtx.dp(16, scale);
    readonly property int heightBar_normal: MainCtx.dp(32, scale);
    readonly property int heightBar_medium: MainCtx.dp(48, scale);
    readonly property int heightBar_large: MainCtx.dp(64, scale);
    readonly property int heightBar_xlarge: MainCtx.dp(128, scale);
    readonly property int heightBar_xxlarge: MainCtx.dp(256, scale);

    readonly property int minWindowWidth: MainCtx.dp(500, scale);
    readonly property int maxWidthPlaylist: MainCtx.dp(400, scale);
    readonly property int defaultWidthPlaylist: MainCtx.dp(300, scale);
    readonly property int closedWidthPlaylist: MainCtx.dp(20, scale);

    readonly property int expandNavigationPaneWidth: MainCtx.dp(160, scale);
    readonly property int buttonHeightNavigationPane: MainCtx.dp(35, scale);

    readonly property int widthSearchInput: MainCtx.dp(200, scale);
    readonly property int widthSortBox: MainCtx.dp(150, scale);
    readonly property int widthTeletext: MainCtx.dp(280, scale);
    readonly property int widthExtendedSpacer: MainCtx.dp(128, scale);
    readonly property int heightInput: MainCtx.dp(22, scale);

    readonly property real network_normal: MainCtx.dp(100, scale)

    readonly property int expandAlbumTracksHeight: MainCtx.dp(200, scale)

    //combobox
    readonly property int combobox_width_small: MainCtx.dp(64, scale)
    readonly property int combobox_width_normal: MainCtx.dp(96, scale)
    readonly property int combobox_width_large: MainCtx.dp(128, scale)

    readonly property int combobox_height_small: MainCtx.dp(16, scale)
    readonly property int combobox_height_normal: MainCtx.dp(24, scale)
    readonly property int combobox_height_large: MainCtx.dp(30, scale)

    //button
    readonly property int button_width_small: MainCtx.dp(64, scale)
    readonly property int button_width_normal: MainCtx.dp(96, scale)
    readonly property int button_width_large: MainCtx.dp(128, scale)

    readonly property real button_radius: MainCtx.dp(4, scale)

    readonly property int contextButton_width: icon_normal
    readonly property int contextButton_margin: margin_xxsmall

    readonly property int checkButton_width: MainCtx.dp(56, scale)
    readonly property int checkButton_height: MainCtx.dp(32, scale)

    readonly property int checkButton_margins: MainCtx.dp(4, scale)
    readonly property int checkButton_handle_margins: MainCtx.dp(2, scale)

    readonly property int navBoxButton_radius: radius_m

    readonly property int table_section_width: MainCtx.dp(32, scale)
    readonly property int table_section_text_margin: MainCtx.dp(10, scale)

    readonly property int gridCover_network_width: colWidth(1)
    readonly property int gridCover_network_height: gridCover_network_width
    readonly property int gridCover_network_border: MainCtx.dp(3, scale)

    readonly property int gridCover_music_width: colWidth(1)
    readonly property int gridCover_music_height: gridCover_music_width
    readonly property int gridCover_music_border: MainCtx.dp(3, scale)

    // Figma library grid: 316x178 thumbnails
    readonly property int gridCover_video_width: MainCtx.dp(316, scale)
    readonly property int gridCover_video_minWidth: MainCtx.dp(296, scale)
    readonly property int gridCover_video_height: ( gridCover_video_width * 9.0 ) / 16
    readonly property int gridCover_video_border: MainCtx.dp(4, scale)

    readonly property int gridCover_radius: radius_l

    readonly property int expandCover_music_height: MainCtx.dp(171, scale)
    readonly property int expandCover_music_width: MainCtx.dp(171, scale)
    readonly property int expandCover_music_radius: gridCover_radius
    readonly property int expandDelegate_border: MainCtx.dp(1, scale)

    readonly property int artistGridCover_radius: MainCtx.dp(90, scale)

    readonly property real mainView_topLeftRadius: MainCtx.dp(8, scale)

    //GridItem
    readonly property int gridItemTitle_topMargin: margin_xsmall + margin_xxxsmall
    readonly property int gridItemTitle_height: fontHeight_normal

    readonly property int gridItemSubtitle_topMargin: margin_xsmall - margin_xxxsmall
    readonly property int gridItemSubtitle_height: fontHeight_normal

    readonly property int gridItemSelectedBorder: MainCtx.dp(8, scale)

    readonly property int gridItem_newIndicator: MainCtx.dp(8, scale)

    readonly property int column_width: MainCtx.dp(114, scale)

    // NOTE: This property should be applied on ExpandGridView and TableView. We should provision
    //       enough space to fit the TableView section labels and 'contextButton'.
    readonly property int column_margin: MainCtx.dp(32, scale)
    readonly property int column_spacing: column_margin

    // NOTE: For the grid layout, there is an additional spacing, defined by the verticalSpacing of the ExpandGridView
    readonly property int gridView_spacing: margin_small + margin_xxxsmall
    readonly property int tableView_spacing: gridView_spacing + margin_large

    readonly property int layoutTitle_top_padding: margin_large
    readonly property int layoutTitle_bottom_padding: margin_normal + margin_xxxsmall

    readonly property int layout_left_margin: margin_normal
    readonly property int layout_right_margin: layout_left_margin

    readonly property int table_cover_border: MainCtx.dp(2, scale)

    readonly property int tableHeaderText_height: fontHeight_normal

    readonly property int artistBanner_height: MainCtx.dp(200, scale)

    //global application size, updated by the root widget
    property int appWidth: 0
    property int appHeight: 0

    readonly property int smallWidth: MainCtx.dp(600, scale)
    readonly property int mediumWidth: MainCtx.dp(1000, scale)

    readonly property bool isScreenSmall: appWidth <= smallWidth
    readonly property bool isScreenReallySmall: appWidth <= MainCtx.dp(380, scale)

    //global application margin "safe area"
    readonly property int applicationHorizontalMargin: MainCtx.safeArea * appWidth / 100
    readonly property int applicationVerticalMargin: MainCtx.safeArea * appHeight / 100

    readonly property int globalToolbar_height: MainCtx.dp(40, scale)
    readonly property int localToolbar_height: MainCtx.dp(48, scale)

    readonly property int bannerTabButton_width_small: icon_banner
    readonly property int bannerTabButton_width_large: column_width

    readonly property int bannerButton_height: icon_banner
    readonly property int bannerButton_width: icon_banner

    // Drag and drop

    readonly property int dragDelta: MainCtx.dp(12, scale)

    // durations. Values are aligned on Kirigami

    //should be used for animation that benefits from a longer animation than duration_long
    readonly property int duration_veryLong: 400

    //should be used for longer animation (opening/closing panes & dialogs)
    readonly property int duration_long: 200

    //should be used for short animations (hovering, accuenting UI event)
    readonly property int duration_short: 100

    //should be used for near instant animations
    readonly property int duration_veryShort: 50

    /* human time reaction, how much time before the user should be informed that something
     * is going on, or before something should be automatically automated,
     * this should not be used for animations
     *
     * Some examples:
     *
     * - When the user types text in a search field, wait no longer than this duration after
     *   the user completes typing before starting the search
     * - When loading data which would commonly arrive rapidly enough to not require interaction,
     *   wait this long before showing a spinner
     */
    readonly property int duration_humanMoment: 2000

    //timing before showing up a tooltip
    readonly property int delayToolTipAppear: (Application?.styleHints?.toolTipWakeUpDelayAsMSec ?? 700)

    //timing for the progressbar/scanbar bouncing animation, explicitly very long
    readonly property int durationSliderBouncing: 2000

    //default arts
    readonly property url noArtAlbum: "qrc:///placeholder/noart_album.svg";
    readonly property url noArtArtist: "qrc:///placeholder/noart_artist.svg";
    readonly property url noArtArtistSmall: "qrc:///placeholder/noart_artist_small.svg";
    readonly property url noArtAlbumCover: "qrc:///placeholder/noart_albumCover.svg";
    readonly property url noArtArtistCover: "qrc:///placeholder/noart_artistCover.svg";
    readonly property url noArtVideoCover: "qrc:///placeholder/noart_videoCover.svg";

    // New indicator
    readonly property url newIndicator: "qrc:///misc/new_indicator.svg";

    // ControlBar

    readonly property int controlBarBookmarksHeight: icon_xsmall * 0.9

    // Player control layout
    readonly property int controlLayoutHeight: MainCtx.dp(64, scale)
    readonly property int controlLayoutHeightPinned: MainCtx.dp(32, scale)

    // Scroll bar (size means width or height, depending on the orientation):
    readonly property real scrollBarInteractingSize: MainCtx.dp(8, scale)
    readonly property real scrollBarNonInteractingSize: MainCtx.dp(2, scale)

    // ---- Redesign semantic tokens (appended, legacy tokens above are unchanged) ----

    // Radii
    readonly property real radius_xxs: MainCtx.dp(2, scale)
    readonly property real radius_xs: MainCtx.dp(3, scale)
    readonly property real radius_s: MainCtx.dp(4, scale)
    readonly property real radius_m: MainCtx.dp(6, scale)
    readonly property real radius_l: MainCtx.dp(10, scale)
    readonly property real radius_xl: MainCtx.dp(14, scale)
    readonly property real radius_viewport: MainCtx.dp(19, scale)

    // Spacing scale
    readonly property real spacing_2: MainCtx.dp(2, scale)
    readonly property real spacing_4: MainCtx.dp(4, scale)
    readonly property real spacing_6: MainCtx.dp(6, scale)
    readonly property real spacing_8: MainCtx.dp(8, scale)
    readonly property real spacing_10: MainCtx.dp(10, scale)
    readonly property real spacing_12: MainCtx.dp(12, scale)
    readonly property real spacing_14: MainCtx.dp(14, scale)
    readonly property real spacing_16: MainCtx.dp(16, scale)
    readonly property real spacing_17: MainCtx.dp(17, scale)
    readonly property real spacing_20: MainCtx.dp(20, scale)
    readonly property real spacing_24: MainCtx.dp(24, scale)

    // Control sizes
    readonly property real titleBar_height: MainCtx.dp(40, scale)
    readonly property real controlBar_height: MainCtx.dp(54, scale)
    readonly property real playButton_w: MainCtx.dp(54, scale)
    readonly property real playButton_h: MainCtx.dp(28, scale)
    readonly property real seek_height: MainCtx.dp(28, scale)
    // waveform seek bar (Figma 2139:8124): 2 px bars every 5 px, 2..14 px tall, 4 px playhead
    readonly property real waveform_barWidth: MainCtx.dp(2, scale)
    readonly property real waveform_barSpacing: MainCtx.dp(3, scale)
    readonly property real waveform_barMinHeight: MainCtx.dp(2, scale)
    readonly property real waveform_barMaxHeight: MainCtx.dp(14, scale)
    readonly property real waveform_padding: MainCtx.dp(6, scale)
    readonly property real waveform_paddingRight: MainCtx.dp(13, scale)
    readonly property real waveform_playheadWidth: MainCtx.dp(4, scale)
    readonly property real waveform_playheadGap: MainCtx.dp(3, scale)
    readonly property real timeChip_w: MainCtx.dp(76, scale)
    readonly property real volume_w: MainCtx.dp(88, scale)
    readonly property real toggle_w: MainCtx.dp(68, scale)
    readonly property real toggle_h: MainCtx.dp(32, scale)
    readonly property real segmented_h: MainCtx.dp(44, scale)
    readonly property real segmentedCompact_h: MainCtx.dp(36, scale)
    readonly property real dropdown_h: MainCtx.dp(44, scale)
    readonly property real dropdownCompact_h: MainCtx.dp(32, scale)
    readonly property real menuItem_h: MainCtx.dp(48, scale)
    readonly property real input_h: MainCtx.dp(36, scale)
    readonly property real settingsHeader_h: MainCtx.dp(50, scale)
    readonly property real settingsNav_w: MainCtx.dp(200, scale)
    readonly property real sidebarRail_w: MainCtx.dp(50, scale)
    readonly property real sidebarPanel_w: MainCtx.dp(377, scale)
    readonly property real popoverPanel_w: MainCtx.dp(400, scale)      // tracks / settings popovers
    readonly property real popoverPanel_margin: MainCtx.dp(20, scale)  // gap to the window edge and the control bar
    readonly property real popoverTab_h: MainCtx.dp(50, scale)
    readonly property real popoverRow_h: MainCtx.dp(44, scale)
    readonly property real effectCard_padding: MainCtx.dp(16, scale)
    readonly property real effectHeader_h: MainCtx.dp(48, scale)
    readonly property real viewport_inset: MainCtx.dp(10, scale)       // player video inset / visible corner radius base
    readonly property real viewport_radius: MainCtx.dp(10, scale)      // visible video corner radius (Figma 19 is the stroke centre-line)
    readonly property real windowButton_w: MainCtx.dp(36, scale)
    // room left at the start of the title bar for the native macOS traffic lights (3 x 14pt + gaps + margin)
    readonly property real trafficLights_inset: MainCtx.trafficLightsInset  // measured from the NSWindow (points)
    readonly property real windowButton_h: MainCtx.dp(28, scale)
    readonly property real iconButton_w: MainCtx.dp(30, scale)
    readonly property real iconButton_h: MainCtx.dp(32, scale)
    readonly property color windowButton_closeHover: "#E15032"           // Figma "red" accent, used as the close hover fill

    // Volume wedge gradient (Figma 244:184), absolute, not accent themed: green -> yellow -> orange -> red

    // Type
    readonly property string fontFamily: Qt.application.font.family
    readonly property int text_caption: MainCtx.dp(12, scale)
    readonly property int text_body: MainCtx.dp(14, scale)
    readonly property int text_time: MainCtx.dp(15, scale)
    readonly property int text_heading: MainCtx.dp(16, scale)
    readonly property int text_subtitle: MainCtx.dp(20, scale)
    readonly property int text_title: MainCtx.dp(24, scale)
    readonly property int text_display: MainCtx.dp(32, scale)

    readonly property int fontWeight_light: Font.Light
    readonly property int fontWeight_regular: Font.Normal
    readonly property int fontWeight_medium: Font.Medium
    readonly property int fontWeight_semibold: Font.DemiBold

    // Control heights / widths shared by the base widgets
    readonly property real size_control_s: MainCtx.dp(32, scale)    // buttons, compact dropdown, settings rows
    readonly property real size_control_m: MainCtx.dp(36, scale)    // inputs, compact segmented
    readonly property real size_control_l: MainCtx.dp(44, scale)    // dropdown, segmented
    readonly property real size_control_xl: MainCtx.dp(52, scale)
    readonly property real size_dropdown_w: MainCtx.dp(320, scale)
    readonly property real size_dialogButton_w: MainCtx.dp(100, scale)
    readonly property real size_input_w: MainCtx.dp(200, scale)
    readonly property real size_button_w: MainCtx.dp(360, scale)
    readonly property real size_segmented_w: MainCtx.dp(213, scale)
    readonly property int icon_button: MainCtx.dp(20, scale)
    readonly property real border_input: MainCtx.dp(2, scale)
    readonly property real size_tooltip_maxw: MainCtx.dp(360, scale)
    readonly property real volume_h: MainCtx.dp(28, scale)
    readonly property real size_progress_h: MainCtx.dp(4, scale)

    // Popup surfaces: menus/popovers r10, tooltips r6, dialogs r14 (same shadow/blur everywhere)
    readonly property real radius_popup: radius_l
    readonly property real radius_tooltip: radius_m
    readonly property real radius_dialog: radius_xl

    // Blur and shadow for floating surfaces
    readonly property real blur_radius: 25
    readonly property var shadow_floating: ({ x: 0, y: MainCtx.dp(8, scale), blur: MainCtx.dp(15, scale), alpha: 0.46 })
    readonly property var shadow_popup: ({ x: 0, y: MainCtx.dp(4, scale), blur: MainCtx.dp(14, scale), alpha: 0.35 })

    // Shadow colour for every drop shadow (replaces repeated Qt.rgba(0, 0, 0, a))
    function shadowColor(alpha: real) : color {
        return Qt.rgba(0, 0, 0, vlc_style.palette.isDark ? alpha : alpha * 0.6) // softer in light schemes
    }

    function dp(size: real, scale: real) : real {
        if (!scale)
            return MainCtx.dp(size, MainCtx.intfScaleFactor)
        return MainCtx.dp(size, scale)
    }

    function colWidth(nb: int) : real {
      return nb * VLCStyle.column_width + ( nb - 1 ) * VLCStyle.column_spacing;
    }

    //dynamic margins based on screen width
    function dynamicAppMargins(width : int) : int {
        if (width < smallWidth)
            return margin_normal;
        else if(width > mediumWidth)
            return margin_large;
        else
            return margin_normal + (width - smallWidth) * (margin_large - margin_normal) /
                    (mediumWidth - smallWidth);
    }

    // volume slider gradient (Figma), used in every colour scheme
    readonly property color volumeGradient_0: "#95D318"
    readonly property color volumeGradient_1: "#B2A918"
    readonly property color volumeGradient_2: "#D37918"
    readonly property color volumeGradient_3: "#FF3737"
}
