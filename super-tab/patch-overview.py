#!/usr/bin/env python3
"""Overview: show the icon of the focused app in front of the focused workspace preview (so ALT+Tab through the windows
of a float-mode workspace shows which one is selected). Idempotent."""
import sys
p = sys.argv[1]; s = open(p).read()
DONE1 = "super-tab: selected app icon v2" in s
anchor = "                border.width: 2\n                border.color: root.activeBorderColor\n"
if not DONE1 and anchor not in s: sys.exit("anchor not found in OverviewWidget.qml")
add = anchor + '''                // super-tab: selected app icon v2, big in front of the preview
                StyledImage {
                    id: icon
                    readonly property var act: HyprlandData.windowByAddress["0x" + (Hyprland.activeToplevel?.address ?? "")]
                    readonly property var wsWins: HyprlandData.windowList.filter(w => w.workspace.id === root.effectiveActiveWorkspaceId)
                    // only on float-mode workspaces (several windows, all floating); tiled workspaces keep the plain preview
                    visible: act !== undefined && act.workspace.id === root.effectiveActiveWorkspaceId && wsWins.length > 1 && wsWins.every(w => w.floating)
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.35
                    height: width
                    mipmap: true
                    source: Quickshell.iconPath(AppSearch.guessIcon(act?.class ?? ""), "image-missing")
                }
'''
if not DONE1: s = s.replace(anchor, add, 1)
old = "                z: root.windowZ\n                width: root.workspaceImplicitWidth"
assert DONE1 or old in s
if not DONE1: s = s.replace(old, "                z: icon.visible ? 50 : root.windowZ  // super-tab: above the (fullscreen) windows only while the selected icon shows\n                width: root.workspaceImplicitWidth", 1)
open(p, "w").write(s)

# --- v3: app icons at the top right of every float-mode workspace preview ---
s = open(p).read()
if "super-tab: float app icons v5" not in s:
    import re
    s = re.sub(r"            // super-tab: float app icons.*?(?=            Rectangle \{ // Focused workspace indicator)", "", s, flags=re.S)
    a = "            Rectangle { // Focused workspace indicator\n"
    assert a in s, "focused indicator anchor not found"
    block = '''            // super-tab: float app icons v5: open apps (one icon per app) at the top right of float-mode workspaces
            Repeater {
                model: root.workspacesShown
                delegate: Item {
                    id: fIcons
                    required property int index
                    readonly property int wsId: root.workspaceGroup * root.workspacesShown + index + 1
                    readonly property var wins: HyprlandData.windowList.filter(w => w.workspace.id === wsId).sort((a, b) => a.address < b.address ? -1 : 1)
                    visible: wins.length > 1 && wins.every(w => w.floating)
                    z: 60
                    width: root.workspaceImplicitWidth
                    height: root.workspaceImplicitHeight
                    x: (root.workspaceImplicitWidth + workspaceSpacing) * root.getWsColumn(wsId)
                    y: (root.workspaceImplicitHeight + workspaceSpacing) * root.getWsRow(wsId)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: fRow.implicitWidth + 10
                        height: fRow.implicitHeight + 10
                        radius: 10
                        color: Appearance.colors.colBackgroundSurfaceContainer
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant
                    Row {
                        id: fRow
                        anchors.centerIn: parent
                        spacing: 4
                        layoutDirection: Qt.RightToLeft
                        Repeater {
                            model: fIcons.wins.slice(0, 6)
                            delegate: Item {
                                id: fIcon
                                required property var modelData
                                width: 24
                                height: 24
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    readonly property bool sel: ("0x" + (Hyprland.activeToplevel?.address ?? "")) === fIcon.modelData.address
                                    color: sel ? Appearance.colors.colPrimaryContainer : (fMa.containsMouse ? Appearance.colors.colLayer1Hover : "transparent")
                                    border.width: sel ? 2 : 0
                                    border.color: Appearance.colors.colPrimary
                                }
                                StyledImage {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    mipmap: true
                                    source: Quickshell.iconPath(AppSearch.guessIcon(fIcon.modelData.class), "image-missing")
                                }
                                MouseArea {
                                    id: fMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`hl.dsp.focus({window = "address:${fIcon.modelData.address}"})`)
                                        Hyprland.dispatch(`hl.dsp.window.alter_zorder({ mode = 'top', window = 'address:${fIcon.modelData.address}' })`)
                                    }
                                }
                                StyledToolTip { text: fIcon.modelData.title }
                            }
                        }
                    }
                    }
                }
            }

'''
    s = s.replace(a, block + a, 1)
    open(p, "w").write(s)

# --- v3b: on float-mode workspaces only the focused window gets a preview ---
s = open(p).read()
if "super-tab: float preview only focused" not in s:
    a = "                    property bool isActive: modelData?.HyprlandToplevel?.address === Hyprland.activeToplevel?.address\n"
    assert a in s, "isActive anchor not found"
    s = s.replace(a, a + '''                    // super-tab: float preview only focused: on float-mode workspaces only the focused window is drawn
                    readonly property var wsAll: HyprlandData.windowList.filter(w => w.workspace.id === windowData?.workspace?.id)
                    visible: isActive || !(wsAll.length > 1 && wsAll.every(w => w.floating))
''', 1)
    open(p, "w").write(s)

# --- v4: the window preview already shows the app icon; drop the extra big icon on the focused workspace ---
s = open(p).read()
old = "visible: act !== undefined && act.workspace.id === root.effectiveActiveWorkspaceId && wsWins.length > 1 && wsWins.every(w => w.floating)"
if old in s:
    s = s.replace(old, "visible: false  // super-tab: the window preview has its own icon; the tray highlights the selection")
    open(p, "w").write(s)
