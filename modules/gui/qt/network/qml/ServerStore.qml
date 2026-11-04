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

import VLC.MainInterface
import VLC.Network

// Saved network shares ("Servers") and the "Connect to Server…" dialog, shared by the Network page
// of the library window and of the sidebar. Shares are kept in the settings as JSON [{name, url}].
Item {
    id: root

    readonly property string settingKey: "Network/saved-shares"

    // [{name, url}]
    property var shares: _load()

    // model of the saved shares (rows give `tree` to browse)
    readonly property StandardPathModel model: StandardPathModel {
        serversMode: true
        servers: root.shares
    }

    // a share was connected: browse its content
    signal browseRequested(var tree)

    width: 0
    height: 0
    visible: false


    function _load() {
        try {
            const list = JSON.parse(String(MainCtx.settingValue(settingKey, "[]")))
            return Array.isArray(list) ? list : []
        } catch (e) {
            return []
        }
    }

    function _save(list) {
        MainCtx.setSettingValue(settingKey, JSON.stringify(list))
        shares = list
    }

    function has(url) {
        return shares.some((s) => s.url === url)
    }

    function add(url, name) {
        if (has(url))
            return
        _save([...shares, { name: name, url: url }])
    }

    function remove(url) {
        _save(shares.filter((s) => s.url !== url))
    }

    function connectDialog() {
        dialog.openDialog()
    }

    ConnectToServerDialog {
        id: dialog

        onConnectRequested: (url, name, save) => {
            if (save)
                root.add(url, name)
            probe.servers = [{ name: name, url: url }]
        }
    }

    // one shot model used to get the tree of an address that is not saved
    StandardPathModel {
        id: probe

        serversMode: true
    }

    ListView {
        width: 0
        height: 0
        visible: false

        model: probe

        delegate: Item {
            required property var tree

            Component.onCompleted: Qt.callLater(() => {
                root.browseRequested(tree)
                probe.servers = []
            })
        }
    }
}
