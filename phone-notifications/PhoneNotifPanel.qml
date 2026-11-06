import QtQuick
import QtQuick.Layouts
import "nectar"

// The panel content, drawn like NectarLink's Home page Notifications card (same components, colors, spacing): header
// (History, Clear all), Undo bar, the feed of NotificationItem, and the History / app options / picture Sheets.
// `store` is the PhoneNotifStore. The Theme comes from NectarLink itself (see nectar/README.md).
FocusScope {
    id: pn
    required property var store
    // handles for the test harness (cage)
    property alias feedList: feedView
    property alias historyList: historyColumn
    property alias historySheet: historySheet
    property alias appSheet: appSheet
    property alias rulesSheet: rulesSheet
    property alias previewSheet: imagePreviewSheet
    property alias historySearch: historySearch
    property alias clearAllButton: clearAll
    property alias undoButton: undoBtn
    property alias historyButton: historyBtn

    FontLoader { source: "nectar/fonts/Figtree.ttf" }

    Rectangle {  // the card
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.cardColor
        border.width: Theme.graphite || Theme.hive || Theme.amoled ? 1 : 0
        border.color: Theme.cardBorder
    }

    Component.onCompleted: {
        forceActiveFocus()
        if (store.pendingSheet === "rules") { store.pendingSheet = ""; openRules() }
    }
    function openRules() { store.loadRules(); rulesSheet.open() }

    Column {
        id: feedColumn
        anchors { fill: parent; margins: 8 }
        spacing: 8

        Item {  // header
            width: parent.width
            height: Math.max(header.height, clearAll.height, historyBtn.height)
            Txt {
                id: header
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: historyBtn.visible ? historyBtn.left : (clearAll.visible ? clearAll.left : parent.right)
                anchors.rightMargin: 8
                role: "label"
                muted: true
                text: pn.store.count > 0 ? qsTr("Notifications · %1").arg(pn.store.count) : qsTr("Notifications")
            }
            IconButton {
                id: historyBtn
                anchors.right: clearAll.visible ? clearAll.left : parent.right
                anchors.rightMargin: clearAll.visible ? 8 : 0
                anchors.verticalCenter: parent.verticalCenter
                visible: pn.store.historyEnabled && pn.store.historyCount > 0
                iconPath: Icons.history
                text: qsTr("History")
                label: qsTr("Notification history (last 24 hours)")
                onClicked: { historySearch.text = ""; pn.store.loadHistory(""); historySheet.open() }
            }
            Button {
                id: clearAll
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: pn.store.count > 0
                variant: "tonal"
                size: "sm"
                iconPath: Icons.close
                text: qsTr("Clear all")
                onClicked: pn.store.post("clear")
            }
        }

        // Calm inline Undo bar after dismissing a notification or app group.
        Rectangle {
            id: undoBanner
            width: parent.width
            height: undoRow.height + 16
            visible: pn.store.undoLabel.length > 0
            radius: Theme.radiusMd
            color: Theme.graphite ? "transparent" : Theme.surfaceContainerHigh
            border.width: Theme.graphite ? 1 : 0
            border.color: Theme.outlineVariant
            Timer {
                id: undoTimer
                interval: 6000
                running: pn.store.undoLabel.length > 0
                onTriggered: pn.store.post("undo/clear")
            }
            Connections {
                target: pn.store
                function onUndoLabelChanged() { if (pn.store.undoLabel.length > 0) undoTimer.restart() }
            }
            Row {
                id: undoRow
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24
                spacing: 8
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(60, parent.width - undoBtn.width - closeUndoBtn.width - 16)
                    role: "bodySmall"
                    elide: Text.ElideRight
                    text: pn.store.undoLabel
                }
                Button {
                    id: undoBtn
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    size: "sm"
                    text: qsTr("Undo")
                    onClicked: pn.store.post("undo")
                }
                IconButton {
                    id: closeUndoBtn
                    anchors.verticalCenter: parent.verticalCenter
                    iconPath: Icons.close
                    label: qsTr("Dismiss")
                    onClicked: pn.store.post("undo/clear")
                }
            }
        }

        ListView {
            id: feedView
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 4
            model: pn.store.feed
            boundsBehavior: Flickable.StopAtBounds
            delegate: NotificationItem {
                width: feedView.width
                list: pn.store
                clock: pn.store.clock
                canOpenApp: pn.store.canOpenApp && app.length > 0
                onOpenAppRequested: pn.store.openApp(app, appName.length > 0 ? appName : app)
                onOptionsRequested: appSheet.openFor(app, appName)
                onImageClicked: (url) => imagePreviewSheet.openFor(url, title.length > 0 ? title : appName)
            }
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic } }
            Txt {  // empty: say why
                width: parent.width
                visible: pn.store.count === 0
                role: "bodySmall"
                muted: true
                wrapMode: Text.WordWrap
                text: !pn.store.connected ? qsTr("NectarLink is not running")
                    : !pn.store.phoneOnline ? qsTr("Connect %1 to view notifications").arg(pn.store.phoneName.length > 0 ? pn.store.phoneName : qsTr("your phone"))
                    : qsTr("No notifications")
            }
            Button {
                visible: !pn.store.connected
                y: 32
                variant: "tonal"
                size: "sm"
                text: qsTr("Start NectarLink")
                onClicked: pn.store.startNectarLink()
            }
        }
    }

    // What one app's notifications do on this PC.
    Sheet {
        id: appSheet
        property string app
        property string appName
        property string rule: "show"
        cardWidth: 420
        function openFor(app, name) {
            appSheet.app = app
            appSheet.appName = name
            appSheet.rule = pn.store.ruleOf(app)
            open()
        }
        Column {
            width: parent.width
            spacing: 16
            Txt { width: parent.width; text: qsTr("%1 notifications").arg(appSheet.appName); role: "headline"; wrapMode: Text.WordWrap }
            Segmented {
                options: [
                    { value: "show", label: qsTr("Show") },
                    { value: "quiet", label: qsTr("No pop-ups") },
                    { value: "hidden", label: qsTr("Hide") }
                ]
                value: appSheet.rule
                onPicked: (value) => {
                    appSheet.rule = value
                    pn.store.setRule(appSheet.app, value)
                }
            }
            Txt {
                width: parent.width
                wrapMode: Text.WordWrap
                role: "body"
                muted: true
                text: appSheet.rule === "hidden"
                      ? qsTr("Hidden on this PC.")
                      : appSheet.rule === "quiet"
                        ? qsTr("Shown in feed without pop-ups.")
                        : qsTr("Shown in feed and as desktop pop-ups.")
            }
            Row {
                anchors.right: parent.right
                Button { text: qsTr("Done"); onClicked: appSheet.close() }
            }
        }
    }

    // Every app's rule (Settings > Notifications in NectarLink).
    Sheet {
        id: rulesSheet
        cardWidth: 420
        Column {
            width: parent.width
            spacing: 12
            Txt { width: parent.width; text: qsTr("Notifications"); role: "headline" }
            Txt {
                width: parent.width
                wrapMode: Text.WordWrap
                role: "bodySmall"
                muted: true
                text: qsTr("What each app's notifications do on this PC.")
            }
            Flickable {
                width: parent.width
                height: Math.min(rulesColumn.height, pn.height - 310)
                contentHeight: rulesColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: rulesColumn
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: rulesSheet.opened ? pn.store.rulesApps : []
                        delegate: Item {
                            id: ruleRow
                            required property var modelData
                            width: rulesColumn.width
                            height: 44
                            Avatar {
                                id: ruleIcon
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28; height: 28
                                name: ruleRow.modelData.name
                                visible: ruleImg.status !== Image.Ready
                            }
                            Image {
                                id: ruleImg
                                anchors.fill: ruleIcon
                                source: ruleRow.modelData.icon
                                sourceSize: Qt.size(56, 56)
                                smooth: true
                                visible: status === Image.Ready
                            }
                            Txt {
                                anchors.left: ruleIcon.right
                                anchors.leftMargin: 10
                                anchors.right: ruleSeg.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: ruleRow.modelData.name
                                role: "body"
                            }
                            Segmented {
                                id: ruleSeg
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                options: [
                                    { value: "show", label: qsTr("Show") },
                                    { value: "quiet", label: qsTr("Quiet") },
                                    { value: "hidden", label: qsTr("Hide") }
                                ]
                                value: ruleRow.modelData.rule
                                onPicked: (value) => pn.store.setRule(ruleRow.modelData.app, value)
                            }
                        }
                    }
                }
            }
            Row {
                anchors.right: parent.right
                Button { text: qsTr("Done"); onClicked: rulesSheet.close() }
            }
        }
    }

    // Notifications from the last day that are gone from the phone.
    Sheet {
        id: historySheet
        cardWidth: 560
        Column {
            width: parent.width
            spacing: 12
            Item {
                width: parent.width
                height: Math.max(historyTitle.height, clearHistory.height)
                Txt { id: historyTitle; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Notification history"); role: "headline" }
                Button {
                    id: clearHistory
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pn.store.history.count > 0
                    variant: "text"
                    size: "sm"
                    text: qsTr("Clear history")
                    onClicked: pn.store.post("history/clear")
                }
            }
            Txt {
                width: parent.width
                wrapMode: Text.WordWrap
                role: "bodySmall"
                muted: true
                text: pn.store.historyTotal > 0
                      ? qsTr("Dismissed notifications from the last 24 hours.")
                      : qsTr("No recent notifications.")
            }
            // Search: by app, title or text, ignoring case.
            Rectangle {
                width: parent.width
                height: 40
                visible: pn.store.historyTotal > 0
                radius: Theme.graphite ? Theme.radiusSm : height / 2
                color: Theme.graphite ? "transparent" : Theme.surfaceContainerHighest
                border.width: historySearch.activeFocus ? 2 : 1
                border.color: historySearch.activeFocus ? Theme.primary : Theme.outlineVariant
                Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    path: Icons.search
                    color: Theme.surfaceContentVariant
                }
                TextInput {
                    id: historySearch
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    color: Theme.surfaceContent
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primaryContainerContent
                    clip: true
                    onTextChanged: historyDebounce.restart()
                    Keys.onEscapePressed: (event) => {
                        // Clears first; a second Escape closes the sheet.
                        event.accepted = text.length > 0
                        text = ""
                    }
                    Accessible.name: qsTr("Search notification history")
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: historySearch.text.length === 0
                        role: "body"
                        muted: true
                        text: qsTr("Search notification history")
                    }
                }
                Timer { id: historyDebounce; interval: 200; onTriggered: pn.store.loadHistory(historySearch.text.trim()) }
            }
            Flickable {
                width: parent.width
                height: Math.min(historyColumn.height, pn.height - 310)
                contentHeight: historyColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: historyColumn
                    width: parent.width
                    Repeater {
                        model: historySheet.opened ? pn.store.history : null
                        delegate: HistoryItem {
                            required property string deviceId
                            required property string app
                            width: historyColumn.width
                            canOpenApp: pn.store.canOpenApp && app.length > 0
                            onOpenAppRequested: {
                                historySheet.close()
                                pn.store.openApp(app, appName.length > 0 ? appName : app)
                            }
                        }
                    }
                }
            }
            Txt {
                width: parent.width
                visible: historySearch.text.trim().length > 0 && historyColumn.height === 0
                horizontalAlignment: Text.AlignHCenter
                role: "body"
                muted: true
                text: qsTr("Nothing matches “%1”.").arg(historySearch.text.trim())
            }
            Row {
                anchors.right: parent.right
                Button { text: qsTr("Done"); onClicked: historySheet.close() }
            }
        }
    }

    // Inline lightbox preview for notification images.
    Sheet {
        id: imagePreviewSheet
        property string imageUrl: ""
        property string caption: ""
        cardWidth: 680
        function openFor(url, title) {
            imageUrl = url || ""
            caption = title || ""
            if (imageUrl.length > 0)
                open()
        }
        Column {
            width: parent.width
            spacing: 14
            Item {
                width: parent.width
                height: Math.max(previewHeaderTxt.height, closePreviewBtn.height)
                Txt {
                    id: previewHeaderTxt
                    anchors.left: parent.left
                    anchors.right: closePreviewBtn.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    role: "headline"
                    elide: Text.ElideRight
                    text: imagePreviewSheet.caption.length > 0 ? imagePreviewSheet.caption : qsTr("Image preview")
                }
                IconButton {
                    id: closePreviewBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    iconPath: Icons.close
                    label: qsTr("Close")
                    onClicked: imagePreviewSheet.close()
                }
            }
            Rectangle {
                width: parent.width
                height: Math.min(480, Math.max(200, previewImg.status === Image.Ready
                    ? width * previewImg.implicitHeight / Math.max(1, previewImg.implicitWidth)
                    : 320))
                radius: Theme.radiusMd
                color: Theme.surfaceContainerHighest
                clip: true
                Image {
                    id: previewImg
                    anchors.fill: parent
                    anchors.margins: 8
                    source: imagePreviewSheet.imageUrl
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Button {
                    variant: "tonal"
                    iconPath: Icons.photo
                    text: qsTr("Open externally")
                    onClicked: Qt.openUrlExternally(imagePreviewSheet.imageUrl)
                }
                Button { text: qsTr("Done"); onClicked: imagePreviewSheet.close() }
            }
        }
    }

    // Esc closes the open sheet first; with none open it falls through to WidgetBase (closes the panel).
    Keys.onEscapePressed: (event) => {
        if (historySheet.opened) historySheet.close()
        else if (appSheet.opened) appSheet.close()
        else if (rulesSheet.opened) rulesSheet.close()
        else if (imagePreviewSheet.opened) imagePreviewSheet.close()
        else event.accepted = false
    }
}
