/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQuick.Layouts


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Network
import VLC.Menus
import VLC.Util

T.Control {
    id: control

    property var path: []

    property var _contentModel
    property var _menuModel

    readonly property int maximumWidth: VLCStyle.bannerTabButton_width_large * 4
    readonly property int minimumWidth: VLCStyle.bannerTabButton_width_large

    signal browse(var tree, int reason)
    signal homeButtonClicked(int reason)

    onPathChanged: createContentModel()
    onAvailableWidthChanged: createContentModel()
    implicitWidth: VLCStyle.bannerTabButton_width_large * 4
    implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
    focus: true
    onActiveFocusChanged: if (activeFocus) contentItem.forceActiveFocus(focusReason)

    function createContentModel() {
        const contentModel = []
        const menuModel = []
        if (path.length < 1)
            return
        let leftWidth = control.availableWidth
        let i = path.length
        while (--i >= 0) {
            const textWidth = fontMetrics.advanceWidth(path[i].display)
                    + (i !== path.length - 1 ? VLCStyle.icon_normal : 0) + VLCStyle.margin_xsmall * 4

            if (i < path.length - 1 && textWidth > leftWidth)
                menuModel.push(path[i])
            else
                contentModel.unshift(path[i])
            leftWidth -= textWidth
        }
        control._contentModel = contentModel
        control._menuModel = menuModel
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View

        focused: control.visualFocus
        hovered: control.hovered
        enabled: control.enabled
    }

    background: Rectangle {
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: theme.border
        border.pixelAligned: (radius < Number.EPSILON)
        color: theme.bg.primary
    }

    contentItem: RowLayout {
        spacing: VLCStyle.margin_xxsmall
        width: control.availableWidth
        onActiveFocusChanged: if (activeFocus) homeButton.forceActiveFocus(focusReason)

        AddressbarButton {
            id: homeButton

            AccessibleCompat.id: "addressBarHome"

            iconName: "home"

            display: AddressbarButton.IconOnly

            Layout.fillHeight: true

            Navigation.parentItem: control
            Navigation.rightAction: function () {
                if (menuButton.visible)
                    menuButton.forceActiveFocus(Qt.TabFocusReason)
                else
                    contentRepeater.itemAt(0).forceActiveFocus(Qt.TabFocusReason)
            }
            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

            onClicked: control.homeButtonClicked(focusReason)
        }

        AddressbarButton {
            id: menuButton

            AccessibleCompat.id: "addressBarMenu"

            visible: !!control._menuModel && control._menuModel.length > 0
            iconName: "chevron-left"

            display: AddressbarButton.IconOnly

            Layout.fillHeight: true

            Navigation.parentItem: control
            Navigation.leftItem: homeButton
            Navigation.rightAction: function () {
                contentRepeater.itemAt(0).forceActiveFocus(Qt.TabFocusReason)
            }
            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

            onClicked: popup.show()
        }

        Repeater {
            id: contentRepeater
            model: control._contentModel
            delegate: RowLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.maximumWidth: implicitWidth
                focus: true
                spacing: VLCStyle.margin_xxxsmall
                onActiveFocusChanged: if (activeFocus) btn.forceActiveFocus(focusReason)

                Navigation.parentItem: control
                Navigation.leftAction: function() {
                    if (index !== 0)
                        contentRepeater.itemAt(index - 1).forceActiveFocus(Qt.BacktabFocusReason)
                    else if (menuButton.visible)
                        menuButton.forceActiveFocus(Qt.BacktabFocusReason)
                    else
                        homeButton.forceActiveFocus(Qt.BacktabFocusReason)
                }

                Navigation.rightAction: function () {
                    if (index !== contentRepeater.count - 1)
                        contentRepeater.itemAt(index + 1).forceActiveFocus(Qt.TabFocusReason)
                    else
                        control.Navigation.defaultNavigationRight()
                }

                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                AddressbarButton {
                    id: btn

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData.display
                    highlighted: index === contentRepeater.count - 1

                    onClicked: {
                        if (index !== contentRepeater.count - 1)
                            browse(modelData.tree, focusReason)
                    }
                }

                Widgets.SvgIcon {
                    Layout.alignment: Qt.AlignVCenter
                    visible: index !== contentRepeater.count - 1
                    name: "chevron-right"
                    size: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    FontMetrics {
        id: fontMetrics
        font.pixelSize: VLCStyle.text_title
    }

    StringListMenu {
        id: popup

        ctx: MainCtx

        function show() {
            const model = control._menuModel.map(function (modelData) {
                return modelData.display
            })

            const point = control.mapToGlobal(0, menuButton.height + VLCStyle.margin_xxsmall)

            popup.popup(point, model)
        }

        onSelected: {
            browse(control._menuModel[index].tree, focusReason)
        }
    }
}
