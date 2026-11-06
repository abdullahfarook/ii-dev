import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.widgets

// Phone notifications (NectarLink): bar button with the notification count + a side panel with everything NectarLink's
// Notifications section does: live feed with groups and Live Updates, reply / actions / Copy code, dismiss, Clear all with
// Undo, history with search, per-app rules. Talks to NectarLink's local API through phone-notifications.sh. Panel behavior
// (open/close, click-away, Esc, monitors) comes from WidgetBase; the panel content only exists while open, the feed
// (a long poll that returns the moment something changes) lives on the button so the badge is always right.
WidgetBase {
    id: root
    iconName: "smartphone"
    iconSize: 17                        // tall glyph: height matches globe and cube
    implicitWidth: 24                   // narrow glyph: tighter button so the gap to its neighbours matches the other icons
    panelId: "phone-notifications"
    iconOpacity: nl.connected && nl.phoneOnline ? 1 : 0.4

    readonly property int count: nl.connected ? nl.count : 0   // read by the bar slot (shown while there are notifications)
    PhoneNotifStore { id: nl; open: root.open }
    onOpenChanged: if (open) nl.onOpened()
    Connections { target: nl; function onRequestClose() { root.close() } }   // an action that opens a window

    // Right-click menu: open NectarLink, start it, history on/off
    menuContent: Component { ColumnLayout {
        spacing: 0
        component Entry: RippleButton {
            property string sym
            property string label
            implicitHeight: 36
            buttonRadius: Appearance.rounding.small
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2Hover
            contentItem: RowLayout {
                spacing: 8
                MaterialSymbol { text: parent.parent.sym; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer2 }
                StyledText { text: parent.parent.label; color: Appearance.colors.colOnLayer2 }
            }
        }
        Entry { sym: "tune"; label: "App rules"; onClicked: { nl.pendingSheet = "rules"; root.closeMenu(); root.open = true } }
        Entry { sym: "open_in_new"; label: "Open NectarLink"; onClicked: { Quickshell.execDetached([nl.helper, "open"]); root.closeMenu() } }
        Entry { sym: "refresh"; label: "Reconnect"; onClicked: { nl.startNectarLink(); nl.poll(); root.closeMenu() } }
        Entry { visible: nl.connected; sym: nl.historyEnabled ? "history_toggle_off" : "history"; label: nl.historyEnabled ? "Turn history off" : "Turn history on"; onClicked: { nl.setHistoryEnabled(!nl.historyEnabled); root.closeMenu() } }
    } }

    // Count badge (top-right like the mail/Teams badges)
    Rectangle {
        visible: nl.connected && nl.count > 0
        anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 0 }
        implicitWidth: Math.max(14, badgeText.implicitWidth + 8); implicitHeight: 14; radius: 7
        color: Appearance.colors.colPrimary
        StyledText { id: badgeText; anchors.centerIn: parent; text: nl.count > 99 ? "99+" : nl.count; font.pixelSize: 9; color: Appearance.colors.colOnPrimary }
    }

    panelContent: Component { PhoneNotifPanel { store: nl; onCloseRequested: root.close() } }
}
