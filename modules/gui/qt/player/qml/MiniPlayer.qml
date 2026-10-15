/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import QtQuick.Shapes
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.Dialogs
import VLC.Util

// Miniplayer card (Figma 970:3091), docked at the bottom corner of the library window:
//
//  +--------------------------------+
//  |  [   cover / preview 375x211 ] |   hover: dimmed art, close, pop-out, prev / play / next
//  |  [=====seek bar (16)==========]|
//  |  title                         |
//  |  [folder] name  [artist] name  [queue] |
//  +--------------------------------+
//
// The card floats over the library: the root item has no height so that the
// library layout is not affected (MainDisplay anchors the root to the bottom edge).
FocusScope {
    id: root

    // Properties (the first ones are set by MainDisplay)

    property real horizontalPadding: 0
    property real bottomPadding: 0

    // MainDisplay toggles `background.visible`, the card draws its own surface
    property Item background: Item {}

    // y of the seek bar relative to the root, used for the thumbnail/time bubbles of the main display
    readonly property real sliderY: -(card.height - (card.sliderBottomOffset))

    // true: the card is docked at the left edge (Figma 970:3792), false: right edge (970:2703)
    property bool dockLeft: false

    property bool queueVisible: false

    // true: the preview shows the live video (MainDisplay sets it when the embedded video
    // output can be shown outside of the player view)
    property bool videoPreview: false

    readonly property bool _isVideo: Player.hasVideoOutput

    readonly property bool shown: Player.isStarted

    readonly property real cardWidth: VLCStyle.dp(391, VLCStyle.scale)

    // Settings


    height: 0
    visible: shown || card.opacity > 0.0

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Mini player")
    AccessibleCompat.id: "miniplayerControlBar"

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space) {
            MainPlaylistController.togglePlayPause()
            event.accepted = true
        } else {
            root.Navigation.defaultKeyAction(event)
        }
    }

    // folder of the playing media
    readonly property string folderName: {
        const url = Player.url
        if (!url || url.toString() === "")
            return ""

        let str = url.toString()
        try {
            str = decodeURIComponent(str)
        } catch (e) {
        }

        str = str.split("?")[0].split("#")[0]

        const parts = str.split("/").filter(part => part.length > 0)
        return (parts.length >= 2) ? parts[parts.length - 2] : ""
    }

    readonly property url coverSource: (Player.artwork && Player.artwork.toString() !== "") ? Player.artwork : ""

    // audio with a cover: the card background is the blurred cover (as in the music player)
    readonly property bool coverBackdrop: !Player.hasVideoOutput && coverSource.toString() !== ""

    readonly property bool _ended: Player.playingState === Player.PLAYING_STATE_STOPPED

    function expand() {
        MainCtx.playerView = true
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property ColorContext viewContext: ColorContext {
        id: viewTheme
        colorSet: ColorContext.View
    }

    readonly property ColorContext itemContext: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
    }

    readonly property ColorContext sliderContext: ColorContext {
        id: sliderTheme
        colorSet: ColorContext.Slider
    }

    readonly property ColorContext fieldContext: ColorContext {
        id: fieldTheme
        colorSet: ColorContext.TextField
    }

    Item {
        id: card

        readonly property real sliderBottomOffset: VLCStyle.dp(8 + 73 + 20, VLCStyle.scale)

        width: root.cardWidth
        height: surface.implicitHeight

        anchors.bottom: parent.bottom
        anchors.bottomMargin: VLCStyle.dp(6, VLCStyle.scale) + VLCStyle.applicationVerticalMargin
        anchors.left: root.dockLeft ? parent.left : undefined
        anchors.leftMargin: VLCStyle.dp(6, VLCStyle.scale) + root.horizontalPadding
        anchors.right: root.dockLeft ? undefined : parent.right
        anchors.rightMargin: VLCStyle.dp(6, VLCStyle.scale) + root.horizontalPadding

        // show / hide: fade + slide up
        opacity: root.shown ? 1.0 : 0.0
        transform: Translate { y: root.shown ? 0 : VLCStyle.dp(24, VLCStyle.scale)
            Behavior on y { NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine } }
        }

        Behavior on opacity {
            NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
        }

        Behavior on height {
            NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
        }

        // blocks the clicks going to the library below
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => wheel.accepted = true
        }

        Rectangle {
            id: surface

            anchors.fill: parent

            implicitHeight: content.implicitHeight + VLCStyle.dp(16, VLCStyle.scale)

            radius: VLCStyle.radius_xl
            color: theme.bg.primary

            // Figma: 0 0 5.9 rgba(0,0,0,.38)
            Widgets.RoundedRectangleShadow {
                color: Qt.rgba(0, 0, 0, 0.38)
                blurRadius: VLCStyle.dp(5.9, VLCStyle.scale)
            }

            // blurred cover, shared with the music player. It is rendered once per cover into a
            // texture (live only briefly after a change) and shown with the card's rounded corners
            MusicBackdrop {
                id: coverBackdrop

                width: surface.width
                height: surface.height

                cover: root.coverSource

            }

            ShaderEffectSource {
                id: coverBackdropTexture

                sourceItem: coverBackdrop
                hideSource: true
                live: coverBackdropLive.running
                width: surface.width
                height: surface.height
                // an invisible source is not rendered; this one is only a texture for the rounded
                // image below (its own, square, rendering is practically transparent)
                opacity: 0.002

                Timer {
                    id: coverBackdropLive

                    interval: VLCStyle.duration_veryLong * 2
                    running: true
                    repeat: false
                }

                Connections {
                    target: root
                    function onCoverSourceChanged() { coverBackdropLive.restart() }
                }

                onWidthChanged: coverBackdropLive.restart()
                onHeightChanged: coverBackdropLive.restart()
            }

            Widgets.EnhancedImageExt {
                anchors.fill: parent

                visible: root.coverBackdrop && coverBackdrop.hasCover
                fillMode: Image.Stretch
                radius: surface.radius
                targetTextureProvider: coverBackdropTexture
            }

            Column {
                id: content

                x: VLCStyle.dp(8, VLCStyle.scale)
                y: VLCStyle.dp(8, VLCStyle.scale)
                width: parent.width - VLCStyle.dp(16, VLCStyle.scale)

                // Queue panel (Figma 975:4377), revealed above the media
                Item {
                    id: queueWrapper

                    width: parent.width
                    height: root.queueVisible ? (queuePanel.height + VLCStyle.dp(20, VLCStyle.scale)) : 0
                    clip: true
                    visible: height > 0

                    Behavior on height {
                        NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
                    }

                    Loader {
                        id: queuePanel

                        active: queueWrapper.visible
                        width: parent.width
                        height: VLCStyle.dp(331, VLCStyle.scale)
                        opacity: root.queueVisible ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: VLCStyle.duration_long; easing.type: Easing.InOutSine }
                        }

                        sourceComponent: queueComponent
                    }
                }

                // Media: preview (16:9) + seek bar
                Item {
                    id: media

                    width: parent.width
                    height: VLCStyle.dp(230, VLCStyle.scale)

                    readonly property bool hovered: mediaHover.hovered || closeButton.hovered || popButton.hovered
                                                    || prevButton.hovered || playButton.hovered || nextButton.hovered
                                                    || seekArea.containsMouse || seekArea.pressed
                    readonly property bool overlayVisible: hovered || root.activeFocus && (closeButton.visualFocus || popButton.visualFocus
                                                           || prevButton.visualFocus || playButton.visualFocus || nextButton.visualFocus)

                    HoverHandler {
                        id: mediaHover
                    }

                    // preview
                    Rectangle {
                        id: preview

                        width: parent.width
                        height: Math.round(width * 9 / 16)

                        radius: VLCStyle.radius_m
                        // audio with a cover: the blurred cover of the card shows on both sides of the square cover
                        color: root.videoPreview ? "black"
                               : (root.coverBackdrop && coverBackdrop.hasCover) ? "transparent"
                               : root.coverSource.toString() !== "" ? itemTheme.bg.secondary : Qt.darker(itemTheme.bg.secondary, 1.5)
                        clip: true

                        // double click to maximise
                        TapHandler {
                            onDoubleTapped: root.expand()
                            onTapped: MainPlaylistController.togglePlayPause()
                        }

                        Item {
                            id: artLayer

                            anchors.fill: parent
                            anchors.margins: VLCStyle.dp(2, VLCStyle.scale)

                            visible: !root.videoPreview

                            property url shownSource: root.coverSource

                            Connections {
                                target: root
                                function onCoverSourceChanged() {
                                    coverFade.restart()
                                }
                            }

                            SequentialAnimation {
                                id: coverFade

                                NumberAnimation { target: artImage; property: "opacity"; to: 0.0; duration: VLCStyle.duration_short }
                                ScriptAction { script: artLayer.shownSource = root.coverSource }
                                NumberAnimation { target: artImage; property: "opacity"; to: 1.0; duration: VLCStyle.duration_long }
                            }

                            Widgets.ImageExt {
                                id: artImage

                                anchors.fill: parent

                                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

                                visible: artLayer.shownSource.toString() !== ""
                                source: artLayer.shownSource.toString() !== "" ? VLCAccessImage.uri(artLayer.shownSource) : ""
                                sourceSize: Qt.size(width * eDPR, width * eDPR)
                                fillMode: Image.PreserveAspectFit
                                radius: VLCStyle.radius_s
                                cache: false
                            }

                            Widgets.SvgIcon {
                                anchors.centerIn: parent
                                visible: !artImage.visible
                                name: root._isVideo ? "video" : "music"
                                size: VLCStyle.dp(64, VLCStyle.scale)
                                color: viewTheme.fg.secondary
                            }
                        }

                        // live video: the native video window is placed under this rectangle
                        // (the surface clears the UI there), the corners are painted in the card colour
                        Loader {
                            id: videoPreviewLoader

                            anchors.fill: parent

                            active: root.videoPreview
                            visible: active

                            sourceComponent: Item {
                                VideoSurface {
                                    anchors.fill: parent
                                    anchors.margins: VLCStyle.dp(2, VLCStyle.scale)

                                    videoSurfaceProvider: MainCtx.videoSurfaceProvider

                                    // the preview handles the clicks (play/pause, double click to expand)
                                    enabled: false
                                }

                                Shape {
                                    id: cornerMask

                                    anchors.fill: parent

                                    readonly property real r: preview.radius

                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        strokeColor: "transparent"
                                        fillColor: surface.color
                                        fillRule: ShapePath.OddEvenFill

                                        PathSvg {
                                            path: {
                                                const w = cornerMask.width, h = cornerMask.height, r = cornerMask.r
                                                return "M0 0H" + w + "V" + h + "H0Z"
                                                     + "M" + r + " 0H" + (w - r)
                                                     + "A" + r + " " + r + " 0 0 1 " + w + " " + r
                                                     + "V" + (h - r)
                                                     + "A" + r + " " + r + " 0 0 1 " + (w - r) + " " + h
                                                     + "H" + r
                                                     + "A" + r + " " + r + " 0 0 1 0 " + (h - r)
                                                     + "V" + r
                                                     + "A" + r + " " + r + " 0 0 1 " + r + " 0Z"
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2px B2 border drawn above the art
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: VLCStyle.dp(2, VLCStyle.scale)
                            border.color: sliderTheme.bg.primary
                        }

                        // hover overlay: dimmed art + controls
                        Rectangle {
                            id: overlay

                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(0, 0, 0, 0.6)

                            opacity: media.overlayVisible ? 1.0 : 0.0
                            visible: opacity > 0.0

                            Behavior on opacity {
                                NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.InOutSine }
                            }

                            // close playback (top left)
                            Widgets.IconToolButton {
                                id: closeButton

                                x: VLCStyle.dp(14, VLCStyle.scale)
                                y: VLCStyle.dp(14, VLCStyle.scale)

                                iconName: "close"
                                iconSize: VLCStyle.dp(24, VLCStyle.scale)
                                width: VLCStyle.dp(24, VLCStyle.scale)
                                height: VLCStyle.dp(24, VLCStyle.scale)
                                padding: 0
                                description: qsTr("Close")
                                color: viewTheme.fg.highlight

                                AccessibleCompat.id: "miniplayerCloseButton"

                                onClicked: MainPlaylistController.stop()

                                Navigation.parentItem: root
                                Navigation.rightItem: popButton
                                Navigation.downItem: playButton
                            }

                            // expand to the full player (top right)
                            Widgets.IconToolButton {
                                id: popButton

                                x: parent.width - width - VLCStyle.dp(14, VLCStyle.scale)
                                y: VLCStyle.dp(14, VLCStyle.scale)

                                iconName: "open"
                                iconSize: VLCStyle.dp(24, VLCStyle.scale)
                                width: VLCStyle.dp(24, VLCStyle.scale)
                                height: VLCStyle.dp(24, VLCStyle.scale)
                                padding: 0
                                description: qsTr("Open player")
                                color: viewTheme.fg.highlight

                                AccessibleCompat.id: "miniplayerExpandButton"

                                onClicked: root.expand()

                                Navigation.parentItem: root
                                Navigation.leftItem: closeButton
                                Navigation.downItem: playButton
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: VLCStyle.dp(21.3, VLCStyle.scale)

                                Widgets.IconToolButton {
                                    id: prevButton

                                    iconName: "previous"
                                    iconSize: VLCStyle.dp(42.857, VLCStyle.scale)
                                    width: VLCStyle.dp(53.571, VLCStyle.scale)
                                    height: VLCStyle.dp(50, VLCStyle.scale)
                                    leftPadding: VLCStyle.dp(5.357, VLCStyle.scale)
                                    rightPadding: VLCStyle.dp(5.357, VLCStyle.scale)
                                    topPadding: VLCStyle.dp(3.571, VLCStyle.scale)
                                    bottomPadding: VLCStyle.dp(3.571, VLCStyle.scale)
                                    radius: VLCStyle.dp(7.143, VLCStyle.scale)
                                    description: qsTr("Previous")
                                    color: viewTheme.fg.highlight

                                    AccessibleCompat.id: "miniplayerPreviousButton"

                                    onClicked: MainPlaylistController.prev()

                                    Navigation.parentItem: root
                                    Navigation.rightItem: playButton
                                    Navigation.upItem: closeButton
                                }

                                Widgets.IconToolButton {
                                    id: playButton

                                    iconName: root._ended ? "replay"
                                                          : (Player.playingState === Player.PLAYING_STATE_PAUSED ? "play" : "pause")
                                    iconSize: VLCStyle.dp(42.857, VLCStyle.scale)
                                    width: VLCStyle.dp(53.571, VLCStyle.scale)
                                    height: VLCStyle.dp(50, VLCStyle.scale)
                                    leftPadding: VLCStyle.dp(5.357, VLCStyle.scale)
                                    rightPadding: VLCStyle.dp(5.357, VLCStyle.scale)
                                    topPadding: VLCStyle.dp(3.571, VLCStyle.scale)
                                    bottomPadding: VLCStyle.dp(3.571, VLCStyle.scale)
                                    radius: VLCStyle.dp(7.143, VLCStyle.scale)
                                    description: root._ended ? qsTr("Replay") : qsTr("Play/Pause")
                                    color: viewTheme.fg.highlight

                                    AccessibleCompat.id: "miniplayerPlayButton"

                                    onClicked: {
                                        if (root._ended)
                                            MainPlaylistController.play()
                                        else
                                            MainPlaylistController.togglePlayPause()
                                    }

                                    Navigation.parentItem: root
                                    Navigation.leftItem: prevButton
                                    Navigation.rightItem: nextButton
                                    Navigation.upItem: closeButton
                                }

                                Widgets.IconToolButton {
                                    id: nextButton

                                    iconName: "next"
                                    iconSize: VLCStyle.dp(42.857, VLCStyle.scale)
                                    width: VLCStyle.dp(53.571, VLCStyle.scale)
                                    height: VLCStyle.dp(50, VLCStyle.scale)
                                    leftPadding: VLCStyle.dp(5.357, VLCStyle.scale)
                                    rightPadding: VLCStyle.dp(5.357, VLCStyle.scale)
                                    topPadding: VLCStyle.dp(3.571, VLCStyle.scale)
                                    bottomPadding: VLCStyle.dp(3.571, VLCStyle.scale)
                                    radius: VLCStyle.dp(7.143, VLCStyle.scale)
                                    description: qsTr("Next")
                                    color: viewTheme.fg.highlight

                                    AccessibleCompat.id: "miniplayerNextButton"

                                    onClicked: MainPlaylistController.next()

                                    Navigation.parentItem: root
                                    Navigation.leftItem: playButton
                                    Navigation.upItem: popButton
                                }
                            }
                        }
                    }

                    // seek bar: 16 high B2 track, played part inset by 2, thumb on hover
                    Rectangle {
                        id: seekTrack

                        y: preview.height + VLCStyle.dp(4, VLCStyle.scale)
                        width: parent.width
                        height: VLCStyle.dp(16, VLCStyle.scale)

                        radius: VLCStyle.radius_m
                        color: sliderTheme.bg.primary

                        readonly property real inset: VLCStyle.dp(2, VLCStyle.scale)
                        readonly property real thumbWidth: VLCStyle.dp(8, VLCStyle.scale)
                        readonly property real position: Math.max(0, Math.min(1, Player.position))
                        readonly property real thumbX: inset + position * Math.max(0, width - inset * 2 - thumbWidth)

                        Accessible.role: Accessible.Slider
                        Accessible.name: qsTr("Progress")

                        Rectangle {
                            x: seekTrack.inset
                            y: seekTrack.inset
                            width: seekTrack.thumbX + seekTrack.thumbWidth - seekTrack.inset
                            height: parent.height - seekTrack.inset * 2
                            radius: VLCStyle.radius_s
                            color: sliderTheme.fg.primary
                        }

                        Rectangle {
                            x: seekTrack.thumbX
                            y: seekTrack.inset
                            width: seekTrack.thumbWidth
                            height: parent.height - seekTrack.inset * 2
                            radius: VLCStyle.radius_s
                            color: sliderTheme.accent

                            opacity: media.overlayVisible ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation { duration: VLCStyle.duration_short }
                            }
                        }

                        MouseArea {
                            id: seekArea

                            anchors.fill: parent
                            anchors.topMargin: -VLCStyle.dp(4, VLCStyle.scale)
                            anchors.bottomMargin: -VLCStyle.dp(4, VLCStyle.scale)

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: Player.playingState === Player.PLAYING_STATE_PLAYING
                                     || Player.playingState === Player.PLAYING_STATE_PAUSED

                            function seek(mouse) {
                                const usable = Math.max(1, seekTrack.width - seekTrack.inset * 2 - seekTrack.thumbWidth)
                                Player.position = Math.max(0, Math.min(1, (mouse.x - seekTrack.inset - seekTrack.thumbWidth / 2) / usable))
                            }

                            onPressed: (mouse) => seek(mouse)
                            onPositionChanged: (mouse) => { if (pressed) seek(mouse) }
                        }
                    }
                }

                Item {
                    width: 1
                    height: VLCStyle.dp(20, VLCStyle.scale)
                }

                // title + folder / artist + queue button
                Item {
                    id: textBlock

                    width: parent.width
                    height: VLCStyle.dp(73, VLCStyle.scale)

                    opacity: 1.0

                    Text {
                        id: titleLabel

                        x: VLCStyle.dp(8, VLCStyle.scale)
                        y: VLCStyle.dp(4, VLCStyle.scale)
                        width: parent.width - VLCStyle.dp(16, VLCStyle.scale)

                        elide: Text.ElideRight
                        text: Player.displayTitle
                        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                        font.weight: VLCStyle.fontWeight_regular
                        color: viewTheme.fg.primary

                        Accessible.role: Accessible.StaticText
                        Accessible.name: text

                        Behavior on text {
                            enabled: false
                        }

                        // cross fade when the track changes
                        Connections {
                            target: Player
                            function onCurrentMetaChanged() {
                                textFade.restart()
                            }
                        }

                        SequentialAnimation {
                            id: textFade

                            NumberAnimation { target: textBlock; property: "opacity"; from: 0.0; to: 1.0; duration: VLCStyle.duration_veryLong; easing.type: Easing.InOutSine }
                        }
                    }

                    Row {
                        id: infoRow

                        x: VLCStyle.dp(8, VLCStyle.scale)
                        y: parent.height - VLCStyle.dp(4 + 32, VLCStyle.scale) + (VLCStyle.dp(32, VLCStyle.scale) - height) / 2
                        spacing: VLCStyle.dp(20, VLCStyle.scale)

                        // folder
                        Row {
                            spacing: VLCStyle.spacing_8
                            visible: root.folderName !== ""

                            Widgets.SvgIcon {
                                name: "folder"
                                size: VLCStyle.dp(24, VLCStyle.scale)
                                color: viewTheme.fg.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, textBlock.width * 0.4)
                                elide: Text.ElideRight
                                text: root.folderName
                                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                color: viewTheme.fg.primary
                            }
                        }

                        // artist
                        Row {
                            spacing: VLCStyle.spacing_8
                            visible: Player.artist !== ""

                            Widgets.SvgIcon {
                                name: "artist"
                                size: VLCStyle.dp(24, VLCStyle.scale)
                                color: viewTheme.fg.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, textBlock.width * 0.4)
                                elide: Text.ElideRight
                                text: Player.artist
                                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                color: viewTheme.fg.primary
                            }
                        }
                    }

                    // queue
                    Widgets.IconToolButton {
                        id: queueButton

                        x: parent.width - width - VLCStyle.dp(8, VLCStyle.scale)
                        y: parent.height - height - VLCStyle.dp(4, VLCStyle.scale)
                        width: VLCStyle.dp(30, VLCStyle.scale)
                        height: VLCStyle.dp(32, VLCStyle.scale)

                        iconName: "lists"
                        iconNameChecked: "lists-active"
                        iconSize: VLCStyle.dp(24, VLCStyle.scale)
                        leftPadding: VLCStyle.dp(3, VLCStyle.scale)
                        rightPadding: VLCStyle.dp(3, VLCStyle.scale)
                        topPadding: VLCStyle.dp(4, VLCStyle.scale)
                        bottomPadding: VLCStyle.dp(4, VLCStyle.scale)
                        radius: VLCStyle.radius_s
                        checked: root.queueVisible
                        description: qsTr("Queue")

                        AccessibleCompat.id: "miniplayerQueueButton"

                        onClicked: root.queueVisible = !root.queueVisible

                        Navigation.parentItem: root
                        Navigation.upItem: playButton
                    }
                }
            }
        }
    }

    // Queue panel content (Figma 975:4378)
    Component {
        id: queueComponent

        Rectangle {
            radius: VLCStyle.radius_l
            color: theme.bg.primary
            clip: true

            // header
            Rectangle {
                id: queueHeader

                width: parent.width
                height: VLCStyle.dp(58, VLCStyle.scale)

                color: fieldTheme.bg.primary
                topLeftRadius: VLCStyle.radius_xl
                topRightRadius: VLCStyle.radius_xl
                bottomLeftRadius: VLCStyle.radius_xxs
                bottomRightRadius: VLCStyle.radius_xxs

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: VLCStyle.dp(16, VLCStyle.scale)
                    text: qsTr("Queue")
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    color: viewTheme.fg.primary
                }
            }

            // count + actions
            Item {
                id: queueInfo

                y: queueHeader.height + VLCStyle.dp(1, VLCStyle.scale)
                width: parent.width
                height: VLCStyle.dp(64, VLCStyle.scale)

                Text {
                    x: VLCStyle.dp(28, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 items - %2").arg(queueModel.count).arg(queueDuration.text)
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    color: viewTheme.fg.secondary
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: VLCStyle.dp(20, VLCStyle.scale)

                    Widgets.IconToolButton {
                        iconName: "sort"
                        iconSize: VLCStyle.dp(24, VLCStyle.scale)
                        width: VLCStyle.dp(24, VLCStyle.scale)
                        height: VLCStyle.dp(24, VLCStyle.scale)
                        padding: 0
                        description: qsTr("Sort")
                        onClicked: MainPlaylistController.sort()
                    }

                    Widgets.IconToolButton {
                        iconName: "remove"
                        iconSize: VLCStyle.dp(24, VLCStyle.scale)
                        width: VLCStyle.dp(24, VLCStyle.scale)
                        height: VLCStyle.dp(24, VLCStyle.scale)
                        padding: 0
                        description: qsTr("Clear queue")
                        onClicked: MainPlaylistController.clear()
                    }

                    Widgets.IconToolButton {
                        iconName: "add"
                        iconSize: VLCStyle.dp(24, VLCStyle.scale)
                        width: VLCStyle.dp(24, VLCStyle.scale)
                        height: VLCStyle.dp(24, VLCStyle.scale)
                        padding: 0
                        description: qsTr("Add media")
                        onClicked: DialogsProvider.simpleOpenDialog()
                    }
                }
            }

            PlaylistListModel {
                id: queueModel

                playlist: MainPlaylistController.playlist
            }

            Text {
                id: queueDuration

                visible: false
                text: {
                    const secs = queueModel.duration.toSeconds()
                    const h = Math.floor(secs / 3600)
                    const m = Math.floor((secs % 3600) / 60)
                    return h > 0 ? qsTr("%1h %2m").arg(h).arg(m) : qsTr("%1m").arg(m)
                }
            }

            ListView {
                id: queueList

                y: queueInfo.y + queueInfo.height
                width: parent.width
                height: parent.height - y

                clip: true
                model: queueModel
                spacing: VLCStyle.dp(12, VLCStyle.scale)
                leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                rightMargin: VLCStyle.dp(20, VLCStyle.scale)

                currentIndex: MainPlaylistController.currentIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: rowItem

                    required property int index
                    required property string title
                    required property var duration
                    required property bool isCurrent

                    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                    height: VLCStyle.dp(32, VLCStyle.scale)

                    Rectangle {
                        anchors.fill: parent
                        radius: VLCStyle.radius_s
                        color: itemTheme.bg.primary
                        opacity: rowHover.hovered ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
                    }

                    HoverHandler { id: rowHover }

                    TapHandler {
                        onDoubleTapped: MainPlaylistController.goTo(rowItem.index, true)
                    }

                    Widgets.SvgIcon {
                        id: handle

                        x: VLCStyle.dp(4, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "move"
                        size: VLCStyle.dp(24, VLCStyle.scale)
                        color: viewTheme.fg.primary
                    }

                    Text {
                        anchors.left: handle.right
                        anchors.leftMargin: VLCStyle.dp(14, VLCStyle.scale)
                        anchors.right: durationLabel.left
                        anchors.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: rowItem.title
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: rowItem.isCurrent ? sliderTheme.accent : viewTheme.fg.primary
                    }

                    Text {
                        id: durationLabel

                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.dp(4, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.duration.formatHMS()
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: viewTheme.fg.secondary
                    }
                }
            }
        }
    }
}
