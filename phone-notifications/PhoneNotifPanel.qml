import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

// The panel content: header (History, Rules, Clear all), phone status, Undo bar, the feed of PhoneNotifCard, history with
// search, per-app rules and the picture preview. `store` is the PhoneNotifStore.
FocusScope {
    id: pn
    required property var store
    signal closeRequested()
    property alias feedList: feedList       // handle for the test harness
    property alias historyList: histList
    property alias historyButton: historyBtn
    property alias rulesButton: rulesBtn
    property alias clearAllButton: clearAllBtn
    property alias clearHistoryButton: clearHistoryBtn
    property alias undoButton: undoBtn

    property string view: "feed"        // feed | history | rules
    property string rulesApp: ""        // set when the rules view was opened from a card's "…"
    property string rulesAppName: ""
    property string lightbox: ""
    // Esc closes the picture, then a sub-view, then (falls through to WidgetBase) the panel
    Keys.onEscapePressed: event => {
        if (pn.lightbox !== "") pn.lightbox = "";
        else if (pn.view !== "feed") pn.view = "feed";
        else event.accepted = false;
    }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: store.clock++ }
    Timer { id: undoTimer; interval: 8000; running: store.undoLabel.length > 0; onTriggered: store.post("undo/clear") }
    onViewChanged: { if (view === "history") store.loadHistory(""); else if (view === "rules") store.loadRules(); }
    Connections {  // history stays current while it is shown
        target: store
        function onRevChanged() { if (pn.view === "history") store.loadHistory(store.historyQuery); }
    }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 8

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            RippleButton {
                visible: pn.view !== "feed"
                implicitWidth: 32; implicitHeight: 32; buttonRadius: 16
                onClicked: pn.view = "feed"
                MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: 20; color: Appearance.colors.colOnLayer1 }
                StyledToolTip { text: "Back" }
            }
            StyledText {
                Layout.fillWidth: true
                text: pn.view === "history" ? "Notification history"
                    : pn.view === "rules" ? (pn.rulesApp !== "" ? pn.rulesAppName + " notifications" : "App rules")
                    : store.count > 0 ? "Notifications · " + store.count : "Notifications"
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer1
            }
            component HeadBtn: RippleButton {
                property string sym
                property string label
                implicitHeight: 32
                implicitWidth: headRow.implicitWidth + 20
                buttonRadius: 16
                colBackground: Appearance.colors.colSecondaryContainer
                RowLayout {
                    id: headRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol { text: parent.parent.sym; iconSize: 18; color: Appearance.colors.colOnSecondaryContainer }
                    StyledText { text: parent.parent.label; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnSecondaryContainer }
                }
            }
            HeadBtn { id: historyBtn; visible: pn.view === "feed" && store.connected && store.historyEnabled; sym: "history"; label: "History"; onClicked: pn.view = "history" }
            HeadBtn { id: rulesBtn; visible: pn.view === "feed" && store.connected; sym: "tune"; label: "Rules"; onClicked: { pn.rulesApp = ""; pn.view = "rules" } }
            HeadBtn { id: clearAllBtn; visible: pn.view === "feed" && store.count > 0; sym: "close"; label: "Clear all"; onClicked: store.post("clear") }
            HeadBtn { id: clearHistoryBtn; visible: pn.view === "history" && store.historyTotal > 0; sym: "delete"; label: "Clear history"; onClicked: store.post("history/clear") }
        }

        // phone status line
        StyledText {
            visible: pn.view === "feed" && store.connected && store.phoneName !== ""
            Layout.fillWidth: true
            text: store.phoneName + (store.phoneOnline ? "" : " · offline")
                + (store.battery >= 0 ? " · " + store.battery + "%" + (store.charging ? " charging" : "") : "")
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        // Undo bar after a dismiss / clear
        Rectangle {
            visible: pn.view === "feed" && store.undoLabel.length > 0
            Layout.fillWidth: true
            implicitHeight: 40; radius: Appearance.rounding.small
            color: Appearance.colors.colSecondaryContainer
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
                StyledText { Layout.fillWidth: true; text: store.undoLabel; elide: Text.ElideRight; color: Appearance.colors.colOnSecondaryContainer }
                RippleButton {
                    implicitHeight: 30; implicitWidth: undoText.implicitWidth + 20; buttonRadius: 15
                    colBackground: "transparent"
                    id: undoBtn
                    onClicked: store.post("undo")
                    StyledText { id: undoText; anchors.centerIn: parent; text: "Undo"; color: Appearance.colors.colPrimary; font.weight: Font.Medium }
                }
                RippleButton {
                    implicitWidth: 30; implicitHeight: 30; buttonRadius: 15
                    colBackground: "transparent"
                    onClicked: store.post("undo/clear")
                    MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 18; color: Appearance.colors.colOnSecondaryContainer }
                }
            }
        }

        // ---- feed ----
        Item {
            visible: pn.view === "feed"
            Layout.fillWidth: true; Layout.fillHeight: true
            ListView {
                id: feedList
                anchors.fill: parent
                clip: true
                spacing: 4
                model: store.feed
                boundsBehavior: Flickable.StopAtBounds
                delegate: PhoneNotifCard {
                    width: feedList.width
                    store: pn.store
                    onImageClicked: url => pn.lightbox = url
                    onOptionsRequested: (app, name) => { pn.rulesApp = app; pn.rulesAppName = name; pn.view = "rules" }
                }
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
                remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
                displaced: Transition { NumberAnimation { properties: "y"; duration: 150 } }
            }
            ColumnLayout {  // empty / unavailable states
                visible: feedList.count === 0
                anchors.centerIn: parent
                spacing: 10
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: store.connected ? "notifications_off" : "phonelink_off"
                    iconSize: 44; color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: !store.connected ? "NectarLink is not running"
                        : !store.phoneOnline ? "Connect your phone to see notifications"
                        : "No notifications"
                    color: Appearance.colors.colSubtext
                }
                RippleButton {
                    visible: !store.connected
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 32; implicitWidth: startText.implicitWidth + 28; buttonRadius: 16
                    colBackground: Appearance.colors.colPrimary
                    onClicked: store.startNectarLink()
                    StyledText { id: startText; anchors.centerIn: parent; text: "Start NectarLink"; color: Appearance.colors.colOnPrimary }
                }
            }
        }

        // ---- history ----
        ColumnLayout {
            visible: pn.view === "history"
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: store.historyTotal > 0 ? "Dismissed notifications from the last 24 hours." : "No recent notifications."
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            Rectangle {
                visible: store.historyTotal > 0
                Layout.fillWidth: true
                implicitHeight: 36; radius: 18
                color: Appearance.colors.colLayer1
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8
                    MaterialSymbol { text: "search"; iconSize: 18; color: Appearance.colors.colSubtext }
                    StyledTextInput {
                        id: histSearch
                        Layout.fillWidth: true
                        clip: true
                        onTextChanged: histDebounce.restart()
                        Keys.onEscapePressed: event => { if (text !== "") { text = ""; event.accepted = true } else event.accepted = false }
                        StyledText { visible: histSearch.text.length === 0; text: "Search notification history"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }
                Timer { id: histDebounce; interval: 200; onTriggered: store.loadHistory(histSearch.text) }
            }
            ListView {
                id: histList
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                spacing: 4
                model: store.history
                boundsBehavior: Flickable.StopAtBounds
                delegate: PhoneNotifHistoryRow {
                    width: histList.width
                    store: pn.store
                }
            }
        }

        // ---- app rules ----
        ColumnLayout {
            visible: pn.view === "rules"
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Show: in the feed. Quiet: in the feed without pop-ups. Hidden: not shown at all."
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            ListView {
                id: rulesList
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: pn.rulesApp !== "" ? store.rulesApps.filter(a => a.app === pn.rulesApp) : store.rulesApps
                delegate: PhoneNotifRuleRow { width: rulesList.width; store: pn.store }
            }
        }
    }

    // ---- picture preview ----
    Rectangle {
        visible: pn.lightbox !== ""
        anchors.fill: parent
        color: "#cc000000"
        radius: Appearance.rounding.normal
        MouseArea { anchors.fill: parent; onClicked: pn.lightbox = "" }
        Image {
            anchors { fill: parent; margins: 16 }
            source: pn.lightbox
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }
}
