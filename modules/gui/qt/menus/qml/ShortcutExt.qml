/*****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
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

Shortcut {
    // On macOS the native menu bar (VLCMenuBar::MacMenuBar) owns the shortcuts of its entries: a
    // second Shortcut with the same sequence would make both ambiguous. Entries the bar owns set
    // menuBarOwned, the shortcut is then only active on the other platforms.
    property bool menuBarOwned: false

    context: Qt.ApplicationShortcut
    enabled: MainCtx.useGlobalShortcuts && !(menuBarOwned && Qt.platform.os === "osx")
}
