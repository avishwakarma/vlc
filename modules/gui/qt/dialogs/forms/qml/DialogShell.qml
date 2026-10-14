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
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

// Shared shell of the Figma form dialogs (Open Network Stream, New Playlist,
// Keyboard Shortcuts, Add Subtitles): a rounded card with a B2 title bar and a
// close button, an optional second header row, the body and a Cancel/primary footer.
//
//   DialogShell {
//       heading: qsTr("New Playlist")
//       cardWidth: 713; cardHeight: 589
//       acceptText: qsTr("Create")
//       acceptEnabled: nameField.text !== ""
//       onAccepted: { ...; close() }
//       headerData: [ ...items of the second header row (34 high)... ]
//       Item { ... body, anchors.fill: parent ... }
//   }
//
// Enter triggers the primary button, Esc the secondary one (both only when the focused
// item did not use the key). The card fades in on show and out on close.
Window {
    id: root

    property string heading
    property string acceptText: qsTr("Save")
    property string rejectText: qsTr("Cancel")
    property bool acceptEnabled: true
    // hide the primary button (read only dialogs)
    property bool showAccept: true

    // card size in Figma pixels (scaled by VLCStyle.scale)
    property real cardWidth: 1048
    property real cardHeight: 631

    // true: Pane colour (#0E0E0E, Figma "B1 Transparent"), false: View colour (#191919)
    property bool darkPane: false

    // second header row, used by the search/filter dialogs
    property alias headerData: headerRow.data
    readonly property bool hasHeaderRow: headerRow.children.length > 0

    // body (the area between the header and the footer)
    default property alias bodyData: body.data
    readonly property alias body: body

    // extra footer items placed before the primary button
    property alias footerData: footerExtra.data

    // item that receives the focus on open
    property Item initialFocusItem: null

    // the Esc/Enter keys can be claimed by the body: set to false to disable the shortcuts
    property bool enterAccepts: true

    signal accepted()
    signal rejected()
    signal unload()

    // transparent margins around the card hold its shadow (Figma frame: 15 / 7 / 15 / 23)
    readonly property real marginSize: dp(15)
    readonly property real marginTop: dp(7)
    readonly property real marginBottom: dp(23)

    function dp(v) { return v * VLCStyle.scale }

    function accept() {
        if (root.acceptEnabled && root.showAccept)
            root.accepted()
    }

    function reject() {
        root.rejected()
        root.close()
    }

    function open() {
        // centre on the main window
        const parentWin = MainCtx.intfMainWindow
        if (parentWin) {
            x = parentWin.x + (parentWin.width - width) / 2
            y = parentWin.y + (parentWin.height - height) / 2
        }
        closing_ = false
        show()
        raise()
        requestActivate()
    }

    property bool closing_: false

    title: heading

    transientParent: MainCtx.intfMainWindow
    flags: Qt.Dialog | Qt.FramelessWindowHint
    color: "transparent"

    width: dp(cardWidth) + marginSize * 2
    height: dp(cardHeight) + marginTop + marginBottom
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height

    onClosing: (close) => {
        // fade out first, then hide for real
        if (root.closing_ || !root.visible || card.opacity === 0)
            return
        close.accepted = false
        root.closing_ = true
        hideAnimation.restart()
    }

    onVisibleChanged: {
        if (visible) {
            card.opacity = 0
            card.scale = 0.98
            showAnimation.restart()
            if (root.initialFocusItem)
                root.initialFocusItem.forceActiveFocus(Qt.TabFocusReason)
            else
                keyScope.forceActiveFocus()
        } else {
            root.unload()
        }
    }

    ParallelAnimation {
        id: showAnimation

        NumberAnimation { target: card; property: "opacity"; to: 1; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: hideAnimation

        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: VLCStyle.duration_short; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "scale"; to: 0.98; duration: VLCStyle.duration_short; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.closing_ = false; root.visible = false } }
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    ColorContext {
        id: paneTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Pane
    }

    ColorContext {
        id: itemTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.Item
        hovered: true
    }

    Rectangle {
        id: card

        x: root.marginSize
        y: root.marginTop
        width: root.dp(root.cardWidth)
        height: root.dp(root.cardHeight)

        radius: VLCStyle.radius_xl
        color: root.darkPane ? paneTheme.bg.primary : Qt.alpha(theme.bg.primary, 0.95)

        transformOrigin: Item.Center

        // palette for the items of the card (Window is not an Item and can not carry it)
        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.View
        }

        Widgets.RoundedRectangleShadow {
            blurRadius: VLCStyle.shadow_floating.blur
            yOffset: VLCStyle.shadow_floating.y
            color: Qt.rgba(0, 0, 0, VLCStyle.shadow_floating.alpha)
            z: -1
        }

        FocusScope {
            id: keyScope

            anchors.fill: parent
            focus: true

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.reject()
                    event.accepted = true
                } else if (root.enterAccepts && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                           && root.acceptEnabled && root.showAccept) {
                    root.accept()
                    event.accepted = true
                }
            }

            // --- header: B2 band with rounded top corners
            Item {
                id: header

                width: parent.width
                height: titleRow.height + (root.hasHeaderRow ? VLCStyle.spacing_12 + headerRow.height : 0) + 2 * VLCStyle.dp(9, VLCStyle.scale)
                z: 2

                Rectangle {
                    width: parent.width
                    height: card.radius * 2
                    radius: card.radius
                    color: theme.bg.secondary
                }
                Rectangle {
                    y: card.radius
                    width: parent.width
                    height: parent.height - card.radius
                    color: theme.bg.secondary
                }

                // drag the window by its title bar
                DragHandler {
                    target: null
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    onActiveChanged: if (active) root.startSystemMove()
                }

                Item {
                    id: titleRow

                    x: VLCStyle.dp(9, VLCStyle.scale)
                    y: VLCStyle.dp(9, VLCStyle.scale)
                    width: parent.width - 2 * x
                    height: VLCStyle.toggle_h

                    Text {
                        x: VLCStyle.spacing_10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.heading
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.text_body
                        font.weight: VLCStyle.fontWeight_regular
                        textFormat: Text.PlainText

                        Accessible.role: Accessible.Heading
                    }

                    T.AbstractButton {
                        id: closeButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: VLCStyle.toggle_h
                        height: width

                        hoverEnabled: true
                        onClicked: root.reject()

                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Close")

                        Keys.priority: Keys.AfterItem
                        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                        background: Rectangle {
                            radius: VLCStyle.radius_s
                            color: closeButton.down ? itemTheme.bg.primary
                                                    : (closeButton.hovered ? Qt.alpha(itemTheme.bg.primary, 0.7) : "transparent")
                            border.width: closeButton.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                            border.color: theme.visualFocus

                            Behavior on color { ColorAnimation { duration: VLCStyle.duration_short } }
                        }

                        contentItem: Widgets.SvgIcon {
                            name: "close"
                            size: VLCStyle.icon_normal
                            color: closeButton.hovered ? theme.fg.highlight : theme.fg.primary
                        }
                    }
                }

                // second header row (filters)
                Item {
                    id: headerRow

                    x: VLCStyle.dp(9, VLCStyle.scale)
                    y: titleRow.y + titleRow.height + VLCStyle.spacing_12
                    width: parent.width - 2 * x
                    height: root.hasHeaderRow ? VLCStyle.dp(34, VLCStyle.scale) : 0
                }
            }

            // --- body
            Item {
                id: body

                y: header.height
                width: parent.width
                height: footer.y - y
            }

            // --- footer
            Item {
                id: footer

                y: parent.height - height
                width: parent.width
                height: VLCStyle.spacing_20 * 2 + VLCStyle.toggle_h

                Widgets.DialogButton {
                    id: rejectButton

                    x: VLCStyle.spacing_20
                    y: VLCStyle.spacing_20
                    text: root.rejectText
                    onClicked: root.reject()
                }

                Row {
                    id: footerButtons

                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.spacing_20
                    y: VLCStyle.spacing_20
                    spacing: VLCStyle.spacing_8

                    Row {
                        id: footerExtra
                        spacing: VLCStyle.spacing_8
                    }

                    Widgets.DialogButton {
                        id: acceptButton

                        visible: root.showAccept
                        kind: Widgets.DialogButton.Primary
                        text: root.acceptText
                        enabled: root.acceptEnabled
                        onClicked: root.accept()
                    }
                }
            }
        }
    }
}
