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

import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQml.Models


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Util

// Player control bar (Figma 491:1928): 54 high per row, padding 20 x 11.
//
// Driven by the PlayerControlbarModel of the current profile (left, center, right lists).
// Default profile (see ControlbarProfile::builtinLayout), one row:
//
//  [prev][ PLAY ][next]  [00:02:10 |=====seek=====| 00:25:40]  [vol ◢]  [audio][subs][settings]  [queue]
//
// A profile without the seek bar item shows the seek bar in a row of its own above the items.
//
T.Pane {
    id: root

    // Properties

    property int identifier: -1

    property var menu: undefined

    // extra margins (safe area) added to the paddings
    property real sideMargin: 0
    property real bottomMargin: 0

    // true when the bar floats over the video (fullscreen): translucent surface + top border
    property bool overlay: false

    property real backgroundOpacity: 1.0

    // music player: translucent tinted surface over the cover backdrop
    property bool frosted: false

    // translucency of the frosted surface (same in every colour scheme)
    readonly property real frostedAlpha: 0.36

    property bool playlistVisible: false


    // For now, used for d&d functionality of the queue button
    property Item plListView

    // y of the bar top relative to the bar (anchor of popups placed above the bar)
    readonly property real sliderY: 0

    // slider of the seek bar item (tracked by TimelineWidget)
    property Item trackPositionSlider: null

    // PlayerControlbarModel of the player of this bar, left/center/right lists
    readonly property var model: {
        const profile = MainCtx.controlbarProfileModel.currentModel
        return profile ? profile.ensureModel(root.identifier) : null
    }

    // the seek bar has its own row (the profile has no seek bar item)
    readonly property bool stacked: !barRow.inline

    readonly property bool editing: PlayerCustomizer.editing

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal togglePlaylistVisibility()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    // height once the timeline row has finished its show/hide animation
    readonly property real settledHeight: implicitHeight - timelineRow.height + (timelineRow.shown ? VLCStyle.iconButton_h : 0)

    leftPadding: VLCStyle.spacing_20 + sideMargin
    rightPadding: VLCStyle.spacing_20 + sideMargin
    topPadding: VLCStyle.dp(11, VLCStyle.scale)
    bottomPadding: VLCStyle.dp(11, VLCStyle.scale) + bottomMargin

    enabled: visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)
    Navigation.cancelAction: function() { History.previous(Qt.BacktabFocusReason) }

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    function showChapterMarks() {
        trackPositionSlider.showChapterMarks()
    }

    function applyMenu(menu) {
        if (root.menu === menu)
            return

        // NOTE: When applying a new menu we hide the previous one.
        if (menu)
            dismiss()

        root.menu = menu
    }

    function dismiss() {
        if ((typeof menu === undefined) || !menu)
            return
        if (menu.hasOwnProperty("dismiss"))
            menu.dismiss()
        else if (menu.hasOwnProperty("close"))
            menu.close()
    }

    function registerTimeline(slider) {
        root.trackPositionSlider = slider
    }

    function unregisterTimeline(slider) {
        if (root.trackPositionSlider === slider)
            root.trackPositionSlider = null
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    background: Rectangle {
        color: root.frosted ? Qt.alpha(theme.bg.primary, root.frostedAlpha)
                            : (root.overlay ? theme.bg.secondary : theme.bg.primary)
        opacity: (root.overlay && !root.frosted) ? root.backgroundOpacity * 0.95 : root.backgroundOpacity

        Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }

        Rectangle {
            visible: root.overlay || root.frosted

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: VLCStyle.dp(1, VLCStyle.scale)

            color: theme.border
        }
    }

    contentItem: Column {
        id: column

        spacing: VLCStyle.dp(22, VLCStyle.scale)

        // Seek bar row, when the profile has no seek bar item
        Item {
            id: timelineRow

            readonly property bool shown: root.stacked
                                          || (root.editing && PlayerCustomizer.dragging
                                              && PlayerCustomizer.dragId === ControlListModel.TIMELINE)

            // PlayerCustomizer zone interface
            readonly property var controls: null
            readonly property real hitMargin: VLCStyle.spacing_8
            function acceptsDrop(id) { return id === ControlListModel.TIMELINE }
            function insertIndexFor(x, exclude) { return 0 }

            readonly property bool dropTarget: root.editing && PlayerCustomizer.dragging && PlayerCustomizer.hoverZone === "timeline"

            width: parent.width
            height: shown ? VLCStyle.iconButton_h : 0
            visible: height > 0
            clip: true

            Behavior on height {
                NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad }
            }

            readonly property bool _onScreen: root.visible && visible

            Component.onCompleted: { if (root.visible) PlayerCustomizer.registerZone("timeline", timelineRow) }
            Component.onDestruction: PlayerCustomizer.unregisterZone("timeline", timelineRow)

            Connections {
                target: root

                function onVisibleChanged() {
                    if (root.visible)
                        PlayerCustomizer.registerZone("timeline", timelineRow)
                    else
                        PlayerCustomizer.unregisterZone("timeline", timelineRow)
                }
            }

            Loader {
                id: stackedTimeline

                anchors.fill: parent

                active: root.stacked
                focus: true

                source: "qrc:///qt/qml/VLC/PlayerControls/TimelineWidget.qml"

                opacity: (root.editing && PlayerCustomizer.dragging && PlayerCustomizer.dragFromZone === "timeline") ? 0.3 : 1.0

                onLoaded: {
                    item.paintOnly = Qt.binding(() => root.editing)
                    item.Navigation.parentItem = root
                    item.Navigation.downItem = barRow
                }
            }

            // customize mode: outline and grab area
            Widgets.DashedBorder {
                anchors.fill: parent

                visible: root.editing
                color: timelineRow.dropTarget ? theme.accent : theme.fg.secondary
            }

            MouseArea {
                anchors.fill: parent

                enabled: root.editing && root.stacked

                hoverEnabled: true
                preventStealing: true
                cursorShape: PlayerCustomizer.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property point pressPoint

                onPressed: (mouse) => {
                        pressPoint = Qt.point(mouse.x, mouse.y)
                        PlayerCustomizer.dragAborted = false
                    }

                onPositionChanged: (mouse) => {
                    const p = mapToItem(null, mouse.x, mouse.y)
                    if (PlayerCustomizer.dragging) {
                        PlayerCustomizer.updateDrag(p.x, p.y)
                    } else if (pressed && Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) > VLCStyle.dp(4, VLCStyle.scale)) {
                        PlayerCustomizer.beginDrag(ControlListModel.TIMELINE, "timeline", 0, p.x, p.y,
                                                   VLCStyle.dp(240, VLCStyle.scale), VLCStyle.dp(36, VLCStyle.scale))
                    }
                }

                onReleased: {
                    if (PlayerCustomizer.dragging)
                        PlayerCustomizer.endDrag()
                }

                onCanceled: {
                    if (PlayerCustomizer.dragging)
                        PlayerCustomizer.cancelDrag()
                }
            }
        }

        BarRow {
            id: barRow

            width: parent.width
            height: VLCStyle.iconButton_h

            keyPrefix: "bar"
            model: root.model

            focus: true

            Navigation.parentItem: root
            Navigation.upItem: stackedTimeline.item

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: root.forceUnlock.connect(barRow.forceUnlock)
        }
    }
}
