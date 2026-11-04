/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *****************************************************************************/
pragma Singleton

import QtQuick

import VLC.Player
import VLC.Dialogs

// Player state that must outlive the popovers and tabs that edit it, plus the tooltip helper.
QtObject {
    id: root

    // ---- sleep timer ---------------------------------------------------------------------
    // Lives here (not in the Playback tab, which is destroyed when the tab changes).

    // minutes chosen, 0 when off
    property int sleepMinutes: 0
    // seconds left, 0 when off
    property int sleepRemaining: 0
    readonly property bool sleepActive: sleepMinutes > 0

    property double _end: 0

    function setSleep(minutes) {
        sleepMinutes = minutes
        if (minutes > 0) {
            _end = Date.now() + minutes * 60000
            sleepRemaining = minutes * 60
        } else {
            _end = 0
            sleepRemaining = 0
        }
    }

    // "23 min" / "45 s"
    readonly property string sleepText: sleepRemaining >= 60 ? qsTr("%1 min").arg(Math.ceil(sleepRemaining / 60))
                                                              : qsTr("%1 s").arg(sleepRemaining)

    property Timer _timer: Timer {
        interval: 1000
        repeat: true
        running: root.sleepActive
        onTriggered: {
            root.sleepRemaining = Math.max(0, Math.round((root._end - Date.now()) / 1000))
            if (root.sleepRemaining <= 0) {
                root.setSleep(0)
                Player.stop()
            }
        }
    }

    // ---- tooltips ------------------------------------------------------------------------

    // Primary binding of the hotkey action ("play-pause", "snapshot", ...) with macOS glyphs, "" if none
    function shortcut(action) {
        const hk = SettingsModel.hotkeys
        if (!hk || !action)
            return ""
        const row = hk.indexOf("key-" + action)
        if (row < 0)
            return ""
        const keys = hk.get(row).keys
        if (!keys)
            return ""
        return hk.keyGlyphs(keys.split("\t")[0])
    }

    // "Subtitles  S"
    function tip(description, action) {
        const s = shortcut(action)
        return s === "" ? description : description + "  " + s
    }
}
