/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Sidebar panel made of titled sections with a few rows each (Figma 1106:5633, "Home"):
// "Continue Watching", "Listen Again", "Frequently Visited Folders", ...
//
// sections: [{ title, model, titleRole, subtitleRole, thumbRole, progressRole, newRole, mrlRole,
//              placeholderIcon, limit, seeAll (function or null), activate (function(index, row)) }]
SidebarPage {
    id: root

    // Properties

    property var sections: []

    // rows drawn before the first section: [{text, icon, action}]
    property var leadingActions: []

    readonly property string currentUrl: Player.url ? Player.url.toString() : ""

    // Settings

    itemCount: {
        let total = 0
        for (const section of sections)
            total += section.model?.count ?? 0
        return total
    }

    function setCurrentItemFocus(reason) {
        flick.forceActiveFocus(reason)
    }

    Flickable {
        id: flick

        parent: root.contentArea
        anchors.fill: parent
        // the first title sits 5 px above the content area in the design
        anchors.topMargin: -VLCStyle.dp(5, VLCStyle.scale)

        focus: true
        clip: true

        contentWidth: width
        contentHeight: column.height + VLCStyle.spacing_20

        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        T.ScrollBar.vertical: Widgets.ScrollBarExt {}

        Navigation.parentItem: root.contentArea

        Keys.priority: Keys.AfterItem
        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

        Column {
            id: column

            width: flick.width

            Repeater {
                model: root.leadingActions

                delegate: SidebarRow {
                    required property var modelData

                    width: column.width

                    title: modelData.text
                    iconName: modelData.icon
                    actionRow: true
                    newKnown: false

                    onClicked: modelData.action()
                }
            }

            Repeater {
                model: root.sections

                delegate: Column {
                    id: section

                    required property int index
                    required property var modelData

                    readonly property var sectionModel: modelData.model
                    readonly property int limit: modelData.limit ?? 3

                    width: column.width

                    visible: (sectionModel?.count ?? 0) > 0
                    height: visible ? implicitHeight : 0

                    // gap between two sections
                    Item {
                        width: parent.width
                        height: section.index === 0 ? 0 : VLCStyle.dp(15, VLCStyle.scale)
                    }

                    // section title with the "see all" chevron
                    T.AbstractButton {
                        id: titleButton

                        width: parent.width
                        height: VLCStyle.dp(52, VLCStyle.scale)

                        hoverEnabled: true
                        enabled: !!section.modelData.seeAll
                        focusPolicy: enabled ? Qt.StrongFocus : Qt.NoFocus

                        Accessible.name: section.modelData.title

                        onClicked: section.modelData.seeAll()

                        ColorContext {
                            id: titleTheme
                            colorSet: ColorContext.Pane
                            hovered: titleButton.hovered
                            focused: titleButton.visualFocus
                        }

                        contentItem: Item {
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                text: section.modelData.title
                                color: titleButton.hovered ? titleTheme.fg.highlight : titleTheme.fg.primary
                                font.pixelSize: VLCStyle.text_heading
                                font.weight: VLCStyle.fontWeight_regular
                            }

                            Widgets.SvgIcon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                visible: titleButton.enabled
                                name: "chevron-right"
                                color: titleButton.hovered ? titleTheme.fg.highlight : titleTheme.fg.primary
                            }
                        }

                        background: null
                    }

                    Repeater {
                        model: section.sectionModel

                        delegate: SidebarRow {
                            id: row

                            required property int index
                            required property var model

                            visible: index < section.limit
                            height: visible ? implicitHeight : 0
                            width: section.width

                            readonly property string _mrl: section.modelData.mrlRole ? (model[section.modelData.mrlRole] ?? "").toString() : ""

                            title: model[section.modelData.titleRole ?? "title"] ?? ""
                            subtitle: section.modelData.subtitleRole ? (model[section.modelData.subtitleRole] ?? "") : ""
                            thumbnail: section.modelData.thumbRole ? (model[section.modelData.thumbRole] ?? "").toString() : ""
                            iconName: section.modelData.placeholderIcon ?? "folder"
                            progress: section.modelData.progressRole ? (model[section.modelData.progressRole] ?? -1) : -1
                            isNew: section.modelData.newRole ? (model[section.modelData.newRole] ?? true) : true
                            newKnown: !!section.modelData.newRole
                            mrl: _mrl
                            current: _mrl !== "" && _mrl === root.currentUrl

                            onClicked: section.modelData.activate(index, {
                                "index": index, "id": model.id, "type": model.type, "tree": model.tree,
                                "mrl": model.mrl, "name": model.name, "title": model.title
                            })
                        }
                    }
                }
            }
        }
    }
}
