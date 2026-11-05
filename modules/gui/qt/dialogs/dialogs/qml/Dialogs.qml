/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style

Item {
    id: root

    //---------------------------------------------------------------------------------------------
    // Properties
    //---------------------------------------------------------------------------------------------

    property Item bgContent: null

    //---------------------------------------------------------------------------------------------
    // Signal
    //---------------------------------------------------------------------------------------------

    signal restoreFocus();

    //---------------------------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------------------------

    Component.onCompleted: if (DialogErrorModel.repeatedMessageCount){
                               hideErrorPopupTimer.restart()
                               errorPopup.state = "visible"
                           }

    Component.onDestruction: {
        if (questionDialog.dialogId !== null) {
            vlcDialog.dismiss(questionDialog.dialogId)
            questionDialog.dialogId = null
        } if (loginDialog.dialogId !== null) {
            vlcDialog.dismiss(loginDialog.dialogId)
            loginDialog.dialogId = null
        }
    }

    //---------------------------------------------------------------------------------------------
    // Functions
    //---------------------------------------------------------------------------------------------

    function ask(text, acceptCb, rejectCb, buttons) {
        customDialog.ask(text, acceptCb, rejectCb, buttons)
    }

    //---------------------------------------------------------------------------------------------
    // Connections
    //---------------------------------------------------------------------------------------------

    VLCDialog
    {
        id: vlcDialog

        Component.onCompleted: {
            VLCDialogModel.provider = vlcDialog
        }

        Component.onDestruction: {
            // Only clear the provider if we are still the current one.
            if (VLCDialogModel.provider === vlcDialog)
                VLCDialogModel.provider = null
        }

        onLogin: (dialogId, title, text, defaultUsername, askStore) => {
            loginDialog.dialogId = dialogId
            loginDialog.title = title
            loginDialog.defaultUsername = defaultUsername
            loginDialog.text = text
            loginDialog.askStore = askStore
            loginDialog.open()
        }

        onQuestion: (dialogId, title, text, type, cancel, action1, action2) => {
            questionDialog.dialogId = dialogId
            questionDialog.title = title
            questionDialog.text = text
            questionDialog.cancelTxt = cancel
            questionDialog.action1Txt = action1
            questionDialog.action2Txt = action2
            questionDialog.open()
        }

        onProgress: (dialogId, title, text, indeterminate, position, cancel) => {
            progressDialog.dialogId = dialogId
            progressDialog.title = title
            progressDialog.text = text
            progressDialog.cancelTxt = cancel
            progressDialog.position = position
            progressDialog.interderminate = indeterminate
            progressDialog.open()
        }

        onProgressUpdated: (dialogId, position, text) => {
            if (progressDialog.dialogId !== dialogId) {
                console.warn("progress event on an inexisting dialog")
                return
            }
            progressDialog.text = text
            progressDialog.position = position
        }

        onCancelled: (dialogId) => {
            if (questionDialog.dialogId === dialogId) {
                questionDialog.close()
                questionDialog.dialogId = null
                dismiss(dialogId)
            } else if (loginDialog.dialogId === dialogId)  {
                loginDialog.close()
                loginDialog.dialogId = null
                dismiss(dialogId)
            } else if (progressDialog.dialogId === dialogId) {
                progressDialog.close()
                progressDialog.dialogId = null
                dismiss(dialogId)
            } else {
                dismiss(dialogId)
            }
        }
    }

    Connections
    {
        target: DialogErrorModel

        function onCountChanged() {
            hideErrorPopupTimer.restart()
            errorPopup.state = "visible"
        }
    }

    //---------------------------------------------------------------------------------------------
    // Childs
    //---------------------------------------------------------------------------------------------

    Widgets.DrawerExt {
        id: errorPopup

        property string messageText
        property int repeatedMessageCount: 0

        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: VLCStyle.margin_small
        }

        edge: Widgets.DrawerExt.Edges.Bottom
        width: contentItem?.layoutWidth ?? 0
        height: contentItem?.height ?? 0
        z: 10

        ColorContext {
            id: errorMsgTheme
            palette: VLCStyle.palette
            colorSet: ColorContext.View
        }

        component: Rectangle {
            // floating card like the form dialogs, a negative badge marks it as an error
            color: Qt.alpha(errorMsgTheme.bg.primary, 0.95)
            border.width: VLCStyle.dp(1, VLCStyle.scale)
            border.color: errorMsgTheme.separator

            height: layout.implicitHeight + 2 * VLCStyle.spacing_12
            radius: VLCStyle.radius_xl

            property real layoutWidth: layout.width + 2 * VLCStyle.spacing_16

            Accessible.role: Accessible.AlertMessage
            Accessible.name: qsTr("error popup")

            RowLayout {
                id: layout

                x: VLCStyle.spacing_16
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.spacing_12

                Rectangle {
                    Layout.preferredWidth: VLCStyle.toggle_h
                    Layout.preferredHeight: VLCStyle.toggle_h
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: errorMsgTheme.bg.negative

                    Widgets.SvgIcon {
                        anchors.centerIn: parent
                        name: "info"
                        size: VLCStyle.icon_normal
                        color: errorMsgTheme.fg.primary
                    }
                }

                T.Label {
                    id: messageText

                    Layout.maximumWidth: root.width * 0.5
                    Layout.alignment: Qt.AlignVCenter

                    text: (DialogErrorModel.repeatedMessageCount > 1 ? '[' + DialogErrorModel.repeatedMessageCount + '] ' : '')
                          + DialogErrorModel.notificationText

                    wrapMode: Text.Wrap
                    font.pixelSize: VLCStyle.text_body
                    font.weight: VLCStyle.fontWeight_regular
                    color: errorMsgTheme.fg.primary
                }

                Widgets.DialogButton {
                    id: detailsBtn

                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("Show Details")

                    onClicked: {
                        hideErrorPopupTimer.stop()
                        errorPopup.state = "hidden"
                        DialogErrorModel.resetRepeatedMessageCount()
                        DialogsProvider.messagesDialog(1)
                    }
                }

                Widgets.DialogButton {
                    id: closeBtn

                    Layout.alignment: Qt.AlignVCenter
                    text: qsTr("Dismiss")

                    onClicked: {
                        hideErrorPopupTimer.stop()
                        errorPopup.state = "hidden"
                        DialogErrorModel.resetRepeatedMessageCount()
                    }
                }
            }

            Widgets.RoundedRectangleShadow {
                blurRadius: VLCStyle.shadow_floating.blur
                yOffset: VLCStyle.shadow_floating.y
                color: VLCStyle.shadowColor(VLCStyle.shadow_floating.alpha)
                z: -1
            }
        }

        state: "hidden"

        Timer {
            id: hideErrorPopupTimer
            interval: 8000
            repeat: false
            onTriggered: {
                errorPopup.state = "hidden"
                DialogErrorModel.resetRepeatedMessageCount()
            }
        }
    }

    ModalDialog {
        id: loginDialog

        //use var here as DialogId is a QGadget and passed by value
        property var dialogId: null
        property string defaultUsername: ""
        property string text: ""
        property bool askStore: true

        onAboutToHide: restoreFocus()
        onAboutToShow: {
            username.text = loginDialog.defaultUsername
            password.text = ""
            savePassword.checked = false
        }
        rootWindow: root.bgContent

        contentItem: ColumnLayout {
            readonly property ColorContext colorContext: ColorContext {
                palette: VLCStyle.palette
                colorSet: ColorContext.View
            }
            spacing: VLCStyle.spacing_12

            Text {
                Layout.fillWidth: true
                visible: loginDialog.text !== ""
                text: loginDialog.text
                color: loginDialog.colorContext.fg.secondary
                font.pixelSize: VLCStyle.text_body
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            Text {
                text: qsTr("Username")
                color: loginDialog.colorContext.fg.primary
                font.pixelSize: VLCStyle.text_body
            }

            Widgets.TextFieldExt {
                id: username

                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(41, VLCStyle.scale)
                Layout.topMargin: -VLCStyle.spacing_8
                leftPadding: VLCStyle.spacing_12
                rightPadding: VLCStyle.spacing_16
                selectByMouse: true
                focus: true

                Navigation.downItem: password
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
                onAccepted: password.forceActiveFocus()
            }

            Text {
                text: qsTr("Password")
                color: loginDialog.colorContext.fg.primary
                font.pixelSize: VLCStyle.text_body
            }

            Widgets.TextFieldExt {
                id: password

                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(41, VLCStyle.scale)
                Layout.topMargin: -VLCStyle.spacing_8
                leftPadding: VLCStyle.spacing_12
                rightPadding: VLCStyle.spacing_16
                selectByMouse: true
                echoMode: TextInput.Password

                Navigation.upItem: username
                Navigation.downItem: savePassword
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
                onAccepted: loginOk.clicked()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.spacing_4
                visible: loginDialog.askStore

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Remember this login")
                    color: loginDialog.colorContext.fg.primary
                    font.pixelSize: VLCStyle.text_body
                }

                Widgets.CheckButton {
                    id: savePassword

                    Navigation.upItem: password
                    Navigation.downItem: loginOk
                    Keys.priority: Keys.AfterItem
                    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
                }
            }
        }

        footer: ModalFooter {
            Widgets.DialogButton {
                id: loginCancel
                text: qsTr("Cancel")

                Navigation.upItem: savePassword
                Navigation.rightItem: loginOk

                onClicked: {
                    loginDialog.reject()
                    loginDialog.close()
                }
            }

            Widgets.DialogButton {
                id: loginOk
                kind: Widgets.DialogButton.Accent
                text: qsTr("Log In")

                Navigation.upItem: savePassword
                Navigation.leftItem: loginCancel

                onClicked: {
                    loginDialog.accept()
                    loginDialog.close()
                }
            }
        }

        onAccepted: {
            if (loginDialog.dialogId !== null) {
                vlcDialog.post_login(loginDialog.dialogId, username.text, password.text, savePassword.checked)
                loginDialog.dialogId = null
            }
        }
        onRejected: {
            if (loginDialog.dialogId !== null) {
                vlcDialog.dismiss(loginDialog.dialogId)
                loginDialog.dialogId = null
            }
        }
    }

    ModalDialog {
        id: progressDialog

        property var dialogId: null

        property string text : ""
        property string cancelTxt: ""
        property bool interderminate: false
        property real position: 0.0

        onAboutToHide: restoreFocus()
        rootWindow: root.bgContent

        contentItem: ColumnLayout {
            readonly property ColorContext colorContext: ColorContext {
                palette: VLCStyle.palette
                colorSet: ColorContext.View
            }
            spacing: VLCStyle.spacing_16

            Text {
                Layout.fillWidth: true
                focus: false
                font.pixelSize: VLCStyle.text_body
                color: progressDialog.colorContext.fg.primary
                text: progressDialog.text
                wrapMode: Text.Wrap
            }

            Widgets.ProgressBarExt {
                Layout.fillWidth: true

                from: 0.0
                to: 1.0

                indeterminate: progressDialog.interderminate
                value: progressDialog.position
            }
        }

        footer: ModalFooter {
            focus: true

            Widgets.DialogButton {
                focus: true
                visible: text !== ""
                text: progressDialog.cancelTxt

                onClicked: {
                    vlcDialog.dismiss(progressDialog.dialogId)
                    progressDialog.dialogId = null
                    progressDialog.close()
                }
            }
        }
    }

    ModalDialog {
        id: questionDialog

        //use var here as DialogId is a QGadget and passed by value
        property var dialogId: null
        property alias text: content.text
        property alias cancelTxt: cancel.text
        property alias action1Txt: action1.text
        property alias action2Txt: action2.text

        rootWindow: root.bgContent

        onAboutToHide: restoreFocus()

        contentItem: Text {
            id: content
            focus: false
            font.pixelSize: VLCStyle.text_body
            color: questionDialog.colorContext.fg.primary
            wrapMode: Text.Wrap
        }

        footer: ModalFooter {
            focus: true

            Widgets.DialogButton {
                id: cancel

                focus: true
                visible: cancel.text !== ""

                Navigation.rightItem: action1

                onClicked: {
                    vlcDialog.dismiss(questionDialog.dialogId)
                    questionDialog.dialogId = null
                    questionDialog.close()
                }
            }

            Widgets.DialogButton {
                id: action1

                visible: action1.text !== ""
                kind: Widgets.DialogButton.Accent

                Navigation.leftItem: cancel
                Navigation.rightItem: action2

                onClicked: {
                    vlcDialog.post_action1(questionDialog.dialogId)
                    questionDialog.dialogId = null
                    questionDialog.close()
                }
            }

            Widgets.DialogButton {
                id: action2
                visible: action2.text !== ""
                kind: Widgets.DialogButton.Primary

                Navigation.leftItem: action1

                onClicked: {
                    vlcDialog.post_action2(questionDialog.dialogId)
                    questionDialog.dialogId = null
                    questionDialog.close()
                }
            }
        }
    }

    CustomDialog {
        id: customDialog
        rootWindow: root.bgContent
        onAboutToHide: restoreFocus()
    }

    Loader {
        id: toolbarEditorDialogLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/ToolbarEditorDialog.qml"

        Connections {
            target: DialogsProvider

            function onShowToolbarEditorDialog() {
                toolbarEditorDialogLoader.active = true
                toolbarEditorDialogLoader.item.open()
            }
        }
    }

    Loader {
        id: settingsWindowLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/SettingsWindow.qml"

        // deep links: SettingsModel.openSettings(page, option) from anywhere in the UI
        Connections {
            target: SettingsModel

            function onSettingsRequested(page, option) {
                settingsWindowLoader.active = true
                const window = settingsWindowLoader.item
                window.open()
                window.openSetting(page, option)
            }
        }

        Connections {
            target: DialogsProvider

            function onShowSettingsDialog() {
                settingsWindowLoader.active = true
                const window = settingsWindowLoader.item
                if (window.visible) {
                    window.raise()
                    window.requestActivate()
                } else {
                    window.open()
                }
            }
        }
    }

    Loader {
        id: onboardingLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/OnboardingWindow.qml"

        function show() {
            if (!DialogsProvider.takeOnboardingRequest())
                return
            active = true
            item.open()
        }

        // the request may have been made before this item was created
        Component.onCompleted: show()

        Connections {
            target: DialogsProvider

            function onShowOnboarding() {
                onboardingLoader.show()
            }
        }

        Connections {
            target: onboardingLoader.item
            ignoreUnknownSignals: true

            function onUnload() {
                onboardingLoader.active = false
            }
        }
    }

    // Form dialogs (dialogs/forms)
    Loader {
        id: openNetworkStreamLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/OpenNetworkStream.qml"

        Connections {
            target: DialogsProvider

            function onShowOpenNetworkStream() {
                openNetworkStreamLoader.active = true
                const window = openNetworkStreamLoader.item
                if (window.visible) {
                    window.raise()
                    window.requestActivate()
                } else {
                    window.open()
                }
            }
        }
    }

    Loader {
        id: newPlaylistLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/NewPlaylist.qml"

        Connections {
            target: DialogsProvider

            function onShowNewPlaylist() {
                newPlaylistLoader.active = true
                const window = newPlaylistLoader.item
                if (window.visible) {
                    window.raise()
                    window.requestActivate()
                } else {
                    window.open()
                }
            }
        }
    }

    Loader {
        id: keyboardShortcutsLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/KeyboardShortcuts.qml"

        Connections {
            target: DialogsProvider

            function onShowKeyboardShortcuts() {
                keyboardShortcutsLoader.active = true
                const window = keyboardShortcutsLoader.item
                if (window.visible) {
                    window.raise()
                    window.requestActivate()
                } else {
                    window.open()
                }
            }
        }
    }

    Loader {
        id: addSubtitlesLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/AddSubtitles.qml"

        Connections {
            target: DialogsProvider

            function onShowAddSubtitles() {
                addSubtitlesLoader.active = true
                const window = addSubtitlesLoader.item
                if (window.visible) {
                    window.raise()
                    window.requestActivate()
                } else {
                    window.open()
                }
            }
        }
    }

    // legacy widget dialogs replaced by QML (Media Information, Go to Time, Chapters and Bookmarks,
    // Add to Playlist, Messages), routed by DialogsProvider
    Loader {
        id: mediaInfoLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/MediaInfo.qml"

        Connections {
            target: DialogsProvider

            function onShowMediaInfo(tab, toggle) {
                mediaInfoLoader.active = true
                mediaInfoLoader.item.present(tab, toggle)
            }
        }
    }

    Loader {
        id: goToTimeLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/GoToTime.qml"

        Connections {
            target: DialogsProvider

            function onShowGoToTime() {
                goToTimeLoader.active = true
                goToTimeLoader.item.present()
            }
        }
    }

    Loader {
        id: bookmarksLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/Bookmarks.qml"

        Connections {
            target: DialogsProvider

            function onShowBookmarks(tab) {
                bookmarksLoader.active = true
                bookmarksLoader.item.present(tab)
            }
        }
    }

    Loader {
        id: addToPlaylistLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/AddToPlaylist.qml"

        Connections {
            target: DialogsProvider

            function onShowAddToPlaylist(playlistType) {
                addToPlaylistLoader.active = true
                addToPlaylistLoader.item.present()
            }
        }
    }

    Loader {
        id: messagesLoader
        active: false
        source: "qrc:///qt/qml/VLC/Dialogs/Messages.qml"

        Connections {
            target: DialogsProvider

            function onShowMessages() {
                messagesLoader.active = true
                messagesLoader.item.present()
            }
        }
    }

    // debug aid: VLC_QT_OPEN_FORM opens a form dialog at start-up (see DialogsProvider::openDebugForm)
    Timer {
        interval: 1500
        running: DialogsProvider.debugFormRequest() !== ""
        onTriggered: {
            // sample modal dialogs for visual checks (no backing request, buttons only close)
            const form = DialogsProvider.debugFormRequest()
            if (form === "question") {
                questionDialog.title = "Confirm"
                questionDialog.text = "Do you want to continue playing from where you stopped?"
                questionDialog.cancelTxt = "Cancel"
                questionDialog.action1Txt = "Resume"
                questionDialog.action2Txt = "Start Over"
                questionDialog.open()
            } else if (form === "progress") {
                progressDialog.title = "Updating"
                progressDialog.text = "Scanning folders..."
                progressDialog.cancelTxt = "Cancel"
                progressDialog.position = 0.4
                progressDialog.interderminate = false
                progressDialog.open()
            } else if (form === "login") {
                loginDialog.title = "Authentication required"
                loginDialog.text = "Please enter a user name and a password for smb://BeastCloud.local/Plex"
                loginDialog.defaultUsername = "guest"
                loginDialog.open()
            } else {
                DialogsProvider.openDebugForm()
            }
        }
    }
}
