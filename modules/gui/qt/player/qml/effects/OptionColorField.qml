
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

import VLC.Dialogs

// HexColorField bound to a ConfigOption of type Color ("#RRGGBB" values).
HexColorField {
    id: control

    property ConfigOption option: null

    rgb: {
        const v = option ? option.value : undefined
        if (v === undefined || v === null)
            return 0
        if (typeof v === "string")
            return parseInt(v.replace("#", ""), 16) || 0
        return Number(v)
    }

    onCommitted: (v) => {
        if (option)
            option.value = "#" + ("000000" + v.toString(16)).slice(-6)
    }
}
