/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Controls.Basic as C

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// Keyboard Shortcuts (Figma 2437:14832): every hotkey of VLC (HotkeysModel, the real bindings) in
// categories, with a search and a field filter. The pencil (or a click) on a field records a new key.
// Edits are written to the configuration right away, "Cancel" puts the previous keys back and
// "Save" keeps them. VLC applies hotkeys after a restart.
DialogShell {
    id: root

    heading: qsTr("Keyboard Shortcuts")
    cardWidth: 1048
    cardHeight: 800

    acceptText: qsTr("Save")
    acceptEnabled: root.editCount > 0
    initialFocusItem: search

    readonly property HotkeysModel hotkeys: SettingsModel.hotkeys

    // Figma uses DM Mono for the keys, fall back to a system monospace font
    readonly property string monoFamily: {
        const families = Qt.fontFamilies()
        for (const f of ["DM Mono", "Menlo", "Consolas", "DejaVu Sans Mono"]) {
            if (families.indexOf(f) !== -1)
                return f
        }
        return "monospace"
    }

    // categories, in display order. Rows are put in the first category whose test matches, the
    // last one gets what is left
    readonly property var categories: [
        { title: qsTr("Basic"),      test: /^key-(toggle-fullscreen|leave-fullscreen|position|intf-.*|quit|snapshot|record)$/ },
        { title: qsTr("Playback"),   test: /^key-(play.*|pause|stop|next|prev|faster|slower|rate-.*|frame-.*|random|loop|program-sid-.*|title-.*|chapter-.*|disc-menu)$/ },
        { title: qsTr("Navigation"), test: /^key-(jump.*|nav-.*)$/ },
        { title: qsTr("Audio"),      test: /^key-(vol-.*|audio.*)$/ },
        { title: qsTr("Video"),      test: /^key-(aspect-ratio|crop.*|uncrop.*|zoom|unzoom|.*scalefactor|toggle-autoscale|deinterlace.*|projection-toggle|wallpaper)$/ },
        { title: qsTr("Subtitles"),  test: /^key-(sub.*)$/ },
        { title: qsTr("Other"),      test: /.*/ }
    ]

    function categoryOf(name) {
        for (let i = 0; i < categories.length; ++i) {
            if (categories[i].test.test(name))
                return i
        }
        return categories.length - 1
    }

    // 0 all fields, 1 action, 2 hotkey, 3 global hotkey
    readonly property int filterField: filterBox.currentIndex
    readonly property string filterText: search.text.trim().toLowerCase()

    function matches(action, keys, globalKeys) {
        if (filterText === "")
            return true
        const f = filterField
        return ((f === 0 || f === 1) && action.toLowerCase().indexOf(filterText) !== -1)
            || ((f === 0 || f === 2) && keys.toLowerCase().indexOf(filterText) !== -1)
            || ((f === 0 || f === 3) && globalKeys.toLowerCase().indexOf(filterText) !== -1)
    }

    // --- edits, to be able to put the previous keys back on Cancel

    // "row:global" -> raw keys before the first edit
    property var original: ({})
    property int editCount: 0

    function remember(row, global) {
        const id = row + ":" + (global ? 1 : 0)
        if (original[id] !== undefined)
            return
        const data = hotkeys.get(row)
        original[id] = global ? data.globalKeys : data.keys
        editCount = Object.keys(original).length
    }

    function revert() {
        for (const id of Object.keys(original)) {
            const parts = id.split(":")
            const row = parseInt(parts[0])
            const global = parts[1] === "1"
            hotkeys.clearKey(row, global)
            for (const key of original[id].split("\t")) {
                if (key !== "")
                    hotkeys.addKey(row, key, global, true)
            }
        }
        original = ({})
        editCount = 0
    }

    onAccepted: {
        SettingsModel.flush()
        original = ({})
        editCount = 0
        close()
    }

    onRejected: revert()

    onVisibleChanged: {
        if (visible) {
            search.text = ""
            filterBox.currentIndex = 0
            hotkeys.reload()
            original = ({})
            editCount = 0
            flick.contentY = 0
        }
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    ColorContext {
        id: fieldTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.TextField
    }

    ColorContext {
        id: itemTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Item
        hovered: true
    }

    // --- header row: search + field filter

    headerData: [
        Widgets.TextFieldExt {
            id: search

            anchors.left: parent.left
            anchors.right: filterBox.left
            anchors.rightMargin: VLCStyle.spacing_10
            height: parent.height

            leftPadding: VLCStyle.spacing_8 + VLCStyle.icon_normal + VLCStyle.spacing_10
            rightPadding: clearButton.visible ? VLCStyle.icon_normal + VLCStyle.spacing_12 : VLCStyle.spacing_12
            placeholderText: qsTr("Search Keyboard Shortcuts...")
            selectByMouse: true

            Accessible.searchEdit: true

            Keys.onDownPressed: flick.forceActiveFocus()

            background: Rectangle {
                radius: VLCStyle.radius_m
                color: fieldTheme.bg.primary
                border.width: search.activeFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                border.color: fieldTheme.border
            }

            Widgets.SvgIcon {
                x: VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: VLCStyle.icon_normal
                color: search.activeFocus ? theme.fg.highlight : theme.fg.primary
            }

            Widgets.SvgIcon {
                id: clearButton

                visible: search.text !== ""
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                name: "close-low"
                size: VLCStyle.icon_normal
                color: clearArea.containsMouse ? theme.fg.highlight : theme.fg.secondary

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { search.text = ""; search.forceActiveFocus() }
                }
            }
        },

        DialogDropdown {
            id: filterBox

            anchors.right: parent.right
            width: VLCStyle.dp(200, VLCStyle.scale)
            model: [qsTr("All Fields"), qsTr("Action"), qsTr("Hotkey"), qsTr("Global Hotkey")]
        }
    ]

    // --- body

    readonly property real columnHotkey: VLCStyle.dp(488, VLCStyle.scale)
    readonly property real columnGlobal: VLCStyle.dp(820, VLCStyle.scale)

    Item {
        id: content

        x: VLCStyle.spacing_20
        y: VLCStyle.spacing_20
        width: root.body.width - 2 * VLCStyle.spacing_20
        height: root.body.height - VLCStyle.spacing_20 - VLCStyle.dp(22, VLCStyle.scale)

        component Divider : Rectangle {
            width: parent ? parent.width : 0
            height: VLCStyle.dp(1, VLCStyle.scale)
            color: theme.separator
        }

        component Line : Text {
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize * 1.75
            height: lineHeight
            verticalAlignment: Text.AlignVCenter
            font.weight: VLCStyle.fontWeight_regular
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }

        // column titles
        Item {
            id: columns

            width: parent.width
            height: columnAction.height

            Line { id: columnAction; text: qsTr("Action"); color: theme.fg.secondary; font.pixelSize: VLCStyle.text_body }
            Line { x: root.columnHotkey; text: qsTr("Hotkey"); color: theme.fg.secondary; font.pixelSize: VLCStyle.text_body }
            Line { x: root.columnGlobal; text: qsTr("Global Hotkey"); color: theme.fg.secondary; font.pixelSize: VLCStyle.text_body }
        }

        Divider {
            id: columnsDivider
            y: columns.height + VLCStyle.spacing_20
        }

        Flickable {
            id: flick

            y: columnsDivider.y + columnsDivider.height + VLCStyle.spacing_20
            width: parent.width
            height: parent.height - y
            clip: true

            contentWidth: width
            contentHeight: sections.height
            boundsBehavior: Flickable.StopAtBounds

            C.ScrollBar.vertical: Widgets.ScrollBarExt { }

            Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

            Column {
                id: sections

                width: flick.width
                spacing: VLCStyle.spacing_20

                Repeater {
                    id: sectionRepeater

                    model: root.categories.length

                    delegate: Column {
                        id: section

                        required property int index

                        // rows of this category that match the search
                        readonly property int rows: {
                            // depends on the filter and on the model
                            const n = root.hotkeys.count
                            const unused = root.filterText + root.filterField
                            let count = 0
                            for (let i = 0; i < n; ++i) {
                                const d = root.hotkeys.get(i)
                                if (root.categoryOf(d.name) === index
                                        && root.matches(d.action, d.keysText, d.globalKeysText))
                                    count++
                            }
                            return count
                        }

                        width: sections.width
                        spacing: VLCStyle.spacing_20
                        visible: rows > 0

                        Divider {
                            visible: section.index > 0 && sectionsBefore()
                            function sectionsBefore() {
                                for (let i = 0; i < section.index; ++i) {
                                    if (sectionRepeater.itemAt(i)?.visible)
                                        return true
                                }
                                return false
                            }
                        }

                        Line {
                            width: parent.width
                            text: root.categories[section.index].title
                            color: theme.fg.primary
                            font.pixelSize: VLCStyle.text_heading
                            Accessible.role: Accessible.Heading
                        }

                        Column {
                            width: parent.width
                            spacing: VLCStyle.dp(14, VLCStyle.scale)
                            bottomPadding: VLCStyle.dp(5, VLCStyle.scale)

                            Repeater {
                                model: root.hotkeys

                                delegate: Item {
                                    id: row

                                    required property int index
                                    required property string name
                                    required property string action
                                    required property string keysText
                                    required property string globalKeysText
                                    required property bool hasGlobal

                                    width: parent.width
                                    height: VLCStyle.dp(33, VLCStyle.scale)
                                    visible: root.categoryOf(name) === section.index
                                             && root.matches(action, keysText, globalKeysText)

                                    Line {
                                        width: VLCStyle.dp(290, VLCStyle.scale)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.action
                                        color: theme.fg.heading
                                        font.pixelSize: VLCStyle.text_body
                                    }

                                    HotkeyField {
                                        x: VLCStyle.dp(290, VLCStyle.scale) + (row.width - VLCStyle.dp(830, VLCStyle.scale)) / 2
                                        row: row.index
                                        global: false
                                        keys: row.keysText
                                    }

                                    HotkeyField {
                                        x: row.width - width
                                        row: row.index
                                        global: true
                                        keys: row.globalKeysText
                                        available: row.hasGlobal
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- one key field (Figma: B2, r6, 270 x 33, mono text centred, pencil on the right)
    component HotkeyField : Rectangle {
        id: field

        property int row
        property bool global
        property string keys
        property bool available: true

        property bool editing: false
        // conflicting binding waiting for a second press to be replaced
        property string pendingKey: ""
        property string message: ""

        width: VLCStyle.dp(270, VLCStyle.scale)
        height: VLCStyle.dp(33, VLCStyle.scale)
        radius: VLCStyle.radius_m
        color: fieldTheme.bg.secondary
        border.width: editing ? VLCStyle.dp(1, VLCStyle.scale) : 0
        border.color: fieldTheme.border

        opacity: available ? 1.0 : 0.3
        activeFocusOnTab: available

        function begin() {
            if (!available)
                return
            editing = true
            pendingKey = ""
            message = ""
            forceActiveFocus(Qt.MouseFocusReason)
        }

        function end() {
            editing = false
            pendingKey = ""
            message = ""
        }

        onActiveFocusChanged: if (!activeFocus) end()

        Keys.onPressed: (event) => {
            if (!editing) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    begin()
                    event.accepted = true
                }
                return
            }

            if (event.key === Qt.Key_Escape) {
                end()
                event.accepted = true
                return
            }

            const key = root.hotkeys.keyFromEvent(event.key, event.modifiers)
            event.accepted = true
            if (key === "")
                return

            const force = (pendingKey === key)
            root.remember(row, global)
            const conflict = root.hotkeys.setKey(row, key, global, force)
            if (conflict >= 0) {
                // another action uses the key: asking for the same key again replaces it
                root.remember(conflict, global)
                pendingKey = key
                message = qsTr("Used by \"%1\". Press again to replace").arg(root.hotkeys.get(conflict).action)
            } else {
                end()
            }
        }

        Behavior on border.color { ColorAnimation { duration: VLCStyle.duration_short } }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * VLCStyle.dp(40, VLCStyle.scale)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText

            text: field.editing ? (field.message !== "" ? field.message : qsTr("Press a key..."))
                                : field.keys
            color: field.editing ? (field.message !== "" ? theme.fg.neutral : theme.fg.secondary)
                                 : theme.fg.heading
            font.family: root.monoFamily
            font.pixelSize: field.editing && field.message !== "" ? VLCStyle.text_caption : VLCStyle.text_body
        }

        Widgets.SvgIcon {
            x: parent.width - width - VLCStyle.dp(5, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            visible: field.available
            name: "edit"
            size: VLCStyle.icon_normal
            color: (hover.hovered || field.editing) ? theme.fg.highlight : theme.fg.secondary
        }

        HoverHandler { id: hover; enabled: field.available; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: field.available; onTapped: field.begin() }

        Accessible.role: Accessible.Button
        Accessible.name: field.keys
    }
}
