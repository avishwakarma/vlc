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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Util

// Music player view (Figma 4767:23726 / 4778:25123).
//
//  full bleed blurred and darkened cover as backdrop
//  [ cover 738x737, radius 20, soft white glow ]
//  title - artist (24 / 500)
//
// The cover, backdrop and caption are drawn by `MusicLayer`; two layers are cross faded when the
// track changes. Optional synced lyrics are shown on the left (as in the previous audio view).
FocusScope {
    id: root

    // Properties

    // area covered by the bars (the backdrop goes behind them, the content does not)
    property real topPadding: 0
    property real bottomPadding: 0

    // left area covered by the sidebar overlay (only the lyrics layout avoids it,
    // the cover stays centered in the window like in the design)
    property real leftInset: 0

    property url coverSource

    readonly property bool lyricsMode: MainCtx.lyricsMode
    readonly property bool lyricsLayoutActive: lyricsMode
                                               && Player.hasLyrics
                                               && (width - leftInset) > VLCStyle.colWidth(6)

    readonly property string caption: {
        const title = Player.title
        const artist = Player.artist
        if (title && artist)
            return qsTr("%1 - %2").arg(title).arg(artist)
        return title || artist || ""
    }

    property alias lyricsToggle: lyricsToggle

    // Settings

    focus: true

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Music player")


    // Cross fade between two layers when the cover changes

    property bool _useB: false
    property bool _initialized: false

    function _swap() {
        const incoming = _useB ? layerA : layerB
        incoming.cover = root.coverSource
        incoming.caption = root.caption
        _useB = !_useB
    }

    onCoverSourceChanged: {
        if (_initialized)
            _swap()
    }

    onCaptionChanged: {
        // meta data may arrive after the cover: update the visible layer without fading
        const current = _useB ? layerB : layerA
        if (!_initialized || current.cover === root.coverSource)
            current.caption = root.caption
    }

    Component.onCompleted: {
        layerA.cover = root.coverSource
        layerA.caption = root.caption
        _initialized = true
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    component MusicLayer : Item {
        id: layer

        property url cover
        property string caption

        // set once the cover (or the placeholder) is ready, hides the layer until then
        readonly property bool ready: (coverImage.status !== Image.Loading) && (backdropImage.status !== Image.Loading)

        property bool shown: false

        anchors.fill: parent

        // the incoming layer is stacked above and fades in; the outgoing one stays opaque until
        // the fade is done, so that the window colour never shows through in the middle of the fade
        z: shown ? 1 : 0

        opacity: (shown && ready) ? 1.0 : 0.0

        visible: opacity > 0.0

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: layer.shown ? 0 : VLCStyle.duration_veryLong }
                NumberAnimation {
                    duration: layer.shown ? VLCStyle.duration_veryLong : 0
                    easing.type: Easing.InOutSine
                }
            }
        }

        // average luminance of the cover (0..1), measured once per cover on a 16x16 downscale
        property real luminance: 0.4

        readonly property bool hasCover: !(layer.cover.toString() === ""
                                           || layer.cover.toString() === VLCStyle.noArtAlbumCover.toString()
                                           || layer.cover.toString() === VLCStyle.noArtVideoCover.toString()
                                           || coverImage._failed)

        // darkness (dark theme) or whiteness (light theme) of the veil over the blurred cover:
        // bright covers get a stronger veil so that text and the accent pill keep their contrast
        readonly property real veilTarget: bgtheme.palette.isDark ? (0.20 + 0.52 * luminance)
                                                            : (0.50 + 0.32 * (1.0 - luminance))

        property real veil: veilTarget

        Behavior on veil { NumberAnimation { duration: VLCStyle.duration_long } }

        // no cover: subtle accent tinted gradient
        Rectangle {
            anchors.fill: parent

            visible: !layer.hasCover

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(bgtheme.bg.primary, Qt.alpha(bgtheme.accent, 0.30)) }
                GradientStop { position: 0.6; color: Qt.tint(bgtheme.bg.primary, Qt.alpha(bgtheme.accent, 0.10)) }
                GradientStop { position: 1.0; color: Qt.tint(bgtheme.bg.primary, Qt.alpha(bgtheme.accent, 0.18)) }
            }
        }

        // backdrop source: small version of the cover (cheap to blur, all detail is lost anyway)
        Widgets.ImageExt {
            id: backdropImage

            visible: false
            width: 1
            height: 1

            source: layer.hasCover ? coverImage.source : ""
            sourceSize: Qt.size(24, 24)
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: true
        }

        Canvas {
            id: lumaProbe

            visible: false
            width: 16
            height: 16
            renderTarget: Canvas.Image

            property url src: layer.hasCover ? coverImage.source : ""

            onSrcChanged: {
                if (src.toString() !== "")
                    loadImage(src)
            }
            onImageLoaded: requestPaint()
            onPaint: {
                if (src.toString() === "" || !isImageLoaded(src))
                    return
                const ctx = getContext("2d")
                ctx.drawImage(src, 0, 0, width, height)
                const d = ctx.getImageData(0, 0, width, height).data
                let sum = 0
                for (let i = 0; i < d.length; i += 4)
                    sum += (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255
                layer.luminance = sum / (d.length / 4)
            }
        }

        // backdrop: heavily blurred cover, filling the whole window (rendered once per cover)
        Widgets.DualKawaseBlur {
            id: blurredBackground

            visible: layer.hasCover

            mode: Widgets.DualKawaseBlur.Mode.SixPass
            radius: 8

            live: true

            readonly property real side: Math.max(parent.width, parent.height) * 1.6

            anchors.centerIn: parent
            width: side
            height: side

            source: textureProviderIndirection

            // noise dithers the gradients, no visible banding
            postprocess: true
            noiseStrength: 0.03
            backgroundColor: bgtheme.bg.primary

            readonly property ColorContext colorContext: ColorContext {
                id: bgtheme
                colorSet: ColorContext.View
            }

            viewportRect: Qt.rect((width - parent.width) / 2, (height - parent.height) / 2, parent.width, parent.height)

            sourceTextureProviderObserver.onTextureChanged: liveTimer.transientTurnOnLive()

            TextureProviderIndirection {
                id: textureProviderIndirection

                source: backdropImage.sourceTextureProviderItem
            }

            Component.onCompleted: {
                widthChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
                heightChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
                liveTimer.transientTurnOnLive()
            }

            Timer {
                id: liveTimer

                repeat: false
                interval: VLCStyle.duration_humanMoment

                function transientTurnOnLive() {
                    if (!blurredBackground.sourceTextureIsValid)
                        return
                    blurredBackground.live = true
                    liveTimer.restart()
                }

                onTriggered: blurredBackground.live = false
            }
        }

        // veil + vignette: contrast for the translucent bars and the caption
        Rectangle {
            anchors.fill: parent

            visible: layer.hasCover
            color: bgtheme.palette.isDark ? "black" : "white"
            opacity: layer.veil
        }

        Rectangle {
            id: vignette

            anchors.fill: parent

            visible: layer.hasCover

            readonly property color edge: bgtheme.palette.isDark ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.15)

            gradient: Gradient {
                GradientStop { position: 0.0; color: vignette.edge }
                GradientStop { position: 0.22; color: "transparent" }
                GradientStop { position: 0.72; color: "transparent" }
                GradientStop { position: 1.0; color: vignette.edge }
            }
        }

        // cover + caption column
        Item {
            id: column

            // the cover column is centered in the window, or in the area right of the lyrics
            readonly property real centerX: root.lyricsLayoutActive ? (root.leftInset + (root.width - root.leftInset) * 0.6 + (root.width - root.leftInset) * 0.2)
                                                                    : root.width / 2

            readonly property real _m: Math.min(VLCStyle.dp(73, VLCStyle.scale), avail * 0.074)
            readonly property real avail: root.height - root.topPadding - root.bottomPadding
            readonly property real _gap: Math.min(VLCStyle.dp(74, VLCStyle.scale), avail * 0.075)

            readonly property real coverSize: Math.max(0, Math.min(VLCStyle.dp(738, VLCStyle.scale),
                                                                    avail - _m * 2 - _gap - captionLabel.implicitHeight,
                                                                    (root.lyricsLayoutActive ? (root.width - root.leftInset) * 0.4 : root.width) - _m * 2))

            width: coverSize
            height: coverSize + _gap + captionLabel.implicitHeight

            x: centerX - width / 2
            y: root.topPadding + _m + Math.max(0, (avail - _m * 2 - height) / 2)

            Behavior on x {
                enabled: root._initialized
                NumberAnimation {
                    duration: VLCStyle.duration_long
                    easing.type: Easing.InOutSine
                }
            }

            Widgets.ImageExt {
                id: coverImage

                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

                width: column.coverSize
                height: column.coverSize

                source: (layer.cover.toString() === "" || _failed) ? VLCStyle.noArtAlbumCover
                                                                   : VLCAccessImage.uri(layer.cover)
                sourceSize: Qt.size(VLCStyle.dp(738, VLCStyle.scale) * eDPR,
                                    VLCStyle.dp(738, VLCStyle.scale) * eDPR)
                fillMode: Image.PreserveAspectCrop
                radius: VLCStyle.dp(20, VLCStyle.scale)
                cache: false
                asynchronous: true
                property bool _failed: false

                onStatusChanged: {
                    if (status === Image.Error)
                        _failed = true
                }

                Connections {
                    target: layer
                    function onCoverChanged() { coverImage._failed = false }
                }

                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("Cover")

                // Figma: 0 0 90.5 spread 64, white 3%
                Widgets.RoundedRectangleShadow {
                    color: Qt.rgba(1, 1, 1, 0.03)
                    blurRadius: VLCStyle.dp(90.5, VLCStyle.scale)
                    compensationFactor: 1.0
                    implicitCompensationFactor: 1.0
                    implicitWidth: parent.width + VLCStyle.dp(64, VLCStyle.scale) * 2 + blurRadius * 2
                    implicitHeight: parent.height + VLCStyle.dp(64, VLCStyle.scale) * 2 + blurRadius * 2
                    radius: VLCStyle.dp(20, VLCStyle.scale) + VLCStyle.dp(64, VLCStyle.scale)
                }
            }

            Text {
                id: captionLabel

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: coverImage.bottom
                anchors.topMargin: column._gap

                width: Math.min(implicitWidth, root.width - VLCStyle.dp(40, VLCStyle.scale))
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter

                text: layer.caption

                font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                font.weight: VLCStyle.fontWeight_medium
                color: theme.fg.primary

                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
        }
    }

    MusicLayer {
        id: layerA

        shown: !root._useB
    }

    MusicLayer {
        id: layerB

        shown: root._useB
    }

    // Lyrics (left side of the window, only when the track has lyrics and the lyrics mode is on)
    Loader {
        id: lyricsLoader

        active: root.lyricsLayoutActive

        anchors.left: parent.left
        anchors.leftMargin: root.leftInset
        anchors.top: parent.top
        anchors.topMargin: root.topPadding + VLCStyle.margin_large
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomPadding

        width: (root.width - root.leftInset) * 0.6

        sourceComponent: LyricsFlickable {
            onPlayerPositionChangeRequested: (time) => {
                Player.setTime(time)
                lyricsSyncToPlayback = true
            }
        }

        opacity: item ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: VLCStyle.duration_long
                easing.type: Easing.InOutSine
            }
        }
    }

    // Lyrics toggle: only shown when the track has lyrics
    Widgets.IconToolButton {
        id: lyricsToggle

        visible: Player.hasLyrics

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomPadding + VLCStyle.dp(20, VLCStyle.scale)

        text: VLCIcons.topbar_music
        font.pixelSize: VLCStyle.icon_audioPlayerButton
        checked: MainCtx.lyricsMode
        onClicked: MainCtx.lyricsMode = !MainCtx.lyricsMode
        description: qsTr("Lyrics")

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Toggle lyrics view")
        AccessibleCompat.id: "audioLyricsButton"

        Navigation.parentItem: root
    }
}
