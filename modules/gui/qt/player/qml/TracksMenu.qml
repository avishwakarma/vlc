
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
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQml.Models

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Player
import VLC.Dialogs

// Popover of the audio / subtitle / settings buttons of the control bar
// (Figma: Controls 491:1780). One 400 px panel anchored above the bar, right
// aligned, with a tab header:
//   mode "tracks":   Video | Audio | Subtitles   (embedded tracks, output device, external subtitles)
//   mode "settings": Playback | Video | Audio | Subtitles + preset footer
// The tabs hold the effect panels (EQ, compressor, spatializer, stereo
// widener, video essential / crop / colours) driven by the Effects controller.
T.Popup {
    id: root

    // "tracks" | "settings"
    property string mode: "tracks"
    property string tab: "audio"

    // time the popup was last closed, lets the owner button turn a click into a toggle
    property double closedAt: 0

    // the wide equalizer panel (opened from the Audio settings tab)
    property alias equalizerPanel: equalizerPanelItem

    readonly property var tabsByMode: ({
        tracks: [
            { id: "video", text: qsTr("Video"), icon: "video" },
            { id: "audio", text: qsTr("Audio"), icon: "audio" },
            { id: "subtitles", text: qsTr("Subtitles"), icon: "subtitles" }
        ],
        settings: [
            { id: "playback", text: qsTr("Playback"), icon: "playback" },
            { id: "video", text: qsTr("Video"), icon: "video" },
            { id: "audio", text: qsTr("Audio"), icon: "audio" },
            { id: "subtitles", text: qsTr("Subtitles"), icon: "subtitles" }
        ]
    })

    readonly property var tabs: tabsByMode[mode]

    readonly property int tabIndex: {
        for (let i = 0; i < tabs.length; ++i)
            if (tabs[i].id === tab)
                return i
        return 0
    }

    // the player item the popup floats over (Player.qml / MainDisplay)
    readonly property real _barTop: (parent && parent.positionSliderY !== undefined) ? parent.positionSliderY : (parent ? parent.height : 0)
    readonly property real _maxHeight: VLCStyle.dp(946, VLCStyle.scale)
    readonly property real _topLimit: VLCStyle.dp(60, VLCStyle.scale)

    width: VLCStyle.popoverPanel_w
    height: Math.max(VLCStyle.dp(320, VLCStyle.scale), Math.min(_maxHeight, _barTop - _topLimit - VLCStyle.popoverPanel_margin))
    x: parent ? parent.width - width - VLCStyle.popoverPanel_margin : 0
    y: _barTop - height - VLCStyle.popoverPanel_margin

    padding: 0
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
    focus: true

    function openMode(newMode, newTab) {
        mode = newMode
        tab = newTab
        open()
    }

    // keep the tab valid when the mode changes
    onModeChanged: {
        if (tabIndex === 0 && tabs[0].id !== tab)
            tab = tabs[0].id
    }

    onClosed: closedAt = Date.now()

    readonly property ColorContext colorContext: ColorContext {
        id: popupTheme
        colorSet: ColorContext.Pane
    }

    // slide up + fade (VLC popups use 150-200 ms)
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: VLCStyle.duration_long }
            NumberAnimation { target: slide; property: "y"; from: VLCStyle.spacing_12; to: 0; duration: VLCStyle.duration_long; easing.type: Easing.OutCubic }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: VLCStyle.duration_short }
            NumberAnimation { target: slide; property: "y"; from: 0; to: VLCStyle.spacing_8; duration: VLCStyle.duration_short }
        }
    }

    background: null

    contentItem: Item {
        id: panel

        focus: true

        // popups live outside of the item tree: hand the palette to the children
        readonly property ColorContext colorContext: ColorContext {
            colorSet: popupTheme.colorSet
            palette: popupTheme.palette
        }

        transform: Translate { id: slide }

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: VLCStyle.radius_l

            color: popupTheme.bg.primary
            opacity: 0.98

            Widgets.RoundedRectangleShadow {
                z: -1
                blurRadius: VLCStyle.shadow_floating.blur
                yOffset: VLCStyle.shadow_floating.y
                color: VLCStyle.shadowColor(VLCStyle.shadow_floating.alpha)
            }
        }

        // clip the content to the rounded surface
        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                PanelTabBar {
                    id: tabBar

                    Layout.fillWidth: true

                    model: root.tabs
                    onCurrentIndexChanged: if (currentIndex >= 0 && root.tabs[currentIndex].id !== root.tab) root.tab = root.tabs[currentIndex].id

                    focus: false

                    Binding {
                        target: tabBar
                        property: "currentIndex"
                        value: root.tabIndex
                        restoreMode: Binding.RestoreNone
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) {
                            pageLoader.forceActiveFocus(Qt.TabFocusReason)
                            event.accepted = true
                        }
                    }
                }

                Loader {
                    id: pageLoader

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    focus: true
                    clip: true

                    sourceComponent: root.mode === "tracks" ? tracksPage
                                   : root.tab === "playback" ? playbackPage
                                   : root.tab === "video" ? videoPage
                                   : root.tab === "audio" ? audioPage
                                   : subtitlesPage

                    onLoaded: {
                        item.opacity = 0
                        fadeIn.target = item
                        fadeIn.restart()
                    }

                    NumberAnimation {
                        id: fadeIn
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: VLCStyle.duration_long
                    }
                }

                Rectangle {
                    visible: root.mode === "settings"
                    Layout.fillWidth: true
                    implicitHeight: VLCStyle.dp(1, VLCStyle.scale)
                    color: popupTheme.separator
                }

                Loader {
                    id: footerLoader

                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0

                    sourceComponent: root.mode === "tracks" ? tracksFooter : settingsFooter
                }
            }
        }
    }

    Component {
        id: tracksPage

        TracksTab {
            kind: root.tab
            onRequestSettings: (tabId) => root.openMode("settings", tabId)
        }
    }

    Component { id: playbackPage; SettingsPlaybackTab {} }
    Component { id: videoPage; SettingsVideoTab {} }
    Component { id: subtitlesPage; SettingsSubtitlesTab {} }

    Component {
        id: audioPage

        SettingsAudioTab {
            onRequestEqualizer: root.equalizerPanel.wanted = !root.equalizerPanel.wanted
        }
    }

    Component {
        id: tracksFooter

        Item {
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale) + 2 * VLCStyle.spacing_20

            Widgets.SettingButton {
                anchors.centerIn: parent

                text: qsTr("Show Preferences")
                onClicked: {
                    root.close()
                    DialogsProvider.prefsDialog()
                }
            }
        }
    }

    Component {
        id: settingsFooter

        ColumnLayout {
            spacing: 0

            readonly property ColorContext colorContext: ColorContext {
                id: footerTheme
                colorSet: ColorContext.View
            }

            // Default Preset, New Preset, saved sets (Figma 2372:8834)
            EffectsDropdown {
                id: presetDropdown

                readonly property var entries: {
                    const list = [{ name: "", text: qsTr("New Preset"), iconName: "add", dim: true, action: "new" }]
                    for (const p of PlayerEffects.presetList)
                        if (p.custom)
                            list.push({ name: p.name, text: p.text, iconName: "more", dim: false, action: "load" })
                    list.push({ name: "", text: qsTr("Default Preset"), iconName: "", dim: false, action: "load" })
                    return list
                }

                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.spacing_20
                Layout.leftMargin: VLCStyle.spacing_20
                Layout.rightMargin: VLCStyle.spacing_20

                compact: false
                openUp: true
                iconRole: "iconName"
                dimRole: "dim"
                textRole: "text"
                model: entries
                currentIndex: {
                    for (let i = 1; i < entries.length; ++i)
                        if (entries[i].action === "load" && entries[i].name === PlayerEffects.activePreset)
                            return i
                    return entries.length - 1
                }
                onActivated: (i) => {
                    const e = entries[i]
                    if (e.action === "new")
                        PlayerEffects.saveSettingsPreset()
                    else
                        PlayerEffects.loadSettingsPreset(e.name)
                }

                Keys.onDeletePressed: {
                    const e = entries[highlightedIndex]
                    if (popup.visible && e && e.iconName === "more")
                        PlayerEffects.deleteSettingsPreset(e.name)
                }

                Accessible.name: qsTr("Settings preset")
            }

            FooterLink {
                id: advanced

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: VLCStyle.spacing_8
                Layout.bottomMargin: VLCStyle.spacing_14

                text: qsTr("Open Advanced Settings")
                iconName: "settings"
                onClicked: {
                    root.close()
                    DialogsProvider.prefsDialog()
                }
            }
        }
    }

    // wide equalizer, Figma 3178:16769
    EqualizerWide {
        id: equalizerPanelItem

        parent: root.parent
        anchorPanel: root
        colorContext.palette: popupTheme.palette
    }
}
