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
import QtQml.Models
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.PlayerControls
import VLC.Dialogs
import VLC.Menus as Menus
import VLC.Util

FocusScope {
    id: rootPlayer

    // Properties

    //behave like a Page
    property var pagePrefix: []

    readonly property int positionSliderY: controlBar.y + controlBar.sliderY

    readonly property string coverSource: {
        if (Player.artwork &&
            Player.artwork.toString())
            return Player.artwork
        else if (Player.hasVideoOutput)
            return VLCStyle.noArtVideoCover
        else
            return VLCStyle.noArtAlbumCover
    }

    // Only applicable in video mode:
    // (the redesigned chrome uses opaque/translucent bars instead of gradient scrims)
    property bool displayFadeRectangles: false
    property real implicitFadeRectangleHeight: VLCStyle.dp(206, VLCStyle.scale)

    // Hide-UI mode (Ctrl+\): title bar, control bar and sidebar are hidden until toggled again
    readonly property bool hideUI: playerToolbarVisibilityFSM.isHiddenAll

    // Library sidebar (Figma 187:328): the layout slot is reserved here, W7 provides the content
    property bool sidebarVisible: false
    readonly property real sidebarWidth: Math.max(0, sidebarLoader.x + sidebarLoader.width)

    // Private

    readonly property bool _fullscreen: (MainCtx.intfMainWindow.visibility === Window.FullScreen)

    // The chrome (title bar, control bar) takes room around the video, like the Figma layout.
    // In fullscreen the bars float over the video and auto-hide on mouse idle.
    property bool _controlsUnderVideo: !_fullscreen && !hideUI

    // 10px rim around the video, with rounded corners (windowed, video only)
    readonly property bool _showRim: !_fullscreen && MainCtx.hasEmbededVideo
    readonly property real _rim: _showRim ? VLCStyle.viewport_inset : 0

    // video viewport insets
    readonly property real _videoLeftInset: Math.max(_rim, sidebarWidth)
    readonly property real _videoRightInset: _rim
    readonly property real _videoTopInset: _controlsUnderVideo ? topBar.height : _rim
    readonly property real _videoBottomInset: _controlsUnderVideo ? controlBar.height : _rim

    property bool _keyPressed: false

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Player")
    AccessibleCompat.id: "playerView"

    // Events

    Component.onCompleted: MainCtx.preferHotkeys = true
    Component.onDestruction: MainCtx.preferHotkeys = false

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.accepted)
            return

        _keyPressed = true

        rootPlayer.Navigation.defaultKeyAction(event)

        //unhandled keys are forwarded as hotkeys
        if (!event.accepted || controlBar.state !== "visible")
            MainCtx.sendHotkey(event.key, event.modifiers);
    }

    Keys.onReleased: (event) => {
        if (event.accepted || _keyPressed === false)
            return

        _keyPressed = false

        rootPlayer.Navigation.defaultKeyReleaseAction(event)
    }

    on_ControlsUnderVideoChanged: {
        lockUnlockAutoHide(_controlsUnderVideo)
    }

    // Functions

    function lockUnlockAutoHide(lock) {
        if (lock) {
            playerToolbarVisibilityFSM.lock()
        } else {
            playerToolbarVisibilityFSM.unlock()
        }
    }

    // Private

    function _onNavigationCancel() {
        if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
            MainPlaylistController.stop()
        }

        History.previous()
    }

    //we draw both the view and the window here
    ColorContext {
        id: windowTheme

        // NOTE: We force the night theme when playing a video.
        // NOTE: the video overlay (fullscreen) forces the night theme; docked chrome follows the user theme.
        palette: (MainCtx.hasEmbededVideo && !_controlsUnderVideo && !hideUI)
                 ? VLCStyle.darkPalette
                 : VLCStyle.palette

        colorSet: ColorContext.Window
    }

    PlayerToolbarVisibilityFSM {
        id: playerToolbarVisibilityFSM

        onForceUnlock:{
            controlBar.forceUnlock()

            topBar.forceUnlock()
        }
    }

    PlayerPlaylistVisibilityFSM {
        id: playlistVisibility

        onIsPlaylistVisibleChanged: lockUnlockAutoHide(isPlaylistVisible)
    }

    Connections {
        target: MainCtx

        //playlist
        function onHasEmbededVideoChanged() {
            playlistVisibility.updateVideoEmbed()
            playerToolbarVisibilityFSM.updateVideoEmbed()
        }
        function onAskShow() {
            playerToolbarVisibilityFSM.askShow()
        }
    }


    Connections {
        target: MainCtx.playqueuePanel

        //playlist
        function onDockedChanged() {
            playlistVisibility.updatePlaylistDocked()
        }
        function onVisibleChanged() {
            playlistVisibility.updatePlaylistVisible()
        }
    }


    Loader {
        id: playerSpecializationLoader

        objectName: "playerSpecializationLoader"

        // Video: inset rectangle between the bars (10px rim, rounded corners). Audio: full bleed.
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom

            leftMargin: MainCtx.hasEmbededVideo ? rootPlayer._videoLeftInset : 0
            rightMargin: MainCtx.hasEmbededVideo ? rootPlayer._videoRightInset : 0
            topMargin: MainCtx.hasEmbededVideo ? rootPlayer._videoTopInset : 0
            bottomMargin: MainCtx.hasEmbededVideo ? rootPlayer._videoBottomInset : 0
        }

        Behavior on anchors.leftMargin {
            enabled: playerToolbarVisibilityFSM.started
            NumberAnimation {
                duration: VLCStyle.duration_long
                easing.type: Easing.InOutSine
            }
        }

        Behavior on anchors.rightMargin {
            enabled: playerToolbarVisibilityFSM.started
            NumberAnimation {
                duration: VLCStyle.duration_long
                easing.type: Easing.InOutSine
            }
        }

        Behavior on anchors.topMargin {
            enabled: playerToolbarVisibilityFSM.started
            NumberAnimation {
                duration: VLCStyle.duration_long
                easing.type: Easing.InOutSine
            }
        }

        Behavior on anchors.bottomMargin {
            enabled: playerToolbarVisibilityFSM.started
            NumberAnimation {
                duration: VLCStyle.duration_long
                easing.type: Easing.InOutSine
            }
        }

        sourceComponent: MainCtx.hasEmbededVideo ? videoComponent : audioComponent

        property int cursorShape

        // Have padding here, so that the content (unlike background) does not go behind the top bar or the control bar:
        property real topPadding: (MainCtx.hasEmbededVideo || rootPlayer.hideUI) ? 0 : topBar.height
        property real bottomPadding: (MainCtx.hasEmbededVideo || rootPlayer.hideUI) ? 0 : controlBar.height

        component TouchDragHandler : DragHandler {
            id: touchDragHandler

            acceptedDevices: PointerDevice.TouchScreen

            minimumPointCount: 1
            maximumPointCount: 1

            target: null

            dragThreshold: VLCStyle.margin_normal

            property vector2d lastActiveTranslation

            // TODO: Use `createComponent()` and load directly from module instead, since
            //       it is pointless to keep the `QQmlComponent` around for this object.
            readonly property Component wheelToVLCConverterComponent: Component { WheelToVLCConverter { } }

            property WheelToVLCConverter wheelToVLCConverter

            // We synthesize wheel event with pixel delta. It is a to-do to handle
            // touch properly with precision adjustment, like on Android:
            onActiveTranslationChanged: {
                if (active) {
                    console.assert(wheelToVLCConverter)

                    const delta = Qt.point(activeTranslation.x - lastActiveTranslation.x,
                                           activeTranslation.y - lastActiveTranslation.y)

                    // WheelToVLCConverter can not handle sole pixel delta now, so we also
                    // use angle delta. This is similar to wheel events on some platforms:
                    wheelToVLCConverter.customWheelEvent(delta,
                                                         delta,
                                                         Qt.NoButton,
                                                         Qt.NoModifier,
                                                         true)

                    lastActiveTranslation = activeTranslation
                }
            }

            onActiveChanged: {
                if (active) {
                    if (!wheelToVLCConverter) {
                        wheelToVLCConverter = wheelToVLCConverterComponent.createObject(touchDragHandler)
                        wheelToVLCConverter.vlcWheelKey.connect(MainCtx, MainCtx.sendVLCHotkey)
                    }
                } else {
                    lastActiveTranslation = Qt.vector2d(0, 0)
                }
            }
        }

        Component {
            id: videoComponent

            FocusScope {
                // Video

                focus: true

                VideoSurface {
                    id: videoSurface

                    anchors.fill: parent

                    // With regard to `ViewBlockingRectangle`, we
                    // do not need to prevent painting anything
                    // behind because there is already nothing
                    // behind (unlike pip player):
                    renderingEnabled: false

                    videoSurfaceProvider: MainCtx.videoSurfaceProvider

                    visible: MainCtx.hasEmbededVideo

                    focus: true

                    cursorShape: playerSpecializationLoader.cursorShape

                    function onMouseEvent() {
                        //short interval for mouse events
                        if (Player.isInteractive)
                            interactiveAutoHideTimer.restart()
                        else
                            playerToolbarVisibilityFSM.mouseMove();
                    }

                    Component.onCompleted: {
                        mouseMoved.connect(videoSurface.onMouseEvent)
                        mousePressed.connect(videoSurface.onMouseEvent)
                        mouseReleased.connect(videoSurface.onMouseEvent)
                        mouseDblClicked.connect(videoSurface.onMouseEvent)
                    }

                    Binding on cursorShape {
                        when: playerToolbarVisibilityFSM.started
                            && !playerToolbarVisibilityFSM.isVisible
                            && !interactiveAutoHideTimer.running
                        value: Qt.BlankCursor
                    }

                    TouchDragHandler {

                    }
                }

                component FadeRectangle : Rectangle {
                    implicitHeight: rootPlayer.implicitFadeRectangleHeight

                    SGManipulator {
                        // The rectangle is the bottom-most item in the interface,
                        // it does not need blending even though it is not opaque.
                        // Since `Rectangle` does not provide explicit control over
                        // blending, we are using `SGManipulator`:
                        blending: false
                    }
                }

                FadeRectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: topBar.opacity
                    visible: rootPlayer.displayFadeRectangles

                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                FadeRectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: controlBar.opacity

                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: .64; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "black" }
                    }

                    visible: rootPlayer.displayFadeRectangles && !(controlBar.background && controlBar.background.visible)
                }
            }
        }

        Component {
            id: audioComponent

            FocusScope {
                id: audioFocusScope

                focus: true

                // wheel (volume/seek) and touch drag handling, the music view is drawn above
                MouseArea {
                    id: centerContent

                    anchors.fill: parent

                    onWheel: (wheel) => {
                        wheel.accepted = true
                        wheelToVlc.qmlWheelEvent(wheel)
                    }

                    TouchDragHandler {
                        wheelToVLCConverter: wheelToVlc
                    }

                    WheelToVLCConverter {
                        id: wheelToVlc

                        onVlcWheelKey: (key) => MainCtx.sendVLCHotkey(key)
                    }
                }

                MusicView {
                    id: musicView

                    anchors.fill: parent

                    focus: true

                    topPadding: playerSpecializationLoader.topPadding
                    bottomPadding: playerSpecializationLoader.bottomPadding
                    leftInset: rootPlayer.sidebarWidth

                    coverSource: rootPlayer.coverSource

                    Navigation.parentItem: rootPlayer
                    Navigation.upItem: topBar
                    Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
                }
            }
        }
    }

    // Rounded corners of the video viewport (Figma: 10px visible radius). The area outside of the
    // rounded rectangle is painted with the window colour, over the video.
    Item {
        id: viewportFrame

        anchors.fill: playerSpecializationLoader
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        anchors.topMargin: -1
        anchors.bottomMargin: -1

        visible: rootPlayer._showRim && MainCtx.hasEmbededVideo

        // radius of the left corners shrinks to 0 while the sidebar docks against the video
        readonly property real _leftRadius: Math.max(0, VLCStyle.viewport_radius - Math.max(0, rootPlayer.sidebarWidth - VLCStyle.viewport_inset))
        readonly property real _rightRadius: VLCStyle.viewport_radius
        readonly property real _bottomRadius: VLCStyle.viewport_radius

        function _path(w, h, tl, tr, br, bl) {
            // outer rectangle, then the rounded rectangle: odd-even fill leaves the corners
            return "M0 0H" + w + "V" + h + "H0Z"
                 + "M" + (tl + 1) + " 1"
                 + "H" + (w - 1 - tr)
                 + "A" + tr + " " + tr + " 0 0 1 " + (w - 1) + " " + (1 + tr)
                 + "V" + (h - 1 - br)
                 + "A" + br + " " + br + " 0 0 1 " + (w - 1 - br) + " " + (h - 1)
                 + "H" + (bl + 1)
                 + "A" + bl + " " + bl + " 0 0 1 1 " + (h - 1 - bl)
                 + "V" + (1 + tl)
                 + "A" + tl + " " + tl + " 0 0 1 " + (tl + 1) + " 1Z"
        }

        Shape {
            anchors.fill: parent

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: windowTheme.bg.primary
                fillRule: ShapePath.OddEvenFill

                PathSvg {
                    path: viewportFrame._path(viewportFrame.width, viewportFrame.height,
                                              viewportFrame._leftRadius,
                                              viewportFrame._rightRadius,
                                              viewportFrame._bottomRadius,
                                              viewportFrame._leftRadius)
                }
            }
        }
    }

    // Sidebar slot (Figma 187:328): rail (50) + panel (377), docked against the video.
    // The content is the library sidebar (icon rail + panels).
    Loader {
        id: sidebarLoader

        x: (rootPlayer.sidebarVisible && rootPlayer._controlsUnderVideo) ? 0 : -width
        y: topBar.height
        width: VLCStyle.sidebarRail_w + VLCStyle.sidebarPanel_w
        height: controlBar.y - y

        // keep the item while it slides out
        active: rootPlayer.sidebarVisible || (x + width > 0)
        visible: x + width > 0

        sourceComponent: sidebarComponent

        Behavior on x {
            enabled: playerToolbarVisibilityFSM.started
            NumberAnimation {
                duration: VLCStyle.duration_long
                easing.type: Easing.InOutSine
            }
        }
    }

    Component {
        id: sidebarComponent

        LibrarySidebar {
            onOpenLibraryRequested: (path) => {
                MainCtx.playerView = false
                if (path && path.length > 0)
                    History.push(path)
            }
        }
    }

    TopBar {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        z: 1

        topMargin: VLCStyle.applicationVerticalMargin
        sideMargin: VLCStyle.applicationHorizontalMargin

        focus: true
        title: Player.title !== "" ? Player.title : qsTr("VLC Media Player")

        pinControls: false

        showCSD: MainCtx.clientSideDecoration
        showToolbar: MainCtx.hasToolbarMenu && !rootPlayer._fullscreen
        playlistVisible: playlistVisibility.isPlaylistVisible
        sidebarVisible: rootPlayer.sidebarVisible

        // translucent over the video in fullscreen, opaque otherwise
        backgroundOpacity: (rootPlayer._fullscreen && MainCtx.hasEmbededVideo) ? MainCtx.pinOpacity : 1.0

        plListView: {
            if (playlistpopup.active)
                return playlistpopup.item
            else if (playlistWindowLoader?.status === Loader.Ready)
                return playlistWindowLoader.item.playlistView
            else
                return null
        }

        Navigation.parentItem: rootPlayer
        Navigation.downItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            if (Player.isInteractive)
                return toggleControlBarButton
            return controlBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: (!rootPlayer.hideUI && (playerToolbarVisibilityFSM.isVisible || rootPlayer._controlsUnderVideo)) ? "visible" : "hidden"
        }

        onSidebarToggleRequested: rootPlayer.sidebarVisible = !rootPlayer.sidebarVisible

        onRequestLockUnlockAutoHide: (lock) => {
            rootPlayer.lockUnlockAutoHide(lock)
        }

        onBackRequested: {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
               MainPlaylistController.stop()
            }
            MainCtx.playerView = false
        }

        FadeControllerStateGroup {
            target: topBar
        }
    }

    Loader {
        id: playlistpopup

        anchors {
            // NOTE: When the controls are pinned we display the playqueue under the topBar.
            top: (rootPlayer._controlsUnderVideo) ? topBar.bottom
                                                  : parent.top

            right: parent.right
            bottom: parent.bottom

            bottomMargin: parent.height - rootPlayer.positionSliderY
        }

        focus: false

        active: MainCtx.playqueuePanel.docked

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playlistVisibility.started
            value: (status === Loader.Ready && playlistVisibility.isPlaylistVisible) ? "expanded" : "retracted"
        }

        Component.onCompleted: {
            Qt.callLater(() => { playlistTransition.enabled = true; })
        }

        states: [
            State {
                name: "expanded"
                PropertyChanges {
                    target: playlistpopup
                    width: playlistpopup.implicitWidth
                    visible: true
                }
           }, State {
                name: "retracted"
                PropertyChanges {
                    target: playlistpopup
                    width: 0
                    visible: false
                }
           }
        ]

        transitions: Transition {
            id: playlistTransition
            enabled: false

            from: "retracted"; to: "expanded";
            reversible: true

            SequentialAnimation {
                PropertyAction { property: "visible" }

                NumberAnimation {
                    property: "width"
                    duration: VLCStyle.duration_short
                    easing.type: Easing.InOutSine
                }
            }
        }

        sourceComponent: PlaylistPane {
            id: playlistView

            property real maximumWidth: (rootPlayer.width + playlistView.rightPadding) / 2

            implicitWidth: Helpers.clamp(MainCtx.playqueuePanel.width
                                 , playlistView.minimumWidth
                                 , playlistView.maximumWidth)
            height: playlistpopup.height

            useAcrylic: false
            focus: true

            wheelEnabled: true

            rightPadding: VLCStyle.applicationHorizontalMargin
            topPadding:  {
                if (rootPlayer._controlsUnderVideo)
                    return VLCStyle.margin_normal
                else
                    // NOTE: We increase the padding accordingly to avoid overlapping the TopBar.
                    return topBar.reservedHeight
            }
            bottomPadding: 0

            background: Rectangle {
                color: windowTheme.bg.primary.alpha(0.8)
            }

            view.fadingEdge.pixelAlignedForDPR: !controlBar.visible

            Navigation.parentItem: rootPlayer
            Navigation.upItem: topBar
            Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
            Navigation.leftAction: closePlaylist
            Navigation.cancelAction: closePlaylist

            function closePlaylist() {
                playlistVisibility.togglePlaylistVisibility()
                controlBar.forceActiveFocus()
            }


            Widgets.HorizontalResizeHandle {
                id: resizeHandle

                property bool _inhibitMainCtxUpdate: false

                parent: playlistView

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }

                atRight: false
                currentWidth: playlistpopup.width

                maximumWidth: playlistView.maximumWidth
                minimumWidth: playlistView.minimumWidth

                onRequestedWidthChanged: {
                    if (!_inhibitMainCtxUpdate)
                        MainCtx.playqueuePanel.width = requestedWidth
                }

                Component.onCompleted:  _updateFromMainCtx()

                function _updateFromMainCtx() {
                    if (requestedWidth === MainCtx.playqueuePanel.width)
                        return

                    _inhibitMainCtxUpdate = true
                    requestedWidth = MainCtx.playqueuePanel.width
                    _inhibitMainCtxUpdate = false
                }

                Connections {
                    target: MainCtx.playqueuePanel

                    function onWidthChanged() {
                        resizeHandle._updateFromMainCtx()
                    }
                }
            }
        }
    }

    Dialogs {
        z: 10
        bgContent: rootPlayer

        anchors {
            bottom: controlBar.visible ? controlBar.top : rootPlayer.bottom
            left: parent.left
            right: parent.right

            bottomMargin: (rootPlayer._controlsUnderVideo || !controlBar.visible)
                          ? 0 : - VLCStyle.margin_large
        }
    }

    Timer {
        // NavigationBox's visibility depends on this timer
        id: interactiveAutoHideTimer
        running: false
        repeat: false
        interval: 3000
    }

    NavigationBox {
        id: navBox
        visible: Player.isInteractive && navBox.show
                    && (interactiveAutoHideTimer.running
                    || navBox.hovered || !MainCtx.hasEmbededVideo)

        x: rootPlayer.x + VLCStyle.margin_normal + VLCStyle.applicationHorizontalMargin
        y: controlBar.y - navBox.height - VLCStyle.margin_normal

        dragXMin: 0
        dragXMax: rootPlayer.width - navBox.width
        dragYMin: 0
        dragYMax: rootPlayer.height - navBox.height

        Drag.onDragStarted: (controlId) => {
            navBox.x = drag.x
            navBox.y = drag.y
        }
    }

    Connections {
        target: MainCtx
        function onNavBoxToggled() { interactiveAutoHideTimer.restart() }
    }

    Connections {
        target: rootPlayer
        function onWidthChanged() {
            if (navBox.x > navBox.dragXMax)
                navBox.x = navBox.dragXMax
        }
        function onHeightChanged() {
            if (navBox.y > navBox.dragYMax)
                navBox.y = navBox.dragYMax
        }
    }

    Widgets.ButtonExt {
        id: toggleControlBarButton
        visible: Player.isInteractive
                 && MainCtx.hasEmbededVideo
                 && !rootPlayer._controlsUnderVideo
                 && (interactiveAutoHideTimer.running === true
                     || controlBar.state !== "hidden" || toggleControlBarButton.hovered)
        focus: true
        anchors {
            bottom: controlBar.state === "hidden" ? parent.bottom : controlBar.top
            horizontalCenter: parent.horizontalCenter
        }
        iconSize: VLCStyle.icon_large
        iconTxt: controlBar.state === "hidden" ? VLCIcons.expand_inverted : VLCIcons.expand

        Navigation.parentItem: rootPlayer
        Navigation.upItem: playlistVisibility.isPlaylistVisible ? playlistpopup : (MainCtx.hasEmbededVideo ? playerSpecializationLoader : topBar)
        Navigation.downItem: controlBar

        onClicked:{
            playerToolbarVisibilityFSM.askShow();
        }
    }

    Widgets.FloatingNotification {
        id: notif

        anchors {
            bottom: controlBar.top
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    ControlBar {
        id: controlBar

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        hoverEnabled: true

        focus: true

        sideMargin: VLCStyle.applicationHorizontalMargin
        bottomMargin: VLCStyle.applicationVerticalMargin

        // docked: opaque bar below the video; fullscreen: translucent bar over the video
        overlay: !rootPlayer._controlsUnderVideo
        backgroundOpacity: (rootPlayer._fullscreen && MainCtx.hasEmbededVideo) ? MainCtx.pinOpacity : 1.0

        playlistVisible: playlistVisibility.isPlaylistVisible
        plListView: topBar.plListView

        onStateChanged: {
            if (state === "visible")
                showChapterMarks()
        }

        Navigation.parentItem: rootPlayer
        Navigation.upItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (Player.isInteractive)
                return toggleControlBarButton
            if (!MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            return topBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: (!rootPlayer.hideUI && (playerToolbarVisibilityFSM.isVisible || rootPlayer._controlsUnderVideo)) ? "visible" : "hidden"
        }

        onRequestLockUnlockAutoHide: (lock) => rootPlayer.lockUnlockAutoHide(lock)

        onTogglePlaylistVisibility: playlistVisibility.togglePlaylistVisibility()

        identifier: (Player.hasVideoOutput) ? PlayerControlbarModel.Videoplayer
                                            : PlayerControlbarModel.Audioplayer

        onHoveredChanged: rootPlayer.lockUnlockAutoHide(hovered)

        FadeControllerStateGroup {
            target: controlBar
        }
    }

    // State and requests of the items of the title bar / control bar (see PlayerHost)
    Binding { target: PlayerHost; property: "playlistVisible"; value: playlistVisibility.isPlaylistVisible }
    Binding { target: PlayerHost; property: "plListView"; value: topBar.plListView }

    Connections {
        target: PlayerHost

        function onToggleQueue() {
            playlistVisibility.togglePlaylistVisibility()
        }
    }

    // Customize Player (modal box over the video, the bars are edited live)
    Loader {
        id: customizeLoader

        anchors.top: topBar.bottom
        anchors.bottom: controlBar.top
        anchors.left: parent.left
        anchors.right: parent.right

        z: 100

        active: PlayerCustomizer.requested || PlayerCustomizer.editing
        source: "qrc:///qt/qml/VLC/Dialogs/PlayerCustomizeOverlay.qml"

        focus: active

        onLoaded: item.forceActiveFocus()
    }

    Connections {
        target: PlayerCustomizer

        // keep the bars on screen while they are edited
        function onEditingChanged() {
            rootPlayer.lockUnlockAutoHide(PlayerCustomizer.editing)
        }
    }

    // Hide-UI mode: hides the title bar, the control bar and the sidebar until toggled again
    Menus.ShortcutExt {
        context: Qt.WindowShortcut
        sequence: "Ctrl+\\"
        onActivated: playerToolbarVisibilityFSM.toggleHideAll()
    }

    // right-click menu "Hide UI" entry
    Connections {
        target: MainCtx

        function onToggleHideUIRequested() {
            playerToolbarVisibilityFSM.toggleHideAll()
        }
    }


    QmlAudioContextMenu {
        id: audioContextMenu

        ctx: MainCtx
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !MainCtx.hasEmbededVideo

        onTapped: (eventPoint, button) => {
            if (button & Qt.RightButton) {
                audioContextMenu.popup(eventPoint.globalPosition)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        propagateComposedEvents: true
        cursorShape: undefined
        onClicked: {
            MainCtx.playerView = false
        }
    }

    //filter key events to keep toolbar
    //visible when user navigates within the control bar
    KeyEventFilter {
    id: filter
    target: MainCtx.intfMainWindow

        Keys.onPressed: (event) => {
            if (Player.isInteractive)
                interactiveAutoHideTimer.restart()
            else
                playerToolbarVisibilityFSM.keyboardMove()
        }
    }
}
