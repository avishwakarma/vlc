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
import QtQuick.Shapes
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// Open Media (advanced): the File / Disc / Network / Capture Device tabs of the legacy Open dialog
// (Ctrl+Shift+O, Ctrl+D, Ctrl+C), with "Show more options" (caching, start / stop time, extra options,
// slave media) and the Play / Add to Queue / Stream / Convert actions. MRLs and options come from
// OpenAdvanced (C++), the same as the widget panels build.
DialogShell {
    id: root

    // OpenAdvanced.Action
    readonly property int actionPlay: 0
    readonly property int actionEnqueue: 1
    readonly property int actionStream: 2
    readonly property int actionConvert: 3

    // tabs
    readonly property int tabFile: 0
    readonly property int tabDisc: 1
    readonly property int tabNetwork: 2
    readonly property int tabCapture: 3

    // disc types (OpenAdvanced::discMrl)
    readonly property int discDvd: 0
    readonly property int discBluray: 1
    readonly property int discCdda: 2
    readonly property int discVcd: 3
    readonly property int discDvda: 4

    property int currentTab: tabFile
    property int primaryAction: actionPlay

    // --- state of the tabs (kept when switching tabs)
    property var files: []
    property bool useSubtitle: false
    property string subtitleUrl: ""

    property int discType: discDvd
    property var discList: []
    property int discIndex: -1
    property int discTitle: 0
    property int discChapter: 0
    property int discAudio: -1
    property int discSubtitle: -1
    property bool discNoMenus: false

    property int captureModeIndex: 0
    property var videoDevices: []
    property var audioDevices: []
    property int videoDeviceIndex: 0
    // 0: none
    property int audioDeviceIndex: 0
    property real captureFps: 1.0

    // --- more options
    property bool moreOptions: false
    property int caching: 0
    property bool useSlave: false
    property string slaveUrl: ""

    readonly property string cachingMethod: currentTab === tabFile ? "file-caching"
                                           : currentTab === tabDisc ? "disc-caching"
                                           : currentTab === tabNetwork ? "network-caching" : "live-caching"

    readonly property real startSeconds: oa.parseTime(startField.text)
    readonly property real stopSeconds: oa.parseTime(stopField.text)
    readonly property bool timesValid: startSeconds >= 0 && stopSeconds >= 0

    readonly property string captureMode: {
        const m = oa.captureModes[captureModeIndex]
        return m ? m.id : "screen"
    }

    // what the current tab would open: { items, names, options }
    readonly property var request: buildRequest()

    heading: qsTr("Open Media")
    cardWidth: 780
    cardHeight: 780

    acceptText: actionText(primaryAction)
    acceptEnabled: request.items.length > 0 && timesValid
    initialFocusItem: tabs

    onAccepted: run(primaryAction)

    OpenAdvanced {
        id: oa
        ctx: MainCtx
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    ColorContext {
        id: dimTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
        enabled: false
    }

    ColorContext {
        id: fieldTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.TextField
    }

    // tab: OpenAdvanced tab, action: OpenAdvanced.Action
    function present(tab, action) {
        currentTab = Math.max(0, Math.min(3, tab))
        primaryAction = action
        reset()
        if (!visible)
            open()
        else {
            raise()
            requestActivate()
        }
    }

    function reset() {
        files = []
        useSubtitle = false
        subtitleUrl = ""
        useSlave = false
        slaveUrl = ""
        startField.text = ""
        stopField.text = ""
        extraField.text = ""
        refreshDiscs()
        refreshCapture()
        caching = oa.cachingDefault(cachingMethod)
        if (currentTab === tabNetwork)
            network.reset(forms.clipboardLocations())
        else
            network.reset("")
    }

    function actionText(action) {
        switch (action) {
        case actionEnqueue: return qsTr("Add to Queue")
        case actionStream: return qsTr("Stream")
        case actionConvert: return qsTr("Convert")
        default: return qsTr("Play")
        }
    }

    function run(action) {
        if (!acceptEnabled)
            return
        if (oa.submit(action, request.items, request.names, request.options) > 0)
            close()
    }

    function refreshDiscs() {
        discList = oa.discDevices()
        discType = discDvd
        discTitle = 0
        discChapter = 0
        discAudio = -1
        discSubtitle = -1
        discNoMenus = false
        selectDefaultDisc()
    }

    function selectDefaultDisc() {
        const def = oa.defaultDiscDevice(discType)
        let idx = -1
        for (let i = 0; i < discList.length; ++i) {
            if (def !== "" && discList[i].path === def) {
                idx = i
                break
            }
        }
        if (idx < 0 && discIndex >= 0 && discIndex < discList.length)
            idx = discIndex
        discIndex = idx < 0 && discList.length > 0 ? 0 : idx
        if (discType === discBluray)
            discNoMenus = !oa.blurayMenuDefault()
    }

    function refreshCapture() {
        captureModeIndex = 0
        videoDevices = oa.captureDevices("video")
        audioDevices = oa.captureDevices("audio")
        videoDeviceIndex = 0
        audioDeviceIndex = 0
        captureFps = 1.0
    }

    function addFiles(urls) {
        if (!urls || urls.length === 0)
            return
        const list = files.slice()
        for (const u of urls) {
            const s = u.toString()
            if (list.indexOf(s) < 0)
                list.push(s)
        }
        files = list
    }

    function removeFile(index) {
        const list = files.slice()
        list.splice(index, 1)
        files = list
    }

    function buildRequest() {
        let items = []
        let names = []
        let options = []

        if (currentTab === tabFile) {
            items = files.slice().sort()
            if (useSubtitle && subtitleUrl !== "" && items.length > 0)
                options.push(oa.subtitleOption(subtitleUrl))
        } else if (currentTab === tabDisc) {
            const dev = (discIndex >= 0 && discIndex < discList.length) ? discList[discIndex].path : ""
            if (dev !== "") {
                const m = oa.discMrl(discType, dev, discTitle, discChapter, discAudio, discSubtitle, discNoMenus)
                items = m.items
                options = m.options
            }
        } else if (currentTab === tabNetwork) {
            items = oa.networkItems(network.text)
            const title = network.name.trim()
            if (title !== "")
                names = items.map((u, i) => items.length === 1 ? title : title + " (" + (i + 1) + ")")
        } else {
            const v = videoDeviceIndex < videoDevices.length ? videoDevices[videoDeviceIndex].id : ""
            const a = (audioDeviceIndex > 0 && audioDeviceIndex <= audioDevices.length)
                    ? audioDevices[audioDeviceIndex - 1].id
                    : (captureMode === "audio" && audioDevices.length > 0 ? audioDevices[0].id : "")
            const m = oa.captureMrl(captureMode, v, captureMode === "audio" ? a : (audioDeviceIndex > 0 ? a : ""), captureFps)
            items = m.items
            options = m.options
        }

        const slave = (useSlave && slaveUrl !== "") ? slaveUrl : ""
        options = options.concat(oa.commonOptions(cachingMethod, caching,
                                                  Math.max(0, startSeconds), Math.max(0, stopSeconds),
                                                  slave, extraField.text))
        return { items: items, names: names, options: options }
    }

    onCachingMethodChanged: caching = oa.cachingDefault(cachingMethod)

    onCurrentTabChanged: {
        if (currentTab === tabNetwork)
            network.initialFocusItem.forceActiveFocus()
    }

    DialogForms {
        id: forms
        ctx: MainCtx
    }

    headerData: [
        Widgets.SegmentedControl {
            id: tabs

            anchors.verticalCenter: parent.verticalCenter
            compact: true
            width: parent.width
            height: parent.height
            model: [qsTr("File"), qsTr("Disc"), qsTr("Network"), qsTr("Capture Device")]
            currentIndex: root.currentTab
            onActivated: (index) => root.currentTab = index
        }
    ]

    footerData: [
        Repeater {
            model: [root.actionPlay, root.actionEnqueue, root.actionStream, root.actionConvert]

            Widgets.DialogButton {
                required property int modelData

                visible: modelData !== root.primaryAction
                text: root.actionText(modelData)
                enabled: root.acceptEnabled
                onClicked: root.run(modelData)
            }
        }
    ]

    // ---- building blocks

    // a field label (14 px FG/2) above a control
    component FieldLabel : Text {
        color: theme.fg.heading
        font.pixelSize: VLCStyle.text_body
        font.weight: VLCStyle.fontWeight_regular
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }

    component Rule : Rectangle {
        height: VLCStyle.dp(1, VLCStyle.scale)
        color: theme.separator
    }

    // label above a control
    component Labeled : Column {
        property string label
        spacing: VLCStyle.spacing_6

        FieldLabel {
            width: parent.width
            text: parent.label
        }
    }

    // 41 px single line field, like the other forms
    component Field : Widgets.TextFieldExt {
        height: VLCStyle.dp(41, VLCStyle.scale)
        leftPadding: VLCStyle.spacing_12
        rightPadding: VLCStyle.spacing_16
        selectByMouse: true
    }

    component Spin : Widgets.SpinBoxExt {
        id: spin

        property string zeroText
        property int zeroValue: 0

        implicitHeight: VLCStyle.dp(41, VLCStyle.scale)
        bgColor: fieldTheme.bg.secondary
        borderColor: fieldTheme.border
        editable: true
        textFromValue: (value) => (zeroText !== "" && value === zeroValue) ? zeroText : String(value)
        valueFromText: (text) => {
            const n = parseInt(text)
            return isNaN(n) ? zeroValue : n
        }
    }

    // name of a file URL, for the lists
    function fileName(url) {
        const p = oa.displayPath(url)
        return p.substring(Math.max(p.lastIndexOf("/"), p.lastIndexOf("\\")) + 1)
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        anchors.leftMargin: VLCStyle.spacing_20
        anchors.rightMargin: VLCStyle.spacing_4
        anchors.topMargin: VLCStyle.dp(22, VLCStyle.scale)
        clip: true
        contentWidth: width
        contentHeight: content.height + VLCStyle.spacing_20
        boundsBehavior: Flickable.StopAtBounds

        T.ScrollBar.vertical: Widgets.ScrollBarExt {
            policy: scroller.contentHeight > scroller.height ? T.ScrollBar.AlwaysOn : T.ScrollBar.AlwaysOff
        }

        Column {
            id: content

            width: scroller.width - VLCStyle.spacing_16 - VLCStyle.spacing_4
            spacing: VLCStyle.spacing_20

            // ================= File
            Column {
                visible: root.currentTab === root.tabFile
                width: parent.width
                spacing: VLCStyle.spacing_20

                DialogHeading {
                    width: parent.width
                    label: qsTr("Files")
                    helper: qsTr("Select one or more files to open. They are played in alphabetical order.")
                }

                Rectangle {
                    id: dropZone

                    width: parent.width
                    height: VLCStyle.dp(186, VLCStyle.scale)
                    radius: VLCStyle.radius_m
                    color: fieldTheme.bg.secondary

                    readonly property real stroke: VLCStyle.dp(2, VLCStyle.scale)

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: (dropArea.containsDrag || hoverZone.hovered) ? theme.fg.secondary : theme.border
                            strokeWidth: dropZone.stroke
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [3, 3]
                            capStyle: ShapePath.FlatCap

                            Behavior on strokeColor { ColorAnimation { duration: VLCStyle.duration_short } }

                            PathRectangle {
                                x: dropZone.stroke / 2
                                y: dropZone.stroke / 2
                                width: dropZone.width - dropZone.stroke
                                height: dropZone.height - dropZone.stroke
                                radius: dropZone.radius - dropZone.stroke / 2
                            }
                        }
                    }

                    HoverHandler { id: hoverZone; cursorShape: Qt.PointingHandCursor }

                    TapHandler {
                        enabled: root.files.length === 0
                        onTapped: root.addFiles(oa.pickFiles())
                    }

                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: (drop) => {
                            if (drop.hasUrls)
                                root.addFiles(drop.urls.map(u => u.toString()))
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.files.length === 0
                        text: qsTr("Drag files into the box or click here to select files.")
                        color: dimTheme.fg.primary
                        font.pixelSize: VLCStyle.text_body
                        font.weight: VLCStyle.fontWeight_regular
                    }

                    ListView {
                        id: fileList

                        anchors.fill: parent
                        anchors.margins: dropZone.stroke + VLCStyle.spacing_4
                        visible: root.files.length > 0
                        clip: true
                        model: root.files
                        boundsBehavior: Flickable.StopAtBounds

                        T.ScrollBar.vertical: Widgets.ScrollBarExt {}

                        delegate: Item {
                            id: row

                            required property int index
                            required property string modelData

                            width: fileList.width - VLCStyle.spacing_12
                            height: VLCStyle.dp(36, VLCStyle.scale)

                            Rectangle {
                                anchors.fill: parent
                                radius: VLCStyle.radius_s
                                color: rowHover.hovered ? fieldTheme.bg.highlight : "transparent"
                            }

                            HoverHandler { id: rowHover }

                            Widgets.SvgIcon {
                                id: rowIcon

                                x: VLCStyle.spacing_8
                                anchors.verticalCenter: parent.verticalCenter
                                name: "clapperboard"
                                size: VLCStyle.icon_normal
                                color: theme.fg.secondary
                            }

                            Text {
                                anchors.left: rowIcon.right
                                anchors.leftMargin: VLCStyle.spacing_8
                                anchors.right: removeButton.left
                                anchors.rightMargin: VLCStyle.spacing_8
                                anchors.verticalCenter: parent.verticalCenter
                                text: oa.displayPath(row.modelData)
                                color: theme.fg.primary
                                font.pixelSize: VLCStyle.text_body
                                elide: Text.ElideMiddle
                                textFormat: Text.PlainText
                            }

                            T.AbstractButton {
                                id: removeButton

                                anchors.right: parent.right
                                anchors.rightMargin: VLCStyle.spacing_4
                                anchors.verticalCenter: parent.verticalCenter
                                width: VLCStyle.dp(28, VLCStyle.scale)
                                height: width
                                hoverEnabled: true
                                onClicked: root.removeFile(row.index)

                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Remove")

                                background: Rectangle {
                                    radius: VLCStyle.radius_s
                                    color: removeButton.hovered ? theme.hoverPlate : "transparent"
                                    border.width: removeButton.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                                    border.color: theme.visualFocus
                                }

                                contentItem: Item {
                                    Widgets.SvgIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: VLCStyle.icon_small
                                        color: theme.fg.primary
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    spacing: VLCStyle.spacing_8
                    visible: root.files.length > 0

                    Widgets.DialogButton {
                        text: qsTr("Add Files…")
                        onClicked: root.addFiles(oa.pickFiles())
                    }

                    Widgets.DialogButton {
                        text: qsTr("Clear")
                        onClicked: root.files = []
                    }
                }

                Rule { width: parent.width }

                Row {
                    width: parent.width
                    spacing: VLCStyle.spacing_12
                    enabled: root.files.length > 0

                    DialogHeading {
                        width: parent.width - subtitleToggle.width - parent.spacing
                        label: qsTr("Subtitle File")
                        labelSuffix: qsTr("(optional)")
                        helper: qsTr("Use an extra subtitle file with these files.")
                    }

                    Widgets.CheckButton {
                        id: subtitleToggle

                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.useSubtitle
                        onClicked: root.useSubtitle = checked
                        Accessible.name: qsTr("Use a subtitle file")
                    }
                }

                Row {
                    width: parent.width
                    spacing: VLCStyle.spacing_8
                    visible: root.useSubtitle && root.files.length > 0

                    Field {
                        width: parent.width - browseSub.width - parent.spacing
                        readOnly: true
                        text: root.subtitleUrl === "" ? "" : oa.displayPath(root.subtitleUrl)
                        placeholderText: qsTr("Choose a subtitle file")
                    }

                    Widgets.DialogButton {
                        id: browseSub

                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Browse…")
                        onClicked: {
                            const u = oa.pickSubtitle()
                            if (u !== "")
                                root.subtitleUrl = u
                        }
                    }
                }
            }

            // ================= Disc
            Column {
                visible: root.currentTab === root.tabDisc
                width: parent.width
                spacing: VLCStyle.spacing_20

                DialogHeading {
                    width: parent.width
                    label: qsTr("Disc Selection")
                    helper: qsTr("Choose the kind of disc and the drive or folder it is in.")
                }

                Widgets.SegmentedControl {
                    width: parent.width
                    height: VLCStyle.dp(34, VLCStyle.scale)
                    compact: true
                    model: [qsTr("DVD"), qsTr("Blu-ray"), qsTr("Audio CD"), qsTr("VCD"), qsTr("DVD Audio")]
                    currentIndex: root.discType
                    onActivated: (index) => {
                        root.discType = index
                        root.discTitle = 0
                        root.discChapter = 0
                        root.selectDefaultDisc()
                    }
                }

                Labeled {
                    width: parent.width
                    label: qsTr("Disc device")

                    Row {
                        width: parent.width
                        spacing: VLCStyle.spacing_8

                        DialogDropdown {
                            width: parent.width - browseDisc.width - ejectDisc.width - 2 * parent.spacing
                            model: root.discList.map(d => d.label)
                            currentIndex: root.discIndex
                            displayText: root.discList.length === 0 ? qsTr("No disc found") : currentText
                            enabled: root.discList.length > 0
                            onActivated: (index) => root.discIndex = index
                        }

                        Widgets.DialogButton {
                            id: browseDisc

                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Browse…")
                            onClicked: {
                                const dir = oa.pickDiscFolder()
                                if (dir === "")
                                    return
                                const list = root.discList.slice()
                                list.push({ path: dir, label: dir })
                                root.discList = list
                                root.discIndex = list.length - 1
                            }
                        }

                        Widgets.DialogButton {
                            id: ejectDisc

                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Eject")
                            enabled: root.discIndex >= 0
                            onClicked: oa.eject(root.discList[root.discIndex].path)
                        }
                    }
                }

                Rule { width: parent.width }

                DialogHeading {
                    width: parent.width
                    label: qsTr("Starting Position")
                    helper: qsTr("Leave on Default to start at the beginning.")
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: VLCStyle.spacing_20
                    rowSpacing: VLCStyle.spacing_16

                    readonly property real cellWidth: (width - columnSpacing) / 2

                    Labeled {
                        width: parent.cellWidth
                        label: root.discType === root.discVcd ? qsTr("Entry")
                               : root.discType === root.discCdda ? qsTr("Track") : qsTr("Title")

                        Spin {
                            width: parent.width
                            from: 0
                            to: 999
                            zeroText: qsTr("Default")
                            value: root.discTitle
                            onValueModified: root.discTitle = value
                        }
                    }

                    Labeled {
                        visible: root.discType === root.discDvd || root.discType === root.discDvda
                        width: parent.cellWidth
                        label: qsTr("Chapter")

                        Spin {
                            width: parent.width
                            from: 0
                            to: 999
                            zeroText: qsTr("Default")
                            value: root.discChapter
                            onValueModified: root.discChapter = value
                        }
                    }

                    Labeled {
                        visible: root.discType === root.discDvd || root.discType === root.discVcd
                        width: parent.cellWidth
                        label: qsTr("Audio track")

                        Spin {
                            width: parent.width
                            from: -1
                            to: 255
                            zeroText: qsTr("Default")
                            zeroValue: -1
                            value: root.discAudio
                            onValueModified: root.discAudio = value
                        }
                    }

                    Labeled {
                        visible: root.discType === root.discDvd || root.discType === root.discVcd
                        width: parent.cellWidth
                        label: qsTr("Subtitle track")

                        Spin {
                            width: parent.width
                            from: -1
                            to: 255
                            zeroText: qsTr("Default")
                            zeroValue: -1
                            value: root.discSubtitle
                            onValueModified: root.discSubtitle = value
                        }
                    }
                }

                Row {
                    visible: root.discType === root.discDvd || root.discType === root.discBluray
                    width: parent.width
                    spacing: VLCStyle.spacing_12

                    DialogHeading {
                        width: parent.width - menusToggle.width - parent.spacing
                        label: qsTr("No disc menus")
                        helper: qsTr("Skip the menus of the disc and play the main title.")
                    }

                    Widgets.CheckButton {
                        id: menusToggle

                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.discNoMenus
                        onClicked: root.discNoMenus = checked
                        Accessible.name: qsTr("No disc menus")
                    }
                }
            }

            // ================= Network
            NetworkStreamForm {
                id: network

                visible: root.currentTab === root.tabNetwork
                width: parent.width

                onSubmitRequested: root.accept()
            }

            // ================= Capture
            Column {
                visible: root.currentTab === root.tabCapture
                width: parent.width
                spacing: VLCStyle.spacing_20

                DialogHeading {
                    width: parent.width
                    label: qsTr("Capture Mode")
                    helper: qsTr("Play or record what a camera, a microphone or your display sees.")
                }

                DialogDropdown {
                    width: parent.width
                    model: oa.captureModes.map(m => m.label)
                    currentIndex: root.captureModeIndex
                    onActivated: (index) => root.captureModeIndex = index
                }

                Rule { width: parent.width }

                Labeled {
                    visible: root.captureMode === "camera"
                    width: parent.width
                    label: qsTr("Video device")

                    DialogDropdown {
                        width: parent.width
                        model: root.videoDevices.map(d => d.label)
                        currentIndex: root.videoDeviceIndex
                        displayText: root.videoDevices.length === 0 ? qsTr("Default device") : currentText
                        onActivated: (index) => root.videoDeviceIndex = index
                    }
                }

                Labeled {
                    visible: root.captureMode === "camera" || root.captureMode === "audio"
                    width: parent.width
                    label: qsTr("Audio device")

                    DialogDropdown {
                        width: parent.width
                        // camera: the first entry is "no audio"
                        model: (root.captureMode === "camera" ? [qsTr("None")] : []).concat(root.audioDevices.map(d => d.label))
                        currentIndex: root.captureMode === "camera" ? root.audioDeviceIndex
                                                                     : Math.max(0, root.audioDeviceIndex - 1)
                        onActivated: (index) => root.audioDeviceIndex = root.captureMode === "camera" ? index : index + 1
                    }
                }

                Labeled {
                    visible: root.captureMode === "screen"
                    width: parent.width
                    label: qsTr("Frame rate")

                    Column {
                        width: parent.width
                        spacing: VLCStyle.spacing_8

                        Field {
                            width: VLCStyle.dp(160, VLCStyle.scale)
                            text: "1.00"
                            validator: DoubleValidator { bottom: 0.01; top: 100; decimals: 2; notation: DoubleValidator.StandardNotation }
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onTextChanged: {
                                const v = parseFloat(text)
                                root.captureFps = (isNaN(v) || v <= 0) ? 1.0 : Math.min(100, v)
                            }
                            Accessible.name: qsTr("Frame rate")
                        }

                        Text {
                            width: parent.width
                            text: qsTr("Your display will be opened and played in order to stream or save it. Desired frame rate for the capture, in frames per second.")
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.text_body
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                        }
                    }
                }
            }

            Rule { width: parent.width }

            // ================= Show more options
            T.AbstractButton {
                id: moreToggle

                width: parent.width
                height: VLCStyle.dp(34, VLCStyle.scale)
                checkable: true
                checked: root.moreOptions
                onToggled: root.moreOptions = checked
                hoverEnabled: true

                Accessible.role: Accessible.Button
                Accessible.name: root.moreOptions ? qsTr("Hide more options") : qsTr("Show more options")

                background: Rectangle {
                    radius: VLCStyle.radius_m
                    color: moreToggle.hovered ? theme.hoverPlate : "transparent"
                    border.width: moreToggle.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                    border.color: theme.visualFocus
                }

                contentItem: Item {
                    Text {
                        x: VLCStyle.spacing_8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.moreOptions ? qsTr("Hide more options") : qsTr("Show more options")
                        color: theme.fg.heading
                        font.pixelSize: VLCStyle.text_heading
                        font.weight: VLCStyle.fontWeight_regular
                        textFormat: Text.PlainText
                    }

                    Widgets.SvgIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: VLCStyle.spacing_8
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.moreOptions ? "chevron-up" : "chevron-down"
                        size: VLCStyle.icon_normal
                        color: theme.fg.primary
                    }
                }
            }

            Column {
                visible: root.moreOptions
                width: parent.width
                spacing: VLCStyle.spacing_16

                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: VLCStyle.spacing_16
                    rowSpacing: VLCStyle.spacing_16

                    readonly property real cellWidth: (width - 2 * columnSpacing) / 3

                    Labeled {
                        width: parent.cellWidth
                        label: qsTr("Caching (ms)")

                        Spin {
                            width: parent.width
                            from: 0
                            to: 60000
                            stepSize: 100
                            value: root.caching
                            onValueModified: root.caching = value
                        }
                    }

                    Labeled {
                        width: parent.cellWidth
                        label: qsTr("Start time")

                        Field {
                            id: startField

                            width: parent.width
                            placeholderText: "0:00:00"
                            color: (text !== "" && root.startSeconds < 0) ? theme.fg.negative : theme.fg.primary
                            Accessible.name: qsTr("Start time")
                        }
                    }

                    Labeled {
                        width: parent.cellWidth
                        label: qsTr("Stop time")

                        Field {
                            id: stopField

                            width: parent.width
                            placeholderText: "0:00:00"
                            color: (text !== "" && root.stopSeconds < 0) ? theme.fg.negative : theme.fg.primary
                            Accessible.name: qsTr("Stop time")
                        }
                    }
                }

                Labeled {
                    width: parent.width
                    label: qsTr("Extra options")

                    Field {
                        id: extraField

                        width: parent.width
                        placeholderText: qsTr("e.g., :no-audio :network-caching=1500")
                        Accessible.name: qsTr("Extra options")
                    }
                }

                Row {
                    width: parent.width
                    spacing: VLCStyle.spacing_12

                    DialogHeading {
                        width: parent.width - slaveToggle.width - parent.spacing
                        label: qsTr("Play another media synchronously")
                        helper: qsTr("Plays a second file at the same time, e.g. an audio track.")
                    }

                    Widgets.CheckButton {
                        id: slaveToggle

                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.useSlave
                        onClicked: root.useSlave = checked
                        Accessible.name: qsTr("Play another media synchronously")
                    }
                }

                Row {
                    width: parent.width
                    spacing: VLCStyle.spacing_8
                    visible: root.useSlave

                    Field {
                        width: parent.width - browseSlave.width - parent.spacing
                        readOnly: true
                        text: root.slaveUrl === "" ? "" : oa.displayPath(root.slaveUrl)
                        placeholderText: qsTr("Choose a media file")
                    }

                    Widgets.DialogButton {
                        id: browseSlave

                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Browse…")
                        onClicked: {
                            const u = oa.pickMedia()
                            if (u !== "")
                                root.slaveUrl = u
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.request.items.join(" ") + root.request.options.map(o => " :" + o).join("")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.text_caption
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    Accessible.name: qsTr("Resulting MRL")
                }
            }
        }
    }
}
