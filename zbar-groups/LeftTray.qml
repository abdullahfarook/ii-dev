import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets

// Floating tray under the bar's left side (zbar-groups): shown while `shown`, it lists every enabled bar widget in rounded groups.
// A click presses the real bar button (so panels, menus and badges keep working); the hovered one gets a name card below it.
Item {
    id: root
    property bool shown: false
    property Item anchorItem            // the tray's left edge lines up with this (the AI button)
    property var groups: []             // [[{ btn, label }]]: btn is the real bar button
    property bool hovered: false       // set from inside the window (its ids are not visible out here)
    property bool hold: false
    onShownChanged: { if (shown) { holdTimer.stop(); hold = true } else holdTimer.restart() }
    Timer { id: holdTimer; interval: 220; onTriggered: root.hold = false }   // keep the window while it fades out

    LazyLoader {
        active: root.shown || root.hold
        component: PanelWindow {
            id: win
            color: "transparent"
            anchors { left: true; top: true }
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            implicitWidth: card.width + 2 * Appearance.sizes.elevationMargin
            implicitHeight: card.height + labelCard.height + 8 + 2 * Appearance.sizes.elevationMargin
            WlrLayershell.namespace: "quickshell:popup"
            WlrLayershell.layer: WlrLayer.Overlay
            margins {
                left: Math.max(0, win.QsWindow?.mapFromItem(root.anchorItem, 0, 0).x ?? 0) - Appearance.sizes.elevationMargin
                top: Appearance.sizes.barHeight - Appearance.sizes.elevationMargin + 4
            }
            mask: Region { item: card }

            Item {
                id: stage
                anchors.fill: parent
                opacity: root.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                transform: Translate { y: root.shown ? 0 : -6; Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }

                StyledRectangularShadow { target: card }
                Rectangle {
                    id: card
                    x: Appearance.sizes.elevationMargin; y: Appearance.sizes.elevationMargin
                    width: row.implicitWidth + 16; height: 52
                    radius: height / 2
                    color: Appearance.m3colors.m3surfaceContainerLow   // opaque: the window under it must not show through
                    border.width: 1; border.color: Appearance.colors.colLayer0Border
                    HoverHandler { id: hoverTrack; onHoveredChanged: root.hovered = hovered }
                    Component.onDestruction: root.hovered = false
                    RowLayout {
                        id: row
                        anchors.centerIn: parent
                        spacing: 14      // gap between groups
                        Repeater {
                            model: root.groups
                            delegate: Rectangle {
                                id: grp
                                required property var modelData
                                implicitWidth: items.implicitWidth + 14; implicitHeight: 40
                                radius: height / 2
                                color: Appearance.m3colors.m3surfaceContainerHigh
                                border.width: 1; border.color: Appearance.colors.colLayer0Border
                                RowLayout {
                                    id: items
                                    anchors.centerIn: parent
                                    spacing: 2           // same gap inside every group
                                    Repeater {
                                        model: grp.modelData
                                        delegate: RippleButton {
                                            id: tb
                                            required property var modelData
                                            readonly property Item real: modelData.btn
                                            implicitWidth: 34; implicitHeight: 34
                                            buttonRadius: 17
                                            colBackground: "transparent"
                                            toggled: real?.open === true
                                            onClicked: { if (real) real.clicked() }
                                            altAction: () => { if (real?.altAction) real.altAction(null) }
                                            onHoveredChanged: if (hovered) { labelCard.target = tb; labelCard.text = modelData.label }
                                            Item {  // loader line below the icon, the same as on the bar button (Mail, Teams, Gists while busy/syncing)
                                                id: loader
                                                visible: tb.real?.busy === true || tb.real?.syncing === true
                                                anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
                                                width: parent.width - 12; height: 2
                                                clip: true
                                                Rectangle { anchors.fill: parent; radius: 1; color: Appearance.colors.colOnLayer0; opacity: 0.2 }
                                                Rectangle {
                                                    id: runner
                                                    height: parent.height; width: parent.width * 0.4; radius: 1
                                                    color: Appearance.colors.colPrimary
                                                    SequentialAnimation on x {
                                                        running: loader.visible; loops: Animation.Infinite
                                                        NumberAnimation { from: -runner.width; to: loader.width; duration: 900; easing.type: Easing.InOutQuad }
                                                    }
                                                }
                                            }
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: tb.modelData.icon        // one fixed icon per widget, so the tray looks the same whatever the bar button draws
                                                iconSize: tb.modelData.size
                                                opacity: tb.real?.iconOpacity ?? (tb.real?.running === false ? 0.4 : 1)   // dimmed like the bar button: iconOpacity (Docker, Mail, Phone, Agents) or Teams not running
                                                color: tb.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // name card under the hovered icon: slides along and fades, one card for the whole tray
                Rectangle {
                    id: labelCard
                    property Item target: null
                    property string text: ""
                    readonly property bool want: hoverTrack.hovered && target !== null && target.hovered
                    width: lbl.implicitWidth + 20; height: lbl.implicitHeight + 12
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer
                    border.width: 1; border.color: Appearance.colors.colLayer0Border
                    y: card.y + card.height + 8
                    x: target ? Math.max(0, Math.min(win.width - width, card.x + target.mapToItem(card, target.width / 2, 0).x - width / 2)) : 0
                    opacity: want ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    StyledText { id: lbl; anchors.centerIn: parent; text: labelCard.text; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.small }
                }
            }
        }
    }
}
