import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

// One phone notification, like the card in NectarLink's Notifications section: app icon, app · sub · time, title, text,
// picture, Live Update progress, replies you sent, buttons (Copy code, Reply, the app's own actions), an inline reply box,
// dismiss, options and the group bar (+N more / Clear N).
Item {
    id: card
    required property var store
    // model roles (see PhoneNotifButton.qml: complex fields are JSON strings)
    required property string uid
    required property string deviceId
    required property string key
    required property string app
    required property string appName
    required property string title
    required property string text
    required property string sub
    required property real when
    required property string iconUrl
    required property string imageUrl
    required property string actions
    required property string replyAction
    required property string replyLabel
    required property bool ongoing
    required property string replies
    required property string otpCode
    required property string live
    required property int groupCount
    required property int groupIndex
    required property bool groupExpanded
    required property string groupSummary
    // handles for the test harness (cage): the buttons a person would click
    property alias replyInput: input
    property alias dismissButton: dismissBtn
    property alias optionsButton: optionsBtn
    property alias replyButton: replyBtn
    property alias actionButtons: actionRepeater
    property alias moreButton: moreBtn
    property alias clearGroupButton: clearGroupBtn
    property alias copyCodeButton: copyBtn
    signal imageClicked(string url)
    signal optionsRequested(string app, string appName)

    readonly property bool isGrouped: groupCount > 1
    readonly property bool isGroupLead: isGrouped && groupIndex === 0
    readonly property bool isGroupChild: isGrouped && groupIndex > 0
    readonly property var buttons: { try { return JSON.parse(actions) } catch (e) { return [] } }
    readonly property var sent: { try { return JSON.parse(replies) } catch (e) { return [] } }
    readonly property var liveData: { try { return live.length > 0 ? JSON.parse(live) : null } catch (e) { return null } }
    readonly property bool isLive: liveData !== null
    readonly property bool hasProgress: isLive && (Boolean(liveData.indeterminate) || Number(liveData.max) > 0)
    property bool replying: false
    property int chronoTick: 0
    readonly property color subtle: Appearance.colors.colSubtext

    implicitHeight: body.implicitHeight + 16
    implicitWidth: 400

    readonly property string timeText: {
        store.clock;  // re-evaluated every minute
        const minutes = Math.round((Date.now() - when) / 60000);
        if (minutes < 1) return "now";
        if (minutes < 60) return minutes + " min";
        const d = new Date(when);
        if (Date.now() - when < 24 * 3600 * 1000) return Qt.formatTime(d, "HH:mm");
        return Qt.formatDate(d, "d MMM");
    }
    readonly property string badgeText: {
        if (!isLive) return "";
        const c = (liveData.chip || "").trim();
        return c.length > 0 ? c : "LIVE";
    }
    readonly property string liveRight: {
        if (!isLive) return "";
        if (liveData.chronometer) return chronoText();
        if (!liveData.indeterminate && Number(liveData.max) > 0)
            return Math.min(100, Math.max(0, Math.round(Number(liveData.progress) * 100 / Number(liveData.max)))) + "%";
        return "";
    }
    function chronoText() {
        chronoTick;
        const target = Number(liveData.when || when);
        const diff = liveData.countdown ? Math.max(0, target - Date.now()) : Math.max(0, Date.now() - target);
        const secs = Math.floor(diff / 1000), h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60), s = secs % 60;
        const pad = n => n < 10 ? "0" + n : String(n);
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
    }
    Timer {
        interval: 1000; repeat: true
        running: card.isLive && Boolean(card.liveData.chronometer) && card.visible
        onTriggered: card.chronoTick++
    }
    function send() {
        const t = input.text.trim();
        if (t.length === 0) return;
        store.post("action", { "device": deviceId, "key": key, "action": replyAction, "reply": t });
        input.text = "";
        replying = false;
    }

    HoverHandler { id: hover }

    Rectangle {  // card background
        anchors { fill: parent; leftMargin: card.isGroupChild ? 22 : 0; topMargin: 2; bottomMargin: 2 }
        radius: Appearance.rounding.small
        color: hover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        border.width: card.replying ? 1 : 0
        border.color: Appearance.colors.colPrimary
    }

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: (card.isGroupChild ? 22 : 0) + 10; topMargin: 12 }
        spacing: 4

        RowLayout {  // icon · app line · options · dismiss
            Layout.fillWidth: true
            spacing: 10
            Item {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 32; implicitHeight: 32
                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: card.iconUrl
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    visible: appIcon.status !== Image.Ready
                    radius: 16
                    color: Qt.hsla(((card.appName.charCodeAt(0) || 0) * 37 % 360) / 360, 0.45, 0.62, 1)
                    StyledText {
                        anchors.centerIn: parent
                        text: (card.appName.charAt(0) || "?").toUpperCase()
                        color: "#1b1b1f"
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: [card.appName, card.sub, card.timeText].filter(s => s.length > 0).join(" · ")
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: card.subtle
                    }
                    Rectangle {  // Live Update badge
                        visible: card.isLive
                        implicitWidth: liveBadge.implicitWidth + 12; implicitHeight: 16; radius: 8
                        color: Appearance.colors.colPrimary
                        StyledText { id: liveBadge; anchors.centerIn: parent; text: card.badgeText; font.pixelSize: 9; color: Appearance.colors.colOnPrimary }
                    }
                    Rectangle {  // group count
                        visible: card.isGroupLead
                        implicitWidth: Math.max(16, groupText.implicitWidth + 8); implicitHeight: 16; radius: 8
                        color: Appearance.colors.colSecondaryContainer
                        StyledText { id: groupText; anchors.centerIn: parent; text: String(card.groupCount); font.pixelSize: 10; color: Appearance.colors.colOnSecondaryContainer }
                    }
                    StyledText {
                        visible: card.liveRight.length > 0
                        text: card.liveRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: card.subtle
                    }
                    RippleButton {  // options (app rules)
                        id: optionsBtn
                        implicitWidth: 24; implicitHeight: 24; buttonRadius: 12
                        opacity: hover.hovered ? 1 : 0.55
                        onClicked: card.optionsRequested(card.app, card.appName)
                        MaterialSymbol { anchors.centerIn: parent; text: "more_horiz"; iconSize: 18; color: Appearance.colors.colOnLayer2 }
                        StyledToolTip { text: "Options for " + card.appName }
                    }
                    RippleButton {  // dismiss
                        id: dismissBtn
                        visible: !card.ongoing || (card.isGroupLead && !card.groupExpanded && card.groupCount > 1)
                        implicitWidth: 24; implicitHeight: 24; buttonRadius: 12
                        opacity: hover.hovered ? 1 : 0.55
                        onClicked: {
                            if (card.isGroupLead && !card.groupExpanded) card.store.post("dismiss-group", { "device": card.deviceId, "app": card.app });
                            else card.store.post("dismiss", { "device": card.deviceId, "key": card.key });
                        }
                        MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 18; color: Appearance.colors.colOnLayer2 }
                        StyledToolTip { text: card.isGroupLead && !card.groupExpanded ? "Dismiss " + card.groupCount + " notifications from " + card.appName : "Dismiss" }
                    }
                }
            }
        }

        StyledText {
            visible: card.title.length > 0
            Layout.fillWidth: true
            text: card.title
            wrapMode: Text.Wrap
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer2
        }
        StyledText {
            visible: card.text.length > 0
            Layout.fillWidth: true
            text: card.text
            wrapMode: Text.Wrap
            maximumLineCount: 8
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer2
        }
        StyledText {  // collapsed group: a preview of the older ones
            visible: card.isGroupLead && !card.groupExpanded && card.groupSummary.length > 0
            Layout.fillWidth: true
            text: card.groupSummary
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: card.subtle
        }

        Item {  // Live Update / progress bar
            visible: card.hasProgress
            Layout.fillWidth: true
            implicitHeight: 6
            Rectangle { anchors.fill: parent; radius: 3; color: Appearance.colors.colLayer1 }
            Rectangle {
                visible: !(card.isLive && card.liveData.indeterminate)
                height: parent.height; radius: 3
                width: card.isLive && Number(card.liveData.max) > 0 ? parent.width * Math.min(1, Number(card.liveData.progress) / Number(card.liveData.max)) : 0
                color: Appearance.colors.colPrimary
            }
            Rectangle {  // indeterminate: a block sliding along
                id: sweep
                visible: card.isLive && card.liveData.indeterminate
                height: parent.height; radius: 3; width: parent.width * 0.3
                color: Appearance.colors.colPrimary
                SequentialAnimation on x {
                    running: sweep.visible && card.visible; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: sweep.parent.width * 0.7; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: sweep.parent.width * 0.7; to: 0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }
        }

        Image {  // the notification's picture; click to enlarge
            id: pic
            visible: card.imageUrl.length > 0 && status === Image.Ready
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(220, width * implicitHeight / Math.max(1, implicitWidth)) : 0
            source: card.imageUrl
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.imageClicked(card.imageUrl) }
        }

        Repeater {  // replies sent from this PC
            model: card.sent
            delegate: StyledText {
                required property var modelData
                Layout.fillWidth: true
                text: (modelData.pending ? "Sending: " : "You: ") + modelData.text
                wrapMode: Text.Wrap
                opacity: modelData.pending ? 0.55 : 1
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colPrimary
            }
        }

        Flow {  // Copy code · Reply · the app's own buttons
            visible: !card.replying && (card.otpCode.length > 0 || card.replyAction.length > 0 || card.buttons.length > 0)
            Layout.fillWidth: true
            spacing: 6
            component Btn: RippleButton {
                property string label
                implicitHeight: 28
                implicitWidth: btnText.implicitWidth + 24
                buttonRadius: 14
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                contentItem: StyledText { id: btnText; anchors.centerIn: parent; text: parent.label; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colPrimary }
            }
            Btn { id: copyBtn; visible: card.otpCode.length > 0; label: "Copy code"; onClicked: card.store.copyCode(card.otpCode) }
            Btn { id: replyBtn; visible: card.replyAction.length > 0; label: card.replyLabel.length > 0 ? card.replyLabel : "Reply"; onClicked: { card.replying = true; input.forceActiveFocus() } }
            Repeater {
                id: actionRepeater
                model: card.buttons
                delegate: Btn {
                    required property var modelData
                    label: modelData.title
                    onClicked: card.store.post("action", { "device": card.deviceId, "key": card.key, "action": modelData.id })
                }
            }
        }

        RowLayout {  // inline reply box
            visible: card.replying
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34; radius: 17
                color: Appearance.colors.colLayer1
                border.width: 1; border.color: Appearance.colors.colPrimary
                StyledTextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onAccepted: card.send()
                    Keys.onEscapePressed: event => { card.replying = false; text = ""; event.accepted = true }
                }
                StyledText {
                    visible: input.text.length === 0
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: "Reply to " + (card.title.length > 0 ? card.title : card.appName)
                    color: card.subtle
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
            RippleButton {
                implicitWidth: 34; implicitHeight: 34; buttonRadius: 17
                enabled: input.text.trim().length > 0
                opacity: enabled ? 1 : 0.4
                onClicked: card.send()
                MaterialSymbol { anchors.centerIn: parent; text: "send"; iconSize: 18; color: Appearance.colors.colPrimary }
            }
        }

        RowLayout {  // group bar: +N more / Show less · Clear N
            visible: card.isGroupLead
            Layout.fillWidth: true
            spacing: 6
            RippleButton {
                id: moreBtn
                implicitHeight: 26; implicitWidth: moreRow.implicitWidth + 20; buttonRadius: 13
                colBackground: Appearance.colors.colSecondaryContainer
                onClicked: card.store.post("toggle-group", { "app": card.app })
                RowLayout {
                    id: moreRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol { text: card.groupExpanded ? "expand_less" : "expand_more"; iconSize: 16; color: Appearance.colors.colOnSecondaryContainer }
                    StyledText { text: card.groupExpanded ? "Show less" : "+" + (card.groupCount - 1) + " more"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnSecondaryContainer }
                }
            }
            RippleButton {
                id: clearGroupBtn
                implicitHeight: 26; implicitWidth: clearRow.implicitWidth + 20; buttonRadius: 13
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: card.store.post("dismiss-group", { "device": card.deviceId, "app": card.app })
                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol { text: "close"; iconSize: 16; color: Appearance.colors.colPrimary }
                    StyledText { text: "Clear " + card.groupCount; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colPrimary }
                }
            }
        }
    }
}
