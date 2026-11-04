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

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Util

// A row of the player window made of three zones (left, center, right) driven by a
// PlayerControlbarModel: used by the control bar and by the title bar.
//
// When one of the zones holds an item that expands (the seek bar), the zones are laid out
// side by side and the expanding zone takes the free space (default control bar).
// Otherwise the left items stick to the left, the right ones to the right and the center
// ones are centered in the row.
FocusScope {
    id: root

    // Properties

    // PlayerControlbarModel (left, center, right ControlListModel)
    property var model: null

    // "bar" or "top"
    required property string keyPrefix

    readonly property bool titleBar: (keyPrefix === "top")

    // space between two zones
    property real zoneSpacing: titleBar ? VLCStyle.spacing_12 : VLCStyle.spacing_20

    readonly property bool inline: left.expanding || center.expanding || right.expanding

    readonly property bool editing: PlayerCustomizer.editing

    // room kept free at the left of the left zone (the VLC cone of the title bar)
    property real leftInset: 0

    property alias leftZone: left
    property alias centerZone: center
    property alias rightZone: right

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)
    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: leftInset + left.implicitWidth + center.implicitWidth + right.implicitWidth + zoneSpacing * 2
    implicitHeight: Math.max(left.implicitHeight, center.implicitHeight, right.implicitHeight)

    Accessible.role: Accessible.Pane

    // Geometry of the zones

    readonly property real _leftW: left.implicitWidth
    readonly property real _rightW: right.implicitWidth
    readonly property real _centerW: center.implicitWidth

    // gap between two zones, only when both have something to show
    function _gap(a, b) {
        return (a.width > 0 && b.width > 0) ? zoneSpacing : 0
    }

    // same for widths (the x of a zone must not read the width of the zone itself: that made a
    // binding loop that left the centre zone at x = 0, on top of the left one)
    function _gapW(wa, wb) {
        return (wa > 0 && wb > 0) ? zoneSpacing : 0
    }

    // Inline layout (zones side by side, one of them expands): the expanding zone always keeps
    // at least its minimum width, the other zones share what is left in the order left, center,
    // right. What does not fit in a zone is hidden by the zone itself (items too far right of the
    // zone are hidden, see ControlRepeater), so the seek bar never collapses under the other items.
    readonly property real _expMin: left.expanding ? left.minimumContentWidth
                                                   : (center.expanding ? center.minimumContentWidth
                                                                       : (right.expanding ? right.minimumContentWidth : 0))

    function _zoneUsed(zone, cap) {
        return (zone.expanding || cap > 0) ? 1 : 0
    }

    // width kept for the non expanding zones, gaps excluded
    readonly property real _room: Math.max(0, width - leftInset - _expMin - 2 * zoneSpacing)

    // (the full width of a zone counts, whether its items are hidden or not: hidden items
    // leave the zone's implicit width, which would shrink the zone again and hide more of them)
    readonly property real _capL: left.expanding ? 0 : Math.min(left.minimumContentWidth, _room)
    readonly property real _capC: center.expanding ? 0 : Math.min(center.minimumContentWidth, Math.max(0, _room - _capL))
    readonly property real _capR: right.expanding ? 0 : Math.min(right.minimumContentWidth, Math.max(0, _room - _capL - _capC))

    // gaps between the zones that are on screen
    readonly property real _gapsInline: zoneSpacing * Math.max(0, _zoneUsed(left, _capL) + _zoneUsed(center, _capC) + _zoneUsed(right, _capR) - 1)

    // inline: the expanding zone takes what the others leave
    readonly property real _freeInline: Math.max(0, width - leftInset - _capL - _capC - _capR - _gapsInline)

    BarZone {
        id: left

        zoneKey: root.keyPrefix + ".left"
        controls: root.model ? root.model.left : null
        alignment: Qt.AlignLeft
        titleBar: root.titleBar

        height: root.height
        availableWidth: root.inline ? width : root.width

        x: root.leftInset
        width: {
            if (root.inline)
                return left.expanding ? root._freeInline : root._capL

            if (root.editing)
                return Math.max(left.implicitWidth, Math.max(0, center.x - root.zoneSpacing - root.leftInset))

            return Math.min(left.implicitWidth, Math.max(0, center.x - root.zoneSpacing - root.leftInset))
        }

        focus: true

        Navigation.parentItem: root
        Navigation.rightAction: function() { return !(center.focusFirst(Qt.TabFocusReason) || right.focusFirst(Qt.TabFocusReason)) }

        altFocusAction: function() { return Navigation.defaultNavigationRight() }

        onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
        onMenuOpened: (menu) => root.menuOpened(menu)
        Component.onCompleted: root.forceUnlock.connect(left.forceUnlock)
    }

    BarZone {
        id: center

        zoneKey: root.keyPrefix + ".center"
        controls: root.model ? root.model.center : null
        alignment: Qt.AlignHCenter
        titleBar: root.titleBar

        height: root.height
        availableWidth: root.inline ? width : root.width

        // centered in the row, unless the zones are laid side by side
        readonly property real _maxCentered: Math.max(0, root.width - 2 * Math.max(root._leftW + root.leftInset, root._rightW) - 2 * root.zoneSpacing)
        readonly property real _centerWidth: root.inline ? (center.expanding ? root._freeInline : root._capC)
                                                         : Math.min(center.implicitWidth, _maxCentered)

        width: _centerWidth
        x: root.inline ? (left.x + left.width + root._gapW(left.width, center._centerWidth))
                       : (root.width - width) / 2

        Navigation.parentItem: root
        Navigation.leftAction: function() { return !left.focusLast(Qt.BacktabFocusReason) }
        Navigation.rightAction: function() { return !right.focusFirst(Qt.TabFocusReason) }

        altFocusAction: function() { return Navigation.defaultNavigationUp() }

        onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
        onMenuOpened: (menu) => root.menuOpened(menu)
        Component.onCompleted: root.forceUnlock.connect(center.forceUnlock)
    }

    BarZone {
        id: right

        zoneKey: root.keyPrefix + ".right"
        controls: root.model ? root.model.right : null
        alignment: Qt.AlignRight
        titleBar: root.titleBar

        height: root.height
        availableWidth: root.inline ? width : root.width

        readonly property real _widthForGap: root.inline ? (right.expanding ? root._freeInline : root._capR) : width

        width: {
            if (root.inline)
                return right.expanding ? root._freeInline : root._capR

            const start = center.x + center.width + root.zoneSpacing
            if (root.editing)
                return Math.max(right.implicitWidth, Math.max(0, root.width - start))

            return Math.min(right.implicitWidth, Math.max(0, root.width - start))
        }
        x: root.inline ? (center.x + center.width + root._gapW(center.width, right._widthForGap)) : root.width - width

        Navigation.parentItem: root
        Navigation.leftAction: function() { return !(center.focusLast(Qt.BacktabFocusReason) || left.focusLast(Qt.BacktabFocusReason)) }

        altFocusAction: function() { return Navigation.defaultNavigationLeft() }

        onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
        onMenuOpened: (menu) => root.menuOpened(menu)
        Component.onCompleted: root.forceUnlock.connect(right.forceUnlock)
    }
}
