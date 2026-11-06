import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// One dismissed notification in the history list: icon, app · sub · time, title, text.
Item {
    id: row
    required property var store
    required property string appName
    required property string title
    required property string text
    required property string sub
    required property real when
    required property string iconUrl
    implicitHeight: col.implicitHeight + 20

    readonly property string timeText: {
        store.clock;
        const d = new Date(when);
        return Date.now() - when < 24 * 3600 * 1000 ? Qt.formatTime(d, "HH:mm") : Qt.formatDate(d, "d MMM");
    }

    Rectangle { anchors { fill: parent; topMargin: 2; bottomMargin: 2 } radius: Appearance.rounding.small; color: Appearance.colors.colLayer2 }
    RowLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; topMargin: 12 }
        spacing: 10
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 28; implicitHeight: 28
            Image { id: ic; anchors.fill: parent; source: row.iconUrl; sourceSize: Qt.size(56, 56); asynchronous: true; visible: status === Image.Ready }
            Rectangle {
                anchors.fill: parent; visible: ic.status !== Image.Ready; radius: 14
                color: Qt.hsla(((row.appName.charCodeAt(0) || 0) * 37 % 360) / 360, 0.45, 0.62, 1)
                StyledText { anchors.centerIn: parent; text: (row.appName.charAt(0) || "?").toUpperCase(); color: "#1b1b1f" }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: [row.appName, row.sub, row.timeText].filter(s => s.length > 0).join(" · ")
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            StyledText { visible: row.title.length > 0; Layout.fillWidth: true; text: row.title; wrapMode: Text.Wrap; font.weight: Font.Medium; color: Appearance.colors.colOnLayer2 }
            StyledText { visible: row.text.length > 0; Layout.fillWidth: true; text: row.text; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer2 }
        }
    }
}
