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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Full bleed backdrop made of a heavily blurred, luminance adapted cover (music player and
// miniplayer). The blur is rendered once per cover (it is only live briefly after a change).
Item {
    id: root

    // cover url as given by the player, and whether loading the cover failed
    property url cover
    property bool coverFailed: false

    readonly property url source: root.cover.toString() === "" ? "" : VLCAccessImage.uri(root.cover)

    // set once the (small) backdrop source is loaded
    readonly property bool ready: backdropImage.status !== Image.Loading

    clip: true

    // average luminance of the cover (0..1), measured once per cover on a 16x16 downscale
    property real luminance: 0.4

    readonly property bool hasCover: !(root.cover.toString() === ""
                                       || root.cover.toString() === VLCStyle.noArtAlbumCover.toString()
                                       || root.cover.toString() === VLCStyle.noArtVideoCover.toString()
                                       || root.coverFailed)

    // darkness (dark theme) or whiteness (light theme) of the veil over the blurred cover:
    // bright covers get a stronger veil so that text and the accent pill keep their contrast
    readonly property real veilTarget: bgtheme.palette.isDark ? (0.20 + 0.52 * luminance)
                                                        : (0.50 + 0.32 * (1.0 - luminance))

    property real veil: veilTarget

    Behavior on veil { NumberAnimation { duration: VLCStyle.duration_long } }

    // no cover: subtle accent tinted gradient
    Rectangle {
        anchors.fill: parent

        visible: !root.hasCover

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

        source: root.hasCover ? root.source : ""
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

        property url src: root.hasCover ? root.source : ""

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
            root.luminance = sum / (d.length / 4)
        }
    }

    // backdrop: heavily blurred cover, filling the whole window (rendered once per cover)
    Widgets.DualKawaseBlur {
        id: blurredBackground

        visible: root.hasCover

        mode: Widgets.DualKawaseBlur.Mode.SixPass
        radius: 8

        live: true

        // The blur chain samples up to a few hundred pixels beyond the visible window and
        // clamps to the edge of its textures; with a smaller oversize that clamped area leaked
        // into the right edge as a purple/pink tint.
        readonly property real side: Math.max(parent.width, parent.height) * 2.4

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

        visible: root.hasCover
        color: bgtheme.palette.isDark ? "black" : "white"
        opacity: root.veil
    }

    Rectangle {
        id: vignette

        anchors.fill: parent

        visible: root.hasCover

        readonly property color edge: bgtheme.palette.isDark ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.15)

        gradient: Gradient {
            GradientStop { position: 0.0; color: vignette.edge }
            GradientStop { position: 0.22; color: "transparent" }
            GradientStop { position: 0.72; color: "transparent" }
            GradientStop { position: 1.0; color: vignette.edge }
        }
    }
}
