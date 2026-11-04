/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player

// Chips on the control bar for the playback state that is not the default and would otherwise be
// invisible: speed other than 1x, running sleep timer, A-B loop. Each one resets its state on click.
Row {
    id: root

    spacing: VLCStyle.spacing_6

    readonly property bool _speed: Math.abs(Player.rate - 1) > 0.005
    readonly property bool _loop: Player.ABloopState !== Player.ABLOOP_STATE_NONE

    visible: _speed || PlayerAux.sleepActive || _loop

    component Chip : T.AbstractButton {
        id: chip

        property string iconName: ""
        property string hint: ""

        implicitHeight: VLCStyle.dp(22, VLCStyle.scale)
        implicitWidth: row.implicitWidth + 2 * VLCStyle.spacing_8

        focusPolicy: Qt.NoFocus
        hoverEnabled: true

        readonly property ColorContext colorContext: ColorContext {
            id: chipTheme
            colorSet: ColorContext.Window
        }

        T.ToolTip.visible: hovered
        T.ToolTip.delay: VLCStyle.delayToolTipAppear
        T.ToolTip.text: hint
        Accessible.name: hint + ", " + text

        background: Rectangle {
            radius: VLCStyle.radius_s
            color: Qt.alpha(chipTheme.accent, chip.hovered ? 0.32 : 0.22)
            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: Qt.alpha(chipTheme.accent, 0.5)
        }

        contentItem: Row {
            id: row
            spacing: VLCStyle.spacing_4

            Widgets.SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.iconName !== ""
                name: chip.iconName
                size: VLCStyle.dp(16, VLCStyle.scale)
                color: chipTheme.fg.primary
                accentColor: chipTheme.accent
            }

            Widgets.LabelExt {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: chipTheme.fg.primary
                font.pixelSize: VLCStyle.text_caption
                font.weight: VLCStyle.fontWeight_semibold
            }
        }
    }

    Chip {
        visible: root._speed
        anchors.verticalCenter: parent.verticalCenter
        iconName: "speed"
        text: qsTr("%1×").arg(+Player.rate.toFixed(2))
        hint: qsTr("Playback speed. Click to reset to 1×")
        onClicked: Player.rate = 1
    }

    Chip {
        visible: PlayerAux.sleepActive
        anchors.verticalCenter: parent.verticalCenter
        iconName: "moon"
        text: PlayerAux.sleepText
        hint: qsTr("Sleep timer. Click to cancel")
        onClicked: PlayerAux.setSleep(0)
    }

    Chip {
        visible: root._loop
        anchors.verticalCenter: parent.verticalCenter
        text: Player.ABloopState === Player.ABLOOP_STATE_A ? qsTr("A–") : qsTr("A–B")
        hint: qsTr("A-B loop. Click to clear")
        onClicked: Player.toggleABloopState()
    }
}
