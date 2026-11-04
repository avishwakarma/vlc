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

// One row of a settings page: label (+ info tooltip) on the left, the control
// on the right. The control is picked from the ConfigOption type unless `kind`
// says otherwise.
//
//   SettingRow { option: SettingsModel.option("qt-name-in-title"); label: qsTr("Show the file name in the title bar") }
//
// kind: "auto" | "toggle" | "dropdown" | "segmented" | "slider" | "text" | "number"
//       | "password" | "file" | "folder" | "swatches" | "button"
// Rows hide themselves when the option is not available, when a search is
// active and they do not match, and dim (0.3, disabled) while `dependsOn` is off.
FocusScope {
    id: row

    readonly property bool isSettingRow: true

    // --- model

    property ConfigOption option: null

    // Figma label; defaults to the label VLC gives the option
    property string label: option ? option.text : ""

    // tooltip behind the "i" icon; defaults to the option's long text
    property string info: option ? option.longText : ""

    // extra search keywords
    property string keywords: ""

    // deep link target: pulses once (SettingsWindow.openSetting)
    property bool highlighted: false

    property string kind: "auto"

    // [{value, text, iconName?}] overriding option.choices
    property var choices: null

    // toggle mapping (e.g. ON = Always for an integer option)
    property var valueOn: true
    property var valueOff: false

    // an option that must be "on" for this row to be enabled
    property ConfigOption dependsOn: null
    property var dependsOnValue: true

    // set to false for rows without a backing option (custom controls, buttons)
    property bool needsOption: true

    // number / slider presentation
    property string suffix: ""
    property real valueScale: 1.0       // displayed = value * valueScale
    property real from: NaN             // displayed units; NaN = option range
    property real to: NaN
    property real stepSize: 1
    property bool ticks: false

    // button rows
    property string buttonText: ""
    property real buttonWidth: VLCStyle.dp(100, VLCStyle.scale)
    property string confirmText: ""     // non-empty: ask before emitting activated()
    property string confirmAction: buttonText
    signal activated()

    // custom control (kind: "custom")
    property Component customControl: null

    // --- state

    readonly property real controlWidth: VLCStyle.dp(320, VLCStyle.scale)

    readonly property var _choiceList: choices ? choices : (option ? option.choices : [])

    readonly property int _choiceIndex: {
        const list = _choiceList
        const v = option ? option.value : undefined
        for (let i = 0; i < list.length; ++i) {
            if (list[i].value == v) // loose: qint64 vs number, bool vs int
                return i
        }
        return -1
    }

    readonly property string _kind: {
        if (kind !== "auto")
            return kind
        if (!option)
            return "text"
        switch (option.type) {
        case ConfigOption.Bool: return "toggle"
        case ConfigOption.Color: return "swatches"
        case ConfigOption.File: return "file"
        case ConfigOption.Directory: return "folder"
        case ConfigOption.Password: return "password"
        case ConfigOption.Int:
        case ConfigOption.Float:
            if (_choiceList.length > 0)
                return "dropdown"
            return option.hasRange ? "slider" : "number"
        default:
            return _choiceList.length > 0 ? "dropdown" : "text"
        }
    }

    readonly property bool available: !needsOption || (option && option.available)

    readonly property string filter: _page ? _page.filter : ""

    readonly property bool matchesFilter: {
        const f = filter.trim().toLowerCase()
        if (f === "")
            return true
        return (label + " " + (option ? option.text : "") + " " + keywords + " " + (_section ? _section.title : "")).toLowerCase().indexOf(f) !== -1
    }

    // true when the row takes part in the layout
    readonly property bool shown: available && matchesFilter

    readonly property bool depsOk: !dependsOn || !dependsOn.available
                                   || dependsOn.value == dependsOnValue

    readonly property Item _page: {
        let p = row.parent
        while (p && !p.isSettingsPage)
            p = p.parent
        return p
    }

    readonly property Item _section: {
        let p = row.parent
        while (p && !p.isSettingSection)
            p = p.parent
        return p
    }

    // the control (for keyboard focus)
    readonly property Item control: loader.item

    visible: shown
    onShownChanged: if (_section) _section.update()
    Component.onCompleted: if (_section) _section.update()

    Layout.fillWidth: true
    implicitHeight: Math.max(VLCStyle.dp(32, VLCStyle.scale), loader.implicitHeight) + 2 * VLCStyle.dp(5, VLCStyle.scale)
    implicitWidth: VLCStyle.dp(600, VLCStyle.scale)

    // a row that depends on another option stays hoverable (its tooltip says why it is off)
    readonly property string _requires: (!depsOk && dependsOn)
                                        ? qsTr("Requires \"%1\"").arg(dependsOn.text) : ""

    onHighlightedChanged: if (highlighted) highlightTimer.restart()

    Timer {
        id: highlightTimer
        interval: 2400
        onTriggered: row.highlighted = false
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.radius_s
        color: Qt.alpha(theme.accent, 0.22)
        border.width: VLCStyle.border
        border.color: theme.accent
        opacity: row.highlighted ? 1 : 0
        z: -1

        Behavior on opacity {
            NumberAnimation { duration: VLCStyle.duration_long }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Pane
    }

    // --- label + info

    Row {
        id: labelRow

        anchors.left: parent.left
        anchors.leftMargin: row.highlighted ? VLCStyle.spacing_8 : 0
        anchors.verticalCenter: parent.verticalCenter

        Behavior on anchors.leftMargin { NumberAnimation { duration: VLCStyle.duration_short } }

        spacing: VLCStyle.spacing_10

        Text {
            id: labelText

            anchors.verticalCenter: parent.verticalCenter

            width: Math.min(implicitWidth, row.width - row.controlWidth - VLCStyle.spacing_12
                            - (infoIcon.visible ? infoIcon.width + labelRow.spacing : 0))

            opacity: row.depsOk ? 1.0 : 0.55

            // the part of the label the search matched is bold and accented
            readonly property string _f: row.filter.trim()
            readonly property int _at: _f !== "" ? row.label.toLowerCase().indexOf(_f.toLowerCase()) : -1
            function _esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

            text: _at < 0 ? row.label
                          : _esc(row.label.substring(0, _at))
                            + "<b><font color=\"" + theme.accentText + "\">" + _esc(row.label.substr(_at, _f.length)) + "</font></b>"
                            + _esc(row.label.substring(_at + _f.length))
            color: theme.fg.primary
            font.pixelSize: VLCStyle.text_body
            font.weight: VLCStyle.fontWeight_regular
            elide: Text.ElideRight
            textFormat: _at < 0 ? Text.PlainText : Text.StyledText
        }

        Widgets.SvgIcon {
            id: infoIcon

            anchors.verticalCenter: parent.verticalCenter

            visible: row.info !== "" || row._requires !== ""
            name: "info"
            size: VLCStyle.dp(18, VLCStyle.scale)
            color: infoHover.hovered ? theme.fg.highlight : theme.fg.secondary

            Behavior on color {
                ColorAnimation { duration: VLCStyle.duration_short }
            }

            HoverHandler {
                id: infoHover
            }

            Widgets.ToolTipExt {
                parent: infoIcon
                x: infoIcon.width + VLCStyle.spacing_6
                y: (infoIcon.height - height) / 2
                visible: infoHover.hovered
                text: row._requires !== "" ? (row.info !== "" ? row._requires + "\n" + row.info : row._requires) : row.info
            }
        }
    }

    // --- control

    Loader {
        id: loader

        anchors.right: parent.right
        anchors.rightMargin: row.highlighted ? VLCStyle.spacing_8 : 0
        anchors.verticalCenter: parent.verticalCenter

        Behavior on anchors.rightMargin { NumberAnimation { duration: VLCStyle.duration_short } }

        focus: true
        enabled: row.depsOk
        opacity: row.depsOk ? 1.0 : 0.45

        Behavior on opacity {
            NumberAnimation { duration: VLCStyle.duration_short }
        }

        sourceComponent: {
            switch (row._kind) {
            case "toggle": return toggleComponent
            case "dropdown": return dropdownComponent
            case "segmented": return segmentedComponent
            case "slider": return sliderComponent
            case "number": return numberComponent
            case "password": return passwordComponent
            case "file":
            case "folder": return fileComponent
            case "swatches": return swatchComponent
            case "button": return buttonComponent
            case "custom": return row.customControl
            default: return textComponent
            }
        }
    }


    Component {
        id: toggleComponent

        Widgets.CheckButton {
            checked: row.option && row.option.value == row.valueOn
            text: ""
            onToggled: row.option.value = checked ? row.valueOn : row.valueOff

            Accessible.name: row.label
        }
    }

    Component {
        id: dropdownComponent

        Widgets.Dropdown {
            implicitWidth: row.controlWidth
            compact: true
            model: row._choiceList
            textRole: "text"
            currentIndex: row._choiceIndex
            displayText: currentIndex >= 0 ? currentText : ""
            onActivated: (index) => row.option.value = row._choiceList[index].value

            Accessible.name: row.label
        }
    }

    Component {
        id: segmentedComponent

        Widgets.SegmentedControl {
            implicitWidth: row.controlWidth
            compact: true
            model: row._choiceList
            currentIndex: row._choiceIndex
            onActivated: (index) => row.option.value = row._choiceList[index].value

            Accessible.name: row.label
        }
    }

    Component {
        id: textComponent

        Widgets.TextFieldExt {
            implicitWidth: row.controlWidth
            implicitHeight: VLCStyle.input_h
            text: (row.option && row.option.value !== undefined) ? String(row.option.value) : ""
            selectByMouse: true
            onEditingFinished: if (row.option && text !== String(row.option.value ?? "")) row.option.value = text

            Accessible.name: row.label
        }
    }

    Component {
        id: passwordComponent

        Widgets.TextFieldExt {
            implicitWidth: row.controlWidth
            implicitHeight: VLCStyle.input_h
            echoMode: TextInput.Password
            text: (row.option && row.option.value !== undefined) ? String(row.option.value) : ""
            selectByMouse: true
            onEditingFinished: if (row.option && text !== String(row.option.value ?? "")) row.option.value = text

            Accessible.name: row.label
        }
    }

    // integer field that shows its suffix ("3 s") while not being edited
    Component {
        id: numberComponent

        Widgets.TextFieldExt {
            id: field

            implicitWidth: row.controlWidth
            implicitHeight: VLCStyle.input_h
            selectByMouse: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator { notation: DoubleValidator.StandardNotation }

            readonly property string raw: (row.option && row.option.value !== undefined)
                                          ? String(Math.round(row.option.value * row.valueScale * 1e6) / 1e6) : ""

            text: activeFocus || row.suffix === "" ? raw : (raw + " " + row.suffix)

            onActiveFocusChanged: if (activeFocus) { text = raw; selectAll() } else text = Qt.binding(() => activeFocus || row.suffix === "" ? raw : (raw + " " + row.suffix))
            onEditingFinished: {
                if (row.option && text !== "" && Number(text) !== Number(raw))
                    row.option.value = Number(text) / row.valueScale
            }

            Accessible.name: row.label
        }
    }

    Component {
        id: fileComponent

        RowLayout {
            spacing: VLCStyle.spacing_10

            Widgets.TextFieldExt {
                id: pathField

                implicitWidth: row.controlWidth - browse.implicitWidth - parent.spacing
                implicitHeight: VLCStyle.input_h
                text: (row.option && row.option.value !== undefined) ? String(row.option.value) : ""
                selectByMouse: true
                onEditingFinished: if (row.option && text !== String(row.option.value ?? "")) row.option.value = text

                Accessible.name: row.label
            }

            Widgets.DialogButton {
                id: browse

                text: qsTr("Browse")
                onClicked: {
                    const current = row.option ? String(row.option.value ?? "") : ""
                    const path = (row._kind === "folder") ? SettingsModel.pickDirectory(current)
                                                          : SettingsModel.pickFile(current, row.option.saveFile)
                    if (path !== "")
                        row.option.value = path
                }
            }
        }
    }

    Component {
        id: swatchComponent

        AccentSwatches {
            option: row.option
        }
    }

    Component {
        id: buttonComponent

        Widgets.DialogButton {
            implicitWidth: row.buttonWidth
            text: row.buttonText
            onClicked: {
                if (row.confirmText !== "" && Window.window && Window.window.confirm)
                    Window.window.confirm(row.label, row.confirmText, row.confirmAction, () => row.activated())
                else
                    row.activated()
            }
        }
    }

    // Figma slider: 320x47 wrapper, 16 px track + 24 px thumb, 6 px ticks, 12 px labels
    Component {
        id: sliderComponent

        Item {
            id: sliderBox

            implicitWidth: row.controlWidth
            implicitHeight: VLCStyle.dp(47, VLCStyle.scale)

            // with `choices` the slider walks the choices and shows their text
            readonly property bool byChoice: row.choices !== null
            readonly property real lo: byChoice ? 0 : (isNaN(row.from) ? (row.option ? row.option.min * row.valueScale : 0) : row.from)
            readonly property real hi: byChoice ? Math.max(1, row.choices.length - 1)
                                                : (isNaN(row.to) ? (row.option ? row.option.max * row.valueScale : 1) : row.to)

            function fmt(v) {
                if (byChoice)
                    return row.choices[Math.round(v)] ? row.choices[Math.round(v)].text : ""
                return (Math.round(v * 100) / 100) + row.suffix
            }

            Widgets.SliderExt {
                id: slider

                y: 0
                width: parent.width
                height: VLCStyle.dp(24, VLCStyle.scale)

                from: sliderBox.lo
                to: sliderBox.hi
                stepSize: sliderBox.byChoice ? 1 : row.stepSize
                snapMode: T.Slider.SnapAlways
                value: sliderBox.byChoice ? Math.max(0, row._choiceIndex)
                                          : (row.option ? row.option.value * row.valueScale : 0)
                focus: true

                topPadding: 0
                bottomPadding: 0

                handleHeight: VLCStyle.dp(24, VLCStyle.scale)
                trackHeight: VLCStyle.dp(16, VLCStyle.scale)

                toolTipTextProvider: (v) => sliderBox.fmt(v)

                onMoved: {
                    if (sliderBox.byChoice)
                        row.option.value = row.choices[Math.round(value)].value
                    else
                        row.option.value = value / row.valueScale
                }

                Accessible.name: row.label

                // tick marks
                Item {
                    visible: row.ticks || sliderBox.byChoice
                    z: 1
                    x: slider.leftPadding + slider.handle.width / 2
                    y: (slider.height - height) / 2
                    height: VLCStyle.dp(6, VLCStyle.scale)
                    width: slider.availableWidth - slider.handle.width

                    readonly property int steps: Math.max(1, Math.round((slider.to - slider.from) / slider.stepSize))

                    Repeater {
                        model: parent.steps + 1

                        delegate: Rectangle {
                            required property int index

                            x: index * parent.width / parent.steps - width / 2
                            width: VLCStyle.border
                            height: parent.height
                            color: theme.fg.secondary
                            opacity: 0.6
                        }
                    }
                }
            }

            Item {
                y: VLCStyle.dp(28, VLCStyle.scale)
                width: parent.width
                height: VLCStyle.dp(15, VLCStyle.scale)

                Text {
                    anchors.left: parent.left
                    text: sliderBox.fmt(sliderBox.lo)
                    color: theme.fg.highlight
                    font.pixelSize: VLCStyle.text_caption
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sliderBox.fmt((sliderBox.lo + sliderBox.hi) / 2)
                    color: theme.fg.highlight
                    font.pixelSize: VLCStyle.text_caption
                }
                Text {
                    anchors.right: parent.right
                    text: sliderBox.fmt(sliderBox.hi)
                    color: theme.fg.highlight
                    font.pixelSize: VLCStyle.text_caption
                }
            }
        }
    }
}
