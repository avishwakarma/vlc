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

pragma Singleton

import QtQuick

// State and logic of the "Customize Player" mode: the live title bar / control bar become
// editable (items get dashed outlines and can be dragged), the dialog hosts the palette of
// the items that are not in the bar.
//
// Zones (BarZone.qml) register here with a key ("bar.left", "bar.center", "bar.right",
// "top.left", "top.center", "top.right") plus the special key "timeline" for the dedicated
// seek bar row. The dialog registers itself as "palette" (dropping an item there removes it).
QtObject {
    id: root

    // Properties

    // set by the "Customize Player" menu entries: the player shows the customize UI
    property bool requested: false
    // true while the user edits (the model is edited live)
    property bool editing: false
    // the edit mode started while the library was shown (go back there afterwards)
    property bool cameFromLibrary: false
    property bool dirty: false

    // changes each time one of the zone models changes
    property int revision: 0

    property var zones: ({})
    property Item paletteArea: null

    // drag state (coordinates are scene coordinates)
    property bool dragging: false
    // the drag was aborted (Esc) while the button is still down: do not start another one
    property bool dragAborted: false
    property int dragId: -1
    property string dragFromZone: ""
    property int dragFromIndex: -1
    property real dragWidth: 0
    property real dragHeight: 0
    property real ghostX: 0
    property real ghostY: 0
    property string hoverZone: ""
    property int hoverIndex: -1

    // items that can be placed several times
    readonly property var repeatable: [ /*WIDGET_SPACER*/ 0x40, /*WIDGET_SPACER_EXTEND*/ 0x41,
                                        /*DIVIDER_WIDGET*/ 0x3F ]

    property var _snapshot: ({})
    property var _connections: ({})

    // Signals

    signal saved()
    signal cancelled()

    // Functions

    function registerZone(key, zone) {
        zones[key] = zone
        zonesChanged()
        revision++
    }

    function unregisterZone(key, zone) {
        if (zones[key] === zone) {
            delete zones[key]
            zonesChanged()
            revision++
        }
    }

    function modelChanged() {
        revision++
        if (editing)
            dirty = _computeDirty()
    }

    function _controlsOf(zone) {
        return (zone && zone.controls) ? zone.controls.getControls() : []
    }

    function _computeDirty() {
        for (const key in _snapshot) {
            const zone = zones[key]
            if (!zone || !zone.controls)
                continue
            if (JSON.stringify(_controlsOf(zone)) !== JSON.stringify(_snapshot[key]))
                return true
        }
        return false
    }

    function isPlaced(id) {
        void revision
        for (const key in zones) {
            const zone = zones[key]
            if (!zone || !zone.controls)
                continue
            if (_controlsOf(zone).indexOf(id) !== -1)
                return true
        }
        return false
    }

    function isRepeatable(id) {
        return repeatable.indexOf(id) !== -1
    }

    // true when the seek bar is shown in its own row (it is not part of any zone)
    function timelineStacked(zoneKeys) {
        void revision
        for (const key of zoneKeys) {
            const zone = zones[key]
            if (zone && zone.controls && _controlsOf(zone).indexOf(0x1F /*TIMELINE*/) !== -1)
                return false
        }
        return true
    }

    function start() {
        if (editing)
            return
        _snapshot = ({})
        for (const key in zones) {
            const zone = zones[key]
            if (zone && zone.controls)
                _snapshot[key] = _controlsOf(zone)
        }
        dirty = false
        editing = true
    }

    function _restore() {
        for (const key in _snapshot) {
            const zone = zones[key]
            if (zone && zone.controls)
                zone.controls.setControls(_snapshot[key])
        }
    }

    function _finish() {
        dragging = false
        hoverZone = ""
        hoverIndex = -1
        editing = false
        requested = false
        dirty = false
        _snapshot = ({})
    }

    // discard the changes
    function cancel() {
        if (!editing) {
            requested = false
            return
        }
        cancelDrag()
        _restore()
        _finish()
        cancelled()
    }

    // keep the changes: the caller persists the profile
    function accept() {
        _finish()
        saved()
    }

    // Drag and drop

    function beginDrag(id, fromZone, fromIndex, gx, gy, w, h) {
        if (dragAborted)
            return
        dragWidth = w
        dragHeight = h
        dragId = id
        dragFromZone = fromZone
        dragFromIndex = fromIndex
        dragging = true
        updateDrag(gx, gy)
    }

    function _zoneAt(gx, gy) {
        // the palette (dialog) has priority: it covers the video area
        if (paletteArea && paletteArea.visible) {
            const p = paletteArea.mapFromItem(null, gx, gy)
            if (p.x >= 0 && p.y >= 0 && p.x <= paletteArea.width && p.y <= paletteArea.height)
                return "palette"
        }

        let best = ""
        let bestDistance = Number.MAX_VALUE
        for (const key in zones) {
            const zone = zones[key]
            if (!zone || !zone.visible || !zone.acceptsDrop(dragId))
                continue
            const p = zone.mapFromItem(null, gx, gy)
            // hit area: the zone plus a margin so that dropping near it works
            const m = zone.hitMargin
            if (p.x < -m || p.x > zone.width + m || p.y < -m || p.y > zone.height + m)
                continue
            const dx = Math.max(0, -p.x, p.x - zone.width)
            const dy = Math.max(0, -p.y, p.y - zone.height)
            const d = dx + dy
            if (d < bestDistance) {
                bestDistance = d
                best = key
            }
        }
        return best
    }

    function updateDrag(gx, gy) {
        ghostX = gx
        ghostY = gy

        const key = _zoneAt(gx, gy)
        hoverZone = key
        if (key === "" || key === "palette") {
            hoverIndex = -1
        } else {
            const zone = zones[key]
            const p = zone.mapFromItem(null, gx, gy)
            hoverIndex = zone.insertIndexFor(p.x, dragFromZone === key ? dragFromIndex : -1)
        }
    }

    function abortDrag() {
        cancelDrag()
        dragAborted = true
    }

    function cancelDrag() {
        dragging = false
        hoverZone = ""
        hoverIndex = -1
        dragId = -1
    }

    // apply the drop: returns true if the layout changed
    function endDrag() {
        const id = dragId
        const from = dragFromZone
        const fromIndex = dragFromIndex
        const target = hoverZone
        const index = hoverIndex

        dragging = false
        hoverZone = ""
        hoverIndex = -1
        dragId = -1

        if (target === "")
            return false

        const src = (from === "palette") ? null : zones[from]

        if (target === "palette") {
            // dropped back into the box: remove it from the player
            if (src && src.controls && fromIndex >= 0)
                src.controls.remove(fromIndex)
            return !!src
        }

        const dst = zones[target]
        if (!dst)
            return false

        if (src && src === dst && src.controls) {
            if (fromIndex !== index)
                src.controls.move(fromIndex, index)
            return true
        }

        if (src && src.controls && fromIndex >= 0)
            src.controls.remove(fromIndex)

        if (dst.controls)
            dst.controls.insert(Math.max(0, Math.min(index, dst.controls.count)), { "id": id })

        return true
    }
}
