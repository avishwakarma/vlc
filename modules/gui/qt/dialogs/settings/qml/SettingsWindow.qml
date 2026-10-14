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

// Placeholder settings window: proves the SettingsModel/ConfigOption plumbing.
// The redesigned window (nav card, pages, SettingRow) replaces this content.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style

WindowDialog {
    id: root

    title: qsTr("Settings")

    width: 1048
    height: 865
    minimumWidth: 640
    minimumHeight: 480

    standardButtons: DialogButtonBox.Close

    // a sample of every kind of option, including virtual and missing ones
    readonly property var optionNames: [
        "qt-name-in-title",     // Bool
        "qt-system-tray",       // Bool, requires restart
        "qt-max-volume",        // Int with range
        "qt-fs-opacity",        // Float with range
        "qt-auto-raise",        // Int with choices
        "aout",                 // Module
        "audioDevice",          // virtual, depends on aout
        "theme",                // virtual
        "accent",               // virtual Color
        "snapshot-path",        // Directory
        "extraInterface:http",  // virtual Bool (needs lua)
        "video-wallpaper",      // win32 only
        "language",             // not an option outside Windows
    ]

    onRejected: SettingsModel.flush()
    onClosing: SettingsModel.flush()

    contentComponent: ColumnLayout {
        spacing: VLCStyle.margin_small

        Label {
            Layout.fillWidth: true
            color: root.colorContext.fg.primary
            text: SettingsModel.restartPending
                  ? qsTr("Some changes will be applied after VLC restarts.")
                  : qsTr("Placeholder settings window, changes apply immediately.")
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: VLCStyle.margin_xsmall

            model: root.optionNames

            delegate: RowLayout {
                id: row

                required property string modelData
                readonly property ConfigOption option: SettingsModel.option(modelData)

                width: ListView.view.width
                opacity: option.available ? 1.0 : 0.4

                Label {
                    Layout.preferredWidth: 320
                    elide: Text.ElideRight
                    color: root.colorContext.fg.primary
                    text: (row.option.text || row.modelData)
                          + (row.option.available ? "" : " (" + qsTr("unavailable") + ")")
                          + (row.option.modified ? " *" : "")
                }

                Loader {
                    Layout.fillWidth: true
                    enabled: row.option.available
                    sourceComponent: {
                        if (row.option.type === ConfigOption.Bool)
                            return boolEditor
                        if (row.option.choices.length > 0)
                            return choiceEditor
                        return textEditor
                    }

                    Component {
                        id: boolEditor
                        CheckBox {
                            checked: row.option.value === true
                            onToggled: row.option.value = checked
                        }
                    }

                    Component {
                        id: choiceEditor
                        ComboBox {
                            model: row.option.choices
                            textRole: "text"
                            currentIndex: row.option.currentIndex
                            onActivated: (index) => { row.option.currentIndex = index }
                        }
                    }

                    Component {
                        id: textEditor
                        TextField {
                            text: row.option.value !== undefined ? String(row.option.value) : ""
                            onEditingFinished: row.option.value = text
                        }
                    }
                }

                Button {
                    text: qsTr("Reset")
                    enabled: row.option.available && row.option.modified
                    onClicked: row.option.reset()
                }
            }
        }

        Label {
            Layout.fillWidth: true
            color: root.colorContext.fg.secondary
            text: qsTr("%1 hotkeys, configuration folder: %2")
                  .arg(SettingsModel.hotkeys.count)
                  .arg(SettingsModel.configFolder)
        }

        RowLayout {
            Button {
                text: qsTr("Open configuration folder")
                onClicked: SettingsModel.openConfigFolder()
            }
            Button {
                text: qsTr("All options…")
                onClicked: SettingsModel.openAllOptions()
            }
        }
    }
}
