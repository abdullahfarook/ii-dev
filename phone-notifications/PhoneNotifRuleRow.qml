import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// One app in the rules list: icon, name and a Show / Quiet / Hidden choice.
Item {
    id: row
    required property var store
    required property var modelData
    implicitHeight: 52

    Rectangle { anchors { fill: parent; topMargin: 2; bottomMargin: 2 } radius: Appearance.rounding.small; color: Appearance.colors.colLayer2 }
    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
        spacing: 10
        Item {
            implicitWidth: 28; implicitHeight: 28
            Image { id: ic; anchors.fill: parent; source: row.modelData.icon; sourceSize: Qt.size(56, 56); asynchronous: true; visible: status === Image.Ready }
            Rectangle {
                anchors.fill: parent; visible: ic.status !== Image.Ready; radius: 14
                color: Qt.hsla(((row.modelData.name.charCodeAt(0) || 0) * 37 % 360) / 360, 0.45, 0.62, 1)
                StyledText { anchors.centerIn: parent; text: (row.modelData.name.charAt(0) || "?").toUpperCase(); color: "#1b1b1f" }
            }
        }
        StyledText { Layout.fillWidth: true; text: row.modelData.name; elide: Text.ElideRight; color: Appearance.colors.colOnLayer2 }
        Repeater {
            model: [{ "k": "show", "t": "Show" }, { "k": "quiet", "t": "Quiet" }, { "k": "hidden", "t": "Hidden" }]
            delegate: RippleButton {
                required property var modelData
                implicitHeight: 28; implicitWidth: choiceText.implicitWidth + 20; buttonRadius: 14
                toggled: row.modelData.rule === modelData.k
                onClicked: row.store.setRule(row.modelData.app, modelData.k)
                StyledText { id: choiceText; anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: Appearance.font.pixelSize.smaller; color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2 }
            }
        }
    }
}
