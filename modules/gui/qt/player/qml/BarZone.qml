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
import QtQml.Models

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Util

// One zone (left, center or right) of a row of the player control bar or title bar.
//
// Normal mode: the items of the model that the current media supports.
// Customize mode (PlayerCustomizer.editing): every item of the model, inside a dashed
// outline, draggable. The zone registers itself in PlayerCustomizer for drag and drop.
FocusScope {
    id: root

    // Properties

    // key used by PlayerCustomizer ("bar.left", "top.center", ...)
    required property string zoneKey

    // ControlListModel of the zone
    property var controls: null

    // Qt.AlignLeft, Qt.AlignHCenter or Qt.AlignRight: where the items sit in the zone
    property int alignment: Qt.AlignLeft

    // the zone belongs to the title bar
    property bool titleBar: false

    // the zone is the one of the seek bar row
    readonly property bool editing: PlayerCustomizer.editing

    // space reserved to drop an item in an empty zone
    property real editMinimumWidth: VLCStyle.dp(120, VLCStyle.scale)

    // distance around the zone that still counts for a drop
    readonly property real hitMargin: VLCStyle.spacing_8

    // width the items may use (the whole row): items that do not fit are hidden
    property real availableWidth: Number.MAX_VALUE

    // true when one of the items expands (seek bar): the zone then takes the free width
    readonly property bool expanding: {
        void controls?.count
        const list = controls ? controls.getControls() : []
        return list.indexOf(ControlListModel.TIMELINE) !== -1
    }

    // smallest width the items can take (the expanding item at its minimum)
    readonly property real minimumContentWidth: {
        void normalRepeater.count
        let w = 0
        for (let i = 0; i < normalRepeater.count; ++i) {
            const l = normalRepeater.itemAt(i)
            if (l)
                w += Math.max(0, l.Layout.minimumWidth) + Math.max(0, l.Layout.leftMargin)
        }
        return w
    }

    // true if there is no item to show in normal mode
    readonly property bool empty: (controls ? controls.count : 0) === 0

    // width of the content, without the edit mode minimum
    readonly property real contentImplicitWidth: editing ? editRow.implicitWidth : normalRow.implicitWidth

    readonly property bool dropTarget: editing && PlayerCustomizer.dragging && PlayerCustomizer.hoverZone === zoneKey

    property var altFocusAction: function() { return false }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)
    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: editing ? Math.max(editRow.implicitWidth, empty ? editMinimumWidth : 0) : normalRow.implicitWidth
    implicitHeight: Math.max(normalRow.implicitHeight, editRow.implicitHeight)

    Navigation.navigable: !editing && normalRepeater.count > 0

    // Functions

    function acceptsDrop(id) {
        if (zoneKey === "timeline")
            return id === ControlListModel.TIMELINE

        if (id === ControlListModel.TIMELINE)
            return !titleBar

        return true
    }

    // index in the list (the dragged item excluded) where an item dropped at x would land
    function insertIndexFor(x, excludeIndex) {
        let remaining = 0
        for (let i = 0; i < editRepeater.count; ++i) {
            if (i === excludeIndex)
                continue

            const slot = editRepeater.itemAt(i)
            if (!slot)
                continue

            // centre of the slot without the room opened for the dragged item
            const center = editRow.x + slot.x - slot.placeholderRoom + slot.width / 2
            if (x < center)
                return remaining

            ++remaining
        }
        return remaining
    }

    function focusFirst(reason) {
        for (let i = 0; i < normalRepeater.count; ++i) {
            const loader = normalRepeater.itemAt(i)
            if (loader?.item?.focus && loader.visible) {
                loader.item.forceActiveFocus(reason)
                return true
            }
        }
        return false
    }

    function focusLast(reason) {
        for (let i = normalRepeater.count - 1; i >= 0; --i) {
            const loader = normalRepeater.itemAt(i)
            if (loader?.item?.focus && loader.visible) {
                loader.item.forceActiveFocus(reason)
                return true
            }
        }
        return false
    }

    // only the zones that are on screen take part in the customize mode (the player can
    // exist twice, e.g. hidden behind the library)
    Component.onCompleted: { if (visible) PlayerCustomizer.registerZone(zoneKey, root) }
    Component.onDestruction: PlayerCustomizer.unregisterZone(zoneKey, root)

    onVisibleChanged: {
        if (visible)
            PlayerCustomizer.registerZone(zoneKey, root)
        else
            PlayerCustomizer.unregisterZone(zoneKey, root)
    }

    Connections {
        target: root.controls
        function onCountChanged() { PlayerCustomizer.modelChanged() }
        function onRowsMoved() { PlayerCustomizer.modelChanged() }
        function onModelReset() { PlayerCustomizer.modelChanged() }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Normal mode

    RowLayout {
        id: normalRow

        visible: !root.editing
        enabled: !root.editing

        spacing: 0

        // the row is as wide as its content, or as the zone when an item expands
        x: root.expanding ? 0 : ((root.alignment === Qt.AlignRight) ? root.width - width
                                                                    : (root.alignment === Qt.AlignHCenter) ? (root.width - width) / 2 : 0)
        width: root.expanding ? root.width : Math.min(implicitWidth, root.width)
        height: root.height

        ControlRepeater {
            id: normalRepeater

            titleBar: root.titleBar

            model: ControlListFilter {
                sourceModel: root.controls

                player: Player
                ctx: MainCtx
            }

            Navigation.parentItem: root

            availableWidth: root.availableWidth
            availableHeight: normalRow.height

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(root.requestLockUnlockAutoHide)
                menuOpened.connect(root.menuOpened)
                root.forceUnlock.connect(normalRepeater.forceUnlock)
            }
        }
    }

    // Customize mode

    // outline of the zone: shown when empty or while it is a possible target of a drag
    Widgets.DashedBorder {
        anchors.fill: parent

        // (the title bar only shows it while something is dragged, like Figma)
        visible: root.editing && ((root.empty && !root.titleBar) || PlayerCustomizer.dragging)
        opacity: root.dropTarget ? 1.0 : (PlayerCustomizer.dragging ? 0.6 : 1.0)

        color: root.dropTarget ? theme.accent : theme.fg.secondary

        Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
    }

    RowLayout {
        id: editRow

        visible: root.editing

        spacing: 0

        x: root.expanding ? 0 : ((root.alignment === Qt.AlignRight) ? root.width - width
                                                                    : (root.alignment === Qt.AlignHCenter) ? (root.width - width) / 2 : 0)
        width: root.expanding ? root.width : Math.min(implicitWidth, root.width)
        height: root.height

        Repeater {
            id: editRepeater

            model: root.editing ? root.controls : null

            delegate: Item {
                id: slot

                required property int index
                required property var model

                readonly property int controlId: model.id
                readonly property var entry: PlayerControlbarControls.control(controlId)

                readonly property bool isDragSource: PlayerCustomizer.dragging
                                                     && PlayerCustomizer.dragFromZone === root.zoneKey
                                                     && PlayerCustomizer.dragFromIndex === index

                // index of the slot once the dragged one is removed
                readonly property int remainingIndex: (PlayerCustomizer.dragging
                                                       && PlayerCustomizer.dragFromZone === root.zoneKey
                                                       && PlayerCustomizer.dragFromIndex >= 0
                                                       && index > PlayerCustomizer.dragFromIndex) ? index - 1 : index

                readonly property bool placeholderBefore: PlayerCustomizer.dragging
                                                          && PlayerCustomizer.hoverZone === root.zoneKey
                                                          && !isDragSource
                                                          && PlayerCustomizer.hoverIndex === remainingIndex

                readonly property real baseGap: (index > 0) ? PlayerControlbarControls.gap(root.titleBar,
                                                                                            root.controls.data(root.controls.index(index - 1, 0), 256),
                                                                                            controlId)
                                                            : 0

                // room opened in front of the slot for the item that is dragged over
                property real placeholderRoom: placeholderBefore ? (PlayerCustomizer.dragWidth + VLCStyle.spacing_8) : 0

                Behavior on placeholderRoom {
                    NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad }
                }

                // the slot of the dragged item folds away
                property real fold: isDragSource ? 0 : 1

                Behavior on fold {
                    NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad }
                }

                Layout.leftMargin: baseGap * fold + placeholderRoom
                Layout.preferredWidth: content.contentImplicitWidth * fold
                Layout.fillWidth: (content.item?.fillWidth === true)
                Layout.minimumWidth: Layout.fillWidth ? VLCStyle.dp(80, VLCStyle.scale) : Layout.preferredWidth
                Layout.preferredHeight: boxHeight
                Layout.alignment: Qt.AlignVCenter

                readonly property real boxHeight: root.titleBar ? VLCStyle.windowButton_h
                                                               : (entry && (controlId === ControlListModel.TIMELINE || controlId === ControlListModel.VOLUME)
                                                                  ? VLCStyle.dp(36, VLCStyle.scale)
                                                                  : (controlId === ControlListModel.PLAY_BUTTON ? VLCStyle.dp(34, VLCStyle.scale)
                                                                                                              : VLCStyle.windowButton_h))

                opacity: fold

                // drop indicator: where the dragged item will land
                Widgets.DashedBorder {
                    x: -(PlayerCustomizer.dragWidth + VLCStyle.spacing_8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: PlayerCustomizer.dragWidth
                    height: slot.boxHeight

                    visible: slot.placeholderRoom > 1
                    opacity: Math.min(1, slot.placeholderRoom / (PlayerCustomizer.dragWidth + VLCStyle.spacing_8))

                    color: theme.accent
                }

                Loader {
                    id: content

                    anchors.verticalCenter: parent.verticalCenter

                    source: slot.entry.source

                    readonly property real contentImplicitWidth: item ? item.implicitWidth : VLCStyle.windowButton_h

                    width: parent.width
                    height: item ? Math.min(item.implicitHeight, slot.boxHeight) : 0

                    onLoaded: {
                        if (item.paintOnly !== undefined)
                            item.paintOnly = true
                        else
                            item.enabled = false

                        if (item.inTitleBar !== undefined)
                            item.inTitleBar = root.titleBar

                        // same sizes as in the normal mode
                        if (item.keepSize !== true && item.iconName !== undefined && item.iconSize !== undefined) {
                            item.implicitWidth = root.titleBar ? VLCStyle.windowButton_h : VLCStyle.iconButton_w
                            item.implicitHeight = root.titleBar ? VLCStyle.windowButton_h : VLCStyle.iconButton_h
                        }

                        if (item.fillWidth === true || item.Layout.minimumWidth > 0) {
                            item.width = Qt.binding(() => content.width)
                        }
                    }
                }

                Widgets.DashedBorder {
                    anchors.fill: parent
                    anchors.topMargin: -(controlId === ControlListModel.PLAY_BUTTON ? VLCStyle.spacing_2 : 0)
                    anchors.bottomMargin: anchors.topMargin

                    color: theme.fg.secondary
                }

                // grab area on top of the (inactive) item
                MouseArea {
                    id: grab

                    anchors.fill: parent

                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: PlayerCustomizer.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property point pressPoint

                    onPressed: (mouse) => {
                        pressPoint = Qt.point(mouse.x, mouse.y)
                        PlayerCustomizer.dragAborted = false
                    }

                    onPositionChanged: (mouse) => {
                        const p = grab.mapToItem(null, mouse.x, mouse.y)
                        if (PlayerCustomizer.dragging) {
                            PlayerCustomizer.updateDrag(p.x, p.y)
                        } else if (pressed && Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) > VLCStyle.dp(4, VLCStyle.scale)) {
                            PlayerCustomizer.beginDrag(slot.controlId, root.zoneKey, slot.index, p.x, p.y,
                                                       Math.max(slot.width, VLCStyle.windowButton_h), slot.boxHeight)
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
        }

        // room at the end of the zone for the dragged item
        Item {
            id: trailing

            readonly property bool active: PlayerCustomizer.dragging
                                           && PlayerCustomizer.hoverZone === root.zoneKey
                                           && PlayerCustomizer.hoverIndex >= (editRepeater.count - (PlayerCustomizer.dragFromZone === root.zoneKey ? 1 : 0))

            property real room: active ? (PlayerCustomizer.dragWidth + VLCStyle.spacing_8) : 0

            Behavior on room {
                NumberAnimation { duration: VLCStyle.duration_short; easing.type: Easing.OutQuad }
            }

            Layout.preferredWidth: room
            Layout.preferredHeight: 1
            Layout.alignment: Qt.AlignVCenter

            Widgets.DashedBorder {
                x: VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                width: PlayerCustomizer.dragWidth
                height: VLCStyle.windowButton_h

                visible: trailing.room > 1
                opacity: Math.min(1, trailing.room / (PlayerCustomizer.dragWidth + VLCStyle.spacing_8))

                color: theme.accent
            }
        }
    }
}
