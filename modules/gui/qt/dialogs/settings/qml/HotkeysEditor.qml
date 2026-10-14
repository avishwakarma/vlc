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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets

// In-window keyboard shortcut editor, opened by the Controls page. Lists the
// HotkeysModel; click a binding, press the new keys (Backspace clears, Esc
// cancels). A key already used elsewhere asks before it is taken over.
T.Popup {
    id: popup

    readonly property var hotkeys: SettingsModel.hotkeys

    parent: T.Overlay.overlay
    anchors.centerIn: parent

    modal: true
    dim: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    width: Math.min(VLCStyle.dp(640, VLCStyle.scale), parent ? parent.width - VLCStyle.margin_xlarge : 640)
    height: Math.min(VLCStyle.dp(620, VLCStyle.scale), parent ? parent.height - VLCStyle.margin_xlarge : 620)

    padding: 0

    // row being edited (-1 = none) and a pending conflict
    property int editing: -1
    property string pendingKey: ""
    property int conflictRow: -1

    onClosed: {
        editing = -1
        conflictRow = -1
        search.text = ""
    }

    onOpened: search.forceActiveFocus()

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_short }
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    // the popup lives in the overlay: it needs its own palette
    readonly property ColorContext _item: ColorContext {
        id: itemTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Item
        hovered: true
    }

    background: Rectangle {
        radius: VLCStyle.radius_xl
        color: theme.bg.primary

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.shadow_floating.blur
            yOffset: VLCStyle.shadow_floating.y
            color: theme.shadow
            z: -1
        }
    }

    function startEdit(row) {
        conflictRow = -1
        pendingKey = ""
        editing = row
        capture.forceActiveFocus()
    }

    function stopEdit() {
        editing = -1
        conflictRow = -1
        pendingKey = ""
        search.forceActiveFocus()
    }

    contentItem: ColumnLayout {
        spacing: 0

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.Menu
        }

        // header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(50, VLCStyle.scale)

            Rectangle {
                width: parent.width
                height: popup.background.radius * 2
                radius: popup.background.radius
                color: theme.bg.secondary
            }
            Rectangle {
                y: popup.background.radius
                width: parent.width
                height: parent.height - popup.background.radius
                color: theme.bg.secondary
            }

            Text {
                x: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Keyboard Shortcuts")
                color: theme.fg.highlight
                font.pixelSize: VLCStyle.text_heading
            }

            T.AbstractButton {
                id: closeButton

                x: parent.width - width - VLCStyle.spacing_8
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(32, VLCStyle.scale)
                height: width
                hoverEnabled: true
                onClicked: popup.close()

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Close")

                background: Rectangle {
                    radius: VLCStyle.radius_s
                    color: closeButton.hovered ? itemTheme.bg.primary : "transparent"
                    border.width: closeButton.visualFocus ? VLCStyle.border : 0
                    border.color: theme.visualFocus
                }
                contentItem: Widgets.SvgIcon {
                    name: "close"
                    size: VLCStyle.icon_normal
                    color: closeButton.hovered ? theme.fg.highlight : theme.fg.primary
                }
            }
        }

        Widgets.TextFieldExt {
            id: search

            Layout.fillWidth: true
            Layout.margins: VLCStyle.spacing_20
            Layout.bottomMargin: VLCStyle.spacing_10
            placeholderText: qsTr("Search shortcuts")
            selectByMouse: true
            Keys.onDownPressed: list.forceActiveFocus()
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VLCStyle.spacing_20
            Layout.rightMargin: VLCStyle.spacing_20

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: popup.hotkeys
            keyNavigationEnabled: true
            currentIndex: 0
            reuseItems: false

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: delegate

                required property int index
                required property var model

                readonly property string actionText: model.action
                readonly property string keysText: model.keysText
                readonly property bool modified: model.modified

                readonly property bool matches: {
                    const f = search.text.trim().toLowerCase()
                    return f === "" || (actionText + " " + keysText).toLowerCase().indexOf(f) !== -1
                }
                readonly property bool isEditing: popup.editing === index

                visible: matches
                width: ListView.view.width
                height: matches ? VLCStyle.dp(40, VLCStyle.scale) : 0
                hoverEnabled: true

                onClicked: popup.startEdit(index)
                Keys.onReturnPressed: popup.startEdit(index)
                Keys.onEnterPressed: popup.startEdit(index)

                Accessible.name: actionText + ", " + keysText

                background: Rectangle {
                    radius: VLCStyle.radius_s
                    color: delegate.isEditing || delegate.hovered || delegate.visualFocus ? itemTheme.bg.primary
                                                                                           : "transparent"
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.spacing_10

                    Text {
                        Layout.fillWidth: true
                        text: delegate.actionText
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.text_body
                        elide: Text.ElideRight
                        leftPadding: VLCStyle.spacing_10
                    }

                    Text {
                        text: delegate.isEditing
                              ? (popup.conflictRow >= 0
                                 ? qsTr("Used by %1. Press Enter to replace").arg(popup.hotkeys.get(popup.conflictRow).action)
                                 : qsTr("Press the new shortcut"))
                              : (delegate.keysText !== "" ? delegate.keysText : qsTr("Not set"))
                        color: delegate.isEditing ? theme.accent
                                                  : (delegate.keysText !== "" ? theme.fg.primary : theme.fg.secondary)
                        font.pixelSize: VLCStyle.text_body
                        font.weight: delegate.modified ? VLCStyle.fontWeight_semibold : VLCStyle.fontWeight_regular
                        elide: Text.ElideLeft
                        rightPadding: VLCStyle.spacing_10
                        Layout.maximumWidth: parent.width * 0.6
                    }
                }
            }
        }

        // key capture while editing
        FocusScope {
            id: capture

            Layout.preferredWidth: 0
            Layout.preferredHeight: 0

            Keys.onPressed: (event) => {
                if (popup.editing < 0)
                    return
                event.accepted = true

                if (event.key === Qt.Key_Escape) {
                    popup.stopEdit()
                    return
                }
                if (popup.conflictRow >= 0 && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                    popup.hotkeys.setKey(popup.editing, popup.pendingKey, false, true)
                    popup.stopEdit()
                    return
                }
                if (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) {
                    popup.hotkeys.clearKey(popup.editing, false)
                    popup.stopEdit()
                    return
                }

                const key = popup.hotkeys.keyFromEvent(event.key, event.modifiers)
                if (key === "")
                    return // modifier only, keep listening

                const conflict = popup.hotkeys.setKey(popup.editing, key, false, false)
                if (conflict >= 0) {
                    popup.pendingKey = key
                    popup.conflictRow = conflict
                } else {
                    popup.stopEdit()
                }
            }
        }

        // footer
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(72, VLCStyle.scale)

            Rectangle {
                width: parent.width
                height: VLCStyle.border
                color: theme.separator
            }

            Text {
                x: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Changes apply after VLC restarts.")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }

            Widgets.DialogButton {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.spacing_20
                anchors.verticalCenter: parent.verticalCenter
                kind: Widgets.DialogButton.Primary
                text: qsTr("Done")
                onClicked: popup.close()
            }
        }
    }
}
