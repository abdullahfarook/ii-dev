import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import "nectar"

// The panel content in the shell's own style (header with icon and subtitle, icon buttons, search, chips, footer hint; History
// and App rules are views of the panel with a back button). The notification cards are NectarLink's own NotificationItem /
// HistoryItem (nectar/), unchanged, each in the app's card color. `store` is the PhoneNotifStore.
FocusScope {
    id: pn
    required property var store
    property string mode: "list"           // list | history | rules
    property string appFilter: ""           // "" = all apps, else a package name
    property string rulesApp: ""            // rules view opened from a card's "...": only that app
    property string rulesAppName: ""
    property string lightbox: ""
    // handles for the test harness (cage)
    property alias feedList: feedView
    property alias historyList: histView
    property alias historySearchInput: histField.input

    readonly property bool filtering: appFilter !== ""
    function matches(app) { return appFilter === "" || app === appFilter }
    function openRules(app, name) { rulesApp = app || ""; rulesAppName = name || ""; store.loadRules(); mode = "rules" }
    function back() { if (lightbox !== "") lightbox = ""; else mode = "list" }
    onModeChanged: { if (mode === "history") store.loadHistory(""); else if (mode === "rules") store.loadRules() }
    Component.onCompleted: {
        if (store.pendingSheet === "rules") { store.pendingSheet = ""; openRules("", "") }
        keyScope.forceActiveFocus()
    }

    FontLoader { source: "nectar/fonts/Figtree.ttf" }

    component IconBtn: RippleButton {
        id: ib
        property string symbol
        property string tip
        implicitWidth: 30; implicitHeight: 30
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2Hover
        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            text: ib.symbol
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer2
            opacity: ib.enabled ? 1 : 0.4
        }
        StyledToolTip { text: ib.tip; visible: ib.hovered && ib.tip !== "" }
    }
    component Chip: RippleButton {
        id: chip
        property string label
        property bool active: false
        implicitHeight: 26
        implicitWidth: chipText.implicitWidth + 20
        buttonRadius: Appearance.rounding.full
        colBackground: active ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
        colBackgroundHover: active ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
        contentItem: StyledText {
            id: chipText
            horizontalAlignment: Text.AlignHCenter
            text: chip.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: chip.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
        }
    }
    component Field: Rectangle {
        id: fld
        property alias input: fieldInput
        property string placeholder
        signal edited(string text)
        Layout.fillWidth: true
        implicitHeight: 38
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: fieldInput.activeFocus ? 1 : 0
        border.color: Appearance.colors.colPrimary
        MaterialSymbol { id: fieldIcon; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: "search"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colSubtext }
        StyledTextInput {
            id: fieldInput
            anchors { left: fieldIcon.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 8; rightMargin: 12 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            onTextChanged: fld.edited(text)
            StyledText { visible: fieldInput.text === ""; anchors.verticalCenter: parent.verticalCenter; text: fld.placeholder; color: Appearance.colors.colSubtext }
        }
    }
    FocusScope {
        id: keyScope
        anchors.fill: parent
        // Esc: the picture, then a view back to the list, then the search, then (falls through to WidgetBase) the panel
        Keys.onEscapePressed: event => {
            if (pn.lightbox !== "") pn.lightbox = ""
            else if (pn.mode !== "list") pn.mode = "list"
            else if (pn.appFilter !== "") pn.appFilter = ""
            else event.accepted = false
        }

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                IconBtn { visible: pn.mode !== "list"; symbol: "arrow_back"; tip: qsTr("Back (Esc)"); onClicked: pn.mode = "list" }
                Item {  // a tall, narrow phone with the battery ring and percentage in the middle; as tall as the two rows of text
                    id: phoneGlyph
                    visible: pn.mode === "list"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 58
                    readonly property int b: pn.store.battery
                    Rectangle {  // the body
                        anchors.fill: parent
                        radius: 8
                        color: "transparent"
                        border.width: 1.5
                        border.color: Appearance.colors.colOnSecondaryContainer
                        opacity: pn.store.phoneOnline ? 1 : 0.5
                        Rectangle { anchors { bottom: parent.bottom; bottomMargin: 3; horizontalCenter: parent.horizontalCenter } width: 10; height: 2; radius: 1; color: Appearance.colors.colOnSecondaryContainer; opacity: 0.8 }
                    }
                    CircularProgress {  // the battery level as a ring around the percentage
                        visible: phoneGlyph.b >= 0
                        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                        implicitSize: 24
                        lineWidth: 2
                        value: Math.max(0, Math.min(100, phoneGlyph.b)) / 100
                        colPrimary: pn.store.charging ? "#43a047" : phoneGlyph.b < 20 ? "#ef5350" : Appearance.colors.colOnSecondaryContainer
                        colSecondary: Qt.rgba(1, 1, 1, 0.12)
                        enableAnimation: false
                        StyledText {
                            id: pctText
                            anchors.centerIn: parent
                            text: phoneGlyph.b
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                    MaterialSymbol { visible: phoneGlyph.b < 0; anchors.centerIn: parent; text: "smartphone"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                    StyledToolTip { text: phoneGlyph.b >= 0 ? (pn.store.charging ? qsTr("Battery %1%, charging").arg(phoneGlyph.b) : qsTr("Battery %1%").arg(phoneGlyph.b)) : qsTr("Phone"); visible: glyphHover.hovered }
                    HoverHandler { id: glyphHover }
                }
                ColumnLayout {
                    id: headerText
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3
                    StyledText {
                        Layout.fillWidth: true
                        text: pn.mode === "history" ? qsTr("Notification history")
                            : pn.mode === "rules" ? (pn.rulesApp !== "" ? qsTr("%1 notifications").arg(pn.rulesAppName) : qsTr("App rules"))
                            : pn.store.phoneName !== "" ? pn.store.phoneName : qsTr("Phone notifications")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        visible: pn.mode !== "list"
                        Layout.fillWidth: true
                        text: pn.mode === "history" ? (pn.store.historyTotal > 0 ? qsTr("Dismissed in the last 24 hours") : qsTr("No recent notifications"))
                            : pn.mode === "rules" ? qsTr("What each app's notifications do on this PC")
                            : ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                    }
                    RowLayout {  // under the name: status only (connection and link), small and quiet like a subtitle
                        visible: pn.mode === "list"
                        Layout.fillWidth: true
                        spacing: 4
                        MaterialSymbol {
                            visible: pn.store.connected
                            text: pn.store.phoneOnline ? "check_circle" : "link_off"
                            fill: 1
                            iconSize: Appearance.font.pixelSize.normal
                            color: pn.store.phoneOnline ? "#43a047" : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: !pn.store.connected ? qsTr("NectarLink is not running") : pn.store.phoneOnline ? qsTr("Connected") : qsTr("Offline")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        StyledText { visible: linkIcon.visible; text: "·"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        MaterialSymbol {
                            id: linkIcon
                            visible: pn.store.phoneOnline && pn.store.link !== ""
                            text: pn.store.link === "usb" ? "usb" : pn.store.link === "relay" ? "cloud" : "wifi"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            visible: linkIcon.visible
                            Layout.fillWidth: true
                            text: pn.store.link === "usb" ? qsTr("USB") : pn.store.link === "relay" ? qsTr("Relay") : qsTr("Wi-Fi")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                        Item { visible: !linkIcon.visible; Layout.fillWidth: true }
                    }
                }
                IconBtn { id: clearHistBtn; visible: pn.mode === "history" && pn.store.historyTotal > 0; symbol: "delete"; tip: qsTr("Clear history"); onClicked: pn.store.post("history/clear") }
            }

            // ---- list: search, app chips, the feed ----
            // ---- toolbar: what to do with the phone (left), the panel's own views (right) ----
            RowLayout {
                visible: pn.mode === "list" && pn.store.connected
                Layout.fillWidth: true
                spacing: 2
                IconBtn { symbol: "screen_share"; tip: qsTr("Mirror screen"); enabled: pn.store.phoneOnline; onClicked: pn.store.quick("mirror") }
                IconBtn { symbol: "send"; tip: qsTr("Send files"); enabled: pn.store.phoneOnline; onClicked: pn.store.quick("send-files") }
                IconBtn { symbol: "content_paste_go"; tip: qsTr("Send clipboard"); enabled: pn.store.phoneOnline; onClicked: pn.store.quick("send-clipboard") }
                IconBtn { symbol: "notifications_active"; tip: qsTr("Find phone"); enabled: pn.store.phoneOnline; onClicked: pn.store.quick("ring") }
                Item { Layout.fillWidth: true }
                IconBtn { visible: pn.store.historyEnabled && pn.store.historyCount > 0; symbol: "history"; tip: qsTr("Notification history (last 24 hours)"); onClicked: pn.mode = "history" }
                IconBtn { symbol: "tune"; tip: qsTr("App rules"); onClicked: pn.openRules("", "") }
                IconBtn { symbol: "open_in_new"; tip: qsTr("Open NectarLink"); onClicked: Quickshell.execDetached([pn.store.helper, "open"]) }
            }
            Rectangle { visible: pn.mode === "list" && pn.store.connected; Layout.fillWidth: true; implicitHeight: 1; color: Appearance.colors.colOutlineVariant }
            RowLayout {
                visible: pn.mode === "list" && pn.store.connected && pn.store.count > 0
                Layout.fillWidth: true
                spacing: 4
            Flow {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                Chip { label: qsTr("All") + " · " + pn.store.count; active: pn.appFilter === ""; onClicked: pn.appFilter = "" }
                Repeater {
                    model: pn.store.appList
                    delegate: Chip {
                        required property var modelData
                        label: modelData.name + " · " + modelData.count
                        active: pn.appFilter === modelData.app
                        onClicked: pn.appFilter = pn.appFilter === modelData.app ? "" : modelData.app
                    }
                }
            }
                IconBtn { id: clearAllBtn; Layout.alignment: Qt.AlignTop; symbol: "clear_all"; tip: qsTr("Clear all"); onClicked: pn.store.post("clear") }
            }
            // Undo after a dismiss or Clear all
            Rectangle {
                id: undoBar
                visible: pn.mode === "list" && pn.store.undoLabel.length > 0
                Layout.fillWidth: true
                implicitHeight: 38; radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                Timer { id: undoTimer; interval: 6000; running: undoBar.visible; onTriggered: pn.store.post("undo/clear") }
                Connections { target: pn.store; function onUndoLabelChanged() { if (pn.store.undoLabel.length > 0) undoTimer.restart() } }
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
                    StyledText { Layout.fillWidth: true; text: pn.store.undoLabel; elide: Text.ElideRight; color: Appearance.colors.colOnSecondaryContainer }
                    Chip { id: undoBtn; label: qsTr("Undo"); active: true; onClicked: pn.store.post("undo") }
                    IconBtn { symbol: "close"; tip: qsTr("Dismiss"); onClicked: pn.store.post("undo/clear") }
                }
            }
            StyledListView {
                id: feedView
                visible: pn.mode === "list"
                animateAppearance: false
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0
                model: pn.store.feed
                boundsBehavior: Flickable.StopAtBounds
                // the app's own NotificationItem is the delegate (its roles are filled from the model), on the panel's own background
                delegate: NotificationItem {
                    id: ni
                    readonly property bool shown: pn.matches(app)
                    width: feedView.width
                    visible: shown
                    height: shown ? implicitHeight + 4 : 0
                    list: pn.store
                    clock: pn.store.clock
                    canOpenApp: pn.store.canOpenApp && app.length > 0
                    onOpenAppRequested: pn.store.openApp(app, appName.length > 0 ? appName : app)
                    onOptionsRequested: pn.openRules(app, appName)
                    onImageClicked: url => pn.lightbox = url
                }
            }
            // empty states
            Item {
                visible: pn.mode === "list" && (feedView.count === 0 || (pn.filtering && feedView.contentHeight < 1))
                Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: !pn.store.connected ? "phonelink_off" : "notifications_off"; iconSize: 44; color: Appearance.colors.colSubtext }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: !pn.store.connected ? qsTr("NectarLink is not running")
                            : !pn.store.phoneOnline ? qsTr("Connect your phone to see notifications")
                            : pn.filtering && feedView.count > 0 ? qsTr("Nothing matches")
                            : qsTr("No notifications")
                        color: Appearance.colors.colSubtext
                    }
                    Chip { visible: !pn.store.connected; Layout.alignment: Qt.AlignHCenter; label: qsTr("Start NectarLink"); active: true; onClicked: pn.store.startNectarLink() }
                }
            }

            // ---- history ----
            Field {
                id: histField
                visible: pn.mode === "history" && pn.store.historyTotal > 0
                placeholder: qsTr("Search notification history")
                onEdited: text => histDebounce.restart()
                Timer { id: histDebounce; interval: 200; onTriggered: pn.store.loadHistory(histField.input.text.trim()) }
            }
            StyledListView {
                id: histView
                visible: pn.mode === "history"
                animateAppearance: false
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 0
                model: pn.store.history
                boundsBehavior: Flickable.StopAtBounds
                delegate: HistoryItem {
                    id: hi
                    required property string deviceId
                    required property string app
                    width: histView.width
                    height: implicitHeight + 4
                    canOpenApp: pn.store.canOpenApp && app.length > 0
                    onOpenAppRequested: pn.store.openApp(app, appName.length > 0 ? appName : app)
                }
            }

            // ---- app rules ----
            StyledListView {
                id: rulesView
                visible: pn.mode === "rules"
                animateAppearance: false
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: pn.rulesApp !== "" ? pn.store.rulesApps.filter(a => a.app === pn.rulesApp) : pn.store.rulesApps
                delegate: Rectangle {
                    id: ruleRow
                    required property var modelData
                    width: rulesView.width
                    implicitHeight: 48
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                        spacing: 8
                        Item {
                            implicitWidth: 28; implicitHeight: 28
                            Image { id: ric; anchors.fill: parent; source: ruleRow.modelData.icon; sourceSize: Qt.size(56, 56); asynchronous: true; visible: status === Image.Ready }
                            Avatar { anchors.fill: parent; name: ruleRow.modelData.name; visible: ric.status !== Image.Ready }
                        }
                        StyledText { Layout.fillWidth: true; text: ruleRow.modelData.name; elide: Text.ElideRight; color: Appearance.colors.colOnLayer2 }
                        Repeater {
                            model: [{ "k": "show", "t": qsTr("Show") }, { "k": "quiet", "t": qsTr("No pop-ups") }, { "k": "hidden", "t": qsTr("Hide") }]
                            delegate: Chip {
                                required property var modelData
                                label: modelData.t
                                active: ruleRow.modelData.rule === modelData.k
                                onClicked: pn.store.setRule(ruleRow.modelData.app, modelData.k)
                            }
                        }
                    }
                }
            }

            // ---- footer hint ----
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: pn.mode === "list" ? qsTr("Reply, act and dismiss right here · Esc closes")
                    : pn.mode === "history" ? qsTr("Esc goes back")
                    : qsTr("Esc goes back")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }

        // ---- picture preview (click or Esc closes) ----
        Rectangle {
            visible: pn.lightbox !== ""
            anchors.fill: parent
            color: "#cc000000"
            radius: Appearance.rounding.normal
            MouseArea { anchors.fill: parent; onClicked: pn.lightbox = "" }
            Image { anchors { fill: parent; margins: 16 } source: pn.lightbox; fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true; mipmap: true }
        }
    }
}
