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

// Media Information inspector (replaces the widget MediaInfoDialog, audit R9).
// Tabs: General (editable metadata, artwork, location), Tracks (codec / stream details)
// and Statistics (live, only for the playing media).
DialogShell {
    id: root

    heading: info.following ? qsTr("Current Media Information") : qsTr("Media Information")
    cardWidth: 760
    cardHeight: 700

    rejectText: qsTr("Close")
    acceptText: qsTr("Save Metadata")
    showAccept: tabs.currentIndex === 0
    acceptEnabled: dirty && info.hasItem
    // multi line fields use Enter
    enterAccepts: false

    // 0 General, 1 Tracks, 2 Statistics
    property bool dirty: false

    // from DialogsProvider: show `tab`; the same tab again closes it when `toggle`
    function present(tab, toggle) {
        if (visible && toggle && tabs.currentIndex === tab) {
            reject()
            return
        }
        info.loadRequest()
        dirty = false
        tabs.currentIndex = (tab === 2 && !info.following) ? 0 : tab
        if (!visible)
            open()
        else {
            raise()
            requestActivate()
        }
    }

    onAccepted: {
        if (info.save(fields()))
            dirty = false
    }

    MediaInfoModel {
        id: info
        ctx: MainCtx
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    function fields() {
        return {
            "title": titleF.text, "artist": artistF.text, "album": albumF.text,
            "genre": genreF.text, "date": dateF.text,
            "trackNumber": trackInput.text, "trackTotal": totalInput.text,
            "description": descriptionBox.text,
            "language": languageF.text, "publisher": publisherF.text,
            "copyright": copyrightF.text
        }
    }

    // fill the fields from the model, unless the user is editing
    function loadFields() {
        const m = info.meta
        titleF.text = m.title ?? ""
        artistF.text = m.artist ?? ""
        albumF.text = m.album ?? ""
        genreF.text = m.genre ?? ""
        dateF.text = m.date ?? ""
        trackInput.text = m.trackNumber ?? ""
        totalInput.text = m.trackTotal ?? ""
        descriptionBox.text = m.description ?? ""
        languageF.text = m.language ?? ""
        publisherF.text = m.publisher ?? ""
        copyrightF.text = m.copyright ?? ""
        dirty = false
    }

    Connections {
        target: info
        function onMetaChanged() { if (!root.dirty) root.loadFields() }
        function onItemChanged() { root.loadFields() }
    }

    function markDirty() {
        if (!dirty) {
            dirty = true
            info.setEditing(true)
        }
    }

    headerData: [
        Widgets.SegmentedControl {
            id: tabs

            anchors.verticalCenter: parent.verticalCenter
            compact: true
            width: Math.min(parent.width, VLCStyle.dp(360, VLCStyle.scale))
            height: parent.height
            model: info.following ? [qsTr("General"), qsTr("Tracks"), qsTr("Statistics")]
                                  : [qsTr("General"), qsTr("Tracks")]
            onActivated: (index) => currentIndex = index
            onCountChanged: if (currentIndex >= count) currentIndex = 0
        }
    ]

    // --- small building blocks

    component FieldLabel : Text {
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.text_caption
        font.weight: VLCStyle.fontWeight_medium
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }

    // label over a text input
    component MetaField : Column {
        id: mf

        property alias label: lbl.text
        property alias text: input.text
        property alias input: input
        property bool readOnly: false

        spacing: VLCStyle.spacing_4

        FieldLabel { id: lbl; width: parent.width }

        Widgets.TextFieldExt {
            id: input

            width: parent.width
            height: VLCStyle.dp(36, VLCStyle.scale)
            selectByMouse: true
            readOnly: mf.readOnly
            onTextEdited: root.markDirty()
        }
    }

    // "name   value" row of the tracks / statistics lists
    component ValueRow : Item {
        id: vr

        property string name
        property string value

        width: parent ? parent.width : 0
        height: Math.max(VLCStyle.dp(28, VLCStyle.scale), Math.max(nameText.implicitHeight, valueText.implicitHeight) + VLCStyle.spacing_8)

        Text {
            id: nameText

            x: VLCStyle.spacing_12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, vr.width * 0.42)
            text: vr.name
            elide: Text.ElideRight
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
            textFormat: Text.PlainText
        }

        Text {
            id: valueText

            anchors.left: parent.left
            anchors.leftMargin: vr.width * 0.42 + VLCStyle.spacing_12
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.spacing_12
            anchors.verticalCenter: parent.verticalCenter
            text: vr.value
            wrapMode: Text.Wrap
            color: theme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
            textFormat: Text.PlainText
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: VLCStyle.dp(1, VLCStyle.scale)
            color: theme.separator
            opacity: 0.6
        }
    }

    // titled card holding rows
    component Section : Column {
        id: sec

        property string title
        property string kind: ""
        default property alias rows: card.data

        width: parent ? parent.width : 0
        spacing: VLCStyle.spacing_8

        Row {
            spacing: VLCStyle.spacing_8
            visible: sec.title !== ""

            Widgets.SvgIcon {
                visible: sec.kind !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: sec.kind === "video" ? "clapperboard" : sec.kind === "audio" ? "audio" : sec.kind === "subtitle" ? "subtitle" : "info"
                size: VLCStyle.icon_normal
                color: theme.fg.secondary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sec.title
                color: theme.fg.heading
                font.pixelSize: VLCStyle.text_heading
                font.weight: VLCStyle.fontWeight_medium
                textFormat: Text.PlainText
            }
        }

        Rectangle {
            width: parent.width
            height: card.height
            radius: VLCStyle.radius_m
            color: theme.bg.secondary

            Column {
                id: card
                width: parent.width
            }
        }
    }

    // ---------------------------------------------------------------- body

    // nothing to show
    Text {
        anchors.centerIn: parent
        visible: !info.hasItem
        text: qsTr("No media. Play something to see its information.")
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.text_body
    }

    // --- General
    Flickable {
        id: generalFlick

        anchors.fill: parent
        visible: info.hasItem && tabs.currentIndex === 0
        contentWidth: width
        contentHeight: general.height + VLCStyle.spacing_20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Column {
            id: general

            x: VLCStyle.spacing_20
            y: VLCStyle.spacing_8
            width: generalFlick.width - 2 * VLCStyle.spacing_20
            spacing: VLCStyle.spacing_16

            Row {
                width: parent.width
                spacing: VLCStyle.spacing_20

                // artwork
                Rectangle {
                    id: art

                    width: VLCStyle.dp(168, VLCStyle.scale)
                    height: width
                    radius: VLCStyle.radius_l
                    color: theme.bg.secondary
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: info.artwork
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: art.width * 2
                        sourceSize.height: art.height * 2
                        visible: status === Image.Ready
                    }

                    Widgets.SvgIcon {
                        anchors.centerIn: parent
                        visible: info.artwork.toString() === ""
                        name: info.streams.length && info.streams[0].kind === "video" ? "clapperboard" : "audio"
                        size: VLCStyle.icon_medium
                        color: theme.fg.secondary
                    }
                }

                Column {
                    width: parent.width - art.width - parent.spacing
                    spacing: VLCStyle.spacing_12

                    MetaField { id: titleF; width: parent.width; label: qsTr("Title") }
                    MetaField { id: artistF; width: parent.width; label: qsTr("Artist") }
                    MetaField { id: albumF; width: parent.width; label: qsTr("Album") }
                }
            }

            Row {
                width: parent.width
                spacing: VLCStyle.spacing_12

                MetaField { id: genreF; width: parent.width - dateF.width - trackBox.width - 2 * parent.spacing; label: qsTr("Genre") }
                MetaField { id: dateF; width: VLCStyle.dp(110, VLCStyle.scale); label: qsTr("Year") }
                Column {
                    id: trackBox

                    width: VLCStyle.dp(176, VLCStyle.scale)
                    spacing: VLCStyle.spacing_4

                    FieldLabel { width: parent.width; text: qsTr("Track number") }
                    Row {
                        spacing: VLCStyle.spacing_8

                        Widgets.TextFieldExt {
                            id: trackInput
                            width: VLCStyle.dp(64, VLCStyle.scale)
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            horizontalAlignment: Text.AlignHCenter
                            selectByMouse: true
                            onTextEdited: root.markDirty()
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("of")
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.text_body
                        }
                        Widgets.TextFieldExt {
                            id: totalInput
                            width: VLCStyle.dp(64, VLCStyle.scale)
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            horizontalAlignment: Text.AlignHCenter
                            selectByMouse: true
                            onTextEdited: root.markDirty()
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: VLCStyle.spacing_4

                FieldLabel { width: parent.width; text: qsTr("Description") }

                DialogTextArea {
                    id: descriptionBox

                    width: parent.width
                    height: VLCStyle.dp(96, VLCStyle.scale)
                    textArea.onTextChanged: if (textArea.activeFocus) root.markDirty()
                }
            }

            // location
            Column {
                width: parent.width
                spacing: VLCStyle.spacing_4

                FieldLabel { width: parent.width; text: qsTr("Location") }

                Row {
                    width: parent.width
                    spacing: VLCStyle.spacing_8

                    Rectangle {
                        width: parent.width - revealButton.width - copyButton.width - 2 * parent.spacing
                        height: VLCStyle.dp(36, VLCStyle.scale)
                        radius: VLCStyle.radius_m
                        color: theme.bg.secondary

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: VLCStyle.spacing_12
                            anchors.rightMargin: VLCStyle.spacing_12
                            verticalAlignment: Text.AlignVCenter
                            text: info.location
                            elide: Text.ElideMiddle
                            color: theme.fg.primary
                            font.pixelSize: VLCStyle.text_body
                            textFormat: Text.PlainText
                        }
                    }

                    Widgets.DialogButton {
                        id: revealButton

                        visible: info.isLocalFile
                        width: visible ? implicitWidth : 0
                        text: Qt.platform.os === "osx" ? qsTr("Reveal in Finder") : qsTr("Show in Folder")
                        onClicked: info.reveal()
                    }

                    Widgets.DialogButton {
                        id: copyButton

                        text: qsTr("Copy")
                        onClicked: info.copyText(info.location)
                    }
                }
            }

            // more details
            Section {
                title: qsTr("More")
                visible: moreRepeater.count > 0

                Repeater {
                    id: moreRepeater
                    model: {
                        const m = info.meta
                        const rows = []
                        if (m.nowPlaying) rows.push({ "key": qsTr("Now playing"), "value": m.nowPlaying })
                        if (m.encodedBy) rows.push({ "key": qsTr("Encoded by"), "value": m.encodedBy })
                        return rows.concat(info.extraMeta)
                    }
                    delegate: ValueRow {
                        required property var modelData
                        name: modelData.key
                        value: modelData.value
                    }
                }
            }

            Section {
                title: qsTr("Additional fields")

                Column {
                    width: parent.width
                    padding: VLCStyle.spacing_12
                    spacing: VLCStyle.spacing_12

                    MetaField { id: languageF; width: parent.width - 2 * parent.padding; label: qsTr("Language") }
                    MetaField { id: publisherF; width: parent.width - 2 * parent.padding; label: qsTr("Publisher") }
                    MetaField { id: copyrightF; width: parent.width - 2 * parent.padding; label: qsTr("Copyright") }
                }
            }
        }
    }

    // --- Tracks
    Flickable {
        anchors.fill: parent
        visible: info.hasItem && tabs.currentIndex === 1
        contentWidth: width
        contentHeight: tracks.height + VLCStyle.spacing_20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Column {
            id: tracks

            x: VLCStyle.spacing_20
            y: VLCStyle.spacing_8
            width: parent.width - 2 * VLCStyle.spacing_20
            spacing: VLCStyle.spacing_16

            Repeater {
                model: info.streams

                delegate: Section {
                    required property var modelData

                    title: modelData.name
                    kind: modelData.kind

                    Repeater {
                        model: modelData.infos
                        delegate: ValueRow {
                            required property var modelData
                            name: modelData.name
                            value: modelData.value
                        }
                    }
                }
            }

            Text {
                visible: info.streams.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("No stream information yet.")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.text_body
            }
        }
    }

    // --- Statistics
    Flickable {
        id: statsFlick

        anchors.fill: parent
        visible: info.hasItem && tabs.currentIndex === 2
        contentWidth: width
        contentHeight: statsCol.height + VLCStyle.spacing_20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Column {
            id: statsCol

            x: VLCStyle.spacing_20
            y: VLCStyle.spacing_8
            width: parent.width - 2 * VLCStyle.spacing_20
            spacing: VLCStyle.spacing_16

            function n(key) { return Number(info.stats[key] ?? 0).toLocaleString(Qt.locale(), "f", 0) }
            function kbps(key) { return Number(info.stats[key] ?? 0).toLocaleString(Qt.locale(), "f", 0) + " kb/s" }
            function bytes(key) { return info.formatBytes(Number(info.stats[key] ?? 0)) }

            Section {
                title: qsTr("Input")

                ValueRow { name: qsTr("Media data size"); value: statsCol.bytes("inputBytes") }
                ValueRow { name: qsTr("Input bitrate"); value: statsCol.kbps("inputBitrate") }
                ValueRow { name: qsTr("Demuxed data size"); value: statsCol.bytes("demuxBytes") }
                ValueRow { name: qsTr("Content bitrate"); value: statsCol.kbps("contentBitrate") }
                ValueRow { name: qsTr("Discarded (corrupted)"); value: statsCol.n("corrupted") }
                ValueRow { name: qsTr("Dropped (discontinued)"); value: statsCol.n("discontinuity") }
            }

            // input bitrate of the last 60 seconds
            Section {
                title: qsTr("Input bitrate, last 60 seconds")

                Canvas {
                    id: graph

                    width: parent.width
                    height: VLCStyle.dp(110, VLCStyle.scale)

                    readonly property color lineColor: theme.accent
                    readonly property color gridColor: theme.separator

                    onLineColorChanged: requestPaint()
                    onGridColorChanged: requestPaint()

                    Connections {
                        target: info
                        function onStatsChanged() { graph.requestPaint() }
                    }

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const pad = VLCStyle.spacing_12
                        const w = width - 2 * pad
                        const h = height - 2 * pad
                        ctx.strokeStyle = gridColor
                        ctx.lineWidth = 1
                        for (let i = 0; i < 3; ++i) {
                            const y = pad + h * i / 2
                            ctx.beginPath(); ctx.moveTo(pad, y); ctx.lineTo(pad + w, y); ctx.stroke()
                        }
                        const hist = info.bitrateHistory
                        if (hist.length < 2)
                            return
                        let max = 1
                        for (let i = 0; i < hist.length; ++i)
                            max = Math.max(max, hist[i])
                        ctx.strokeStyle = lineColor
                        ctx.lineWidth = 2
                        ctx.lineJoin = "round"
                        ctx.beginPath()
                        for (let i = 0; i < hist.length; ++i) {
                            const x = pad + w * (60 - hist.length + i) / 59
                            const y = pad + h * (1 - hist[i] / max)
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }
            }

            Section {
                title: qsTr("Video")
                kind: "video"

                ValueRow { name: qsTr("Decoded"); value: statsCol.n("vDecoded") }
                ValueRow { name: qsTr("Displayed"); value: statsCol.n("vDisplayed") }
                ValueRow { name: qsTr("Late"); value: statsCol.n("vLate") }
                ValueRow { name: qsTr("Lost"); value: statsCol.n("vLost") }
            }

            Section {
                title: qsTr("Audio")
                kind: "audio"

                ValueRow { name: qsTr("Decoded"); value: statsCol.n("aDecoded") }
                ValueRow { name: qsTr("Played"); value: statsCol.n("aPlayed") }
                ValueRow { name: qsTr("Lost"); value: statsCol.n("aLost") }
            }
        }
    }
}
