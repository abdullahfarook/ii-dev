#!/usr/bin/env python3
"""Overview: show the icon of the focused app in front of the focused workspace preview (so ALT+Tab through the windows
of a float-mode workspace shows which one is selected). Idempotent."""
import sys
p = sys.argv[1]; s = open(p).read()
if "super-tab: selected app icon" in s: sys.exit(0)
anchor = "                border.width: 2\n                border.color: root.activeBorderColor\n"
if anchor not in s: sys.exit("anchor not found in OverviewWidget.qml")
add = anchor + '''                // super-tab: selected app icon, big in front of the preview
                StyledImage {
                    readonly property var act: HyprlandData.windowByAddress["0x" + (Hyprland.activeToplevel?.address ?? "")]
                    readonly property int count: root.windowByAddress ? HyprlandData.windowList.filter(w => w.workspace.id === root.effectiveActiveWorkspaceId).length : 0
                    visible: act !== undefined && act.workspace.id === root.effectiveActiveWorkspaceId && count > 1
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.35
                    height: width
                    mipmap: true
                    source: Quickshell.iconPath(AppSearch.guessIcon(act?.class ?? ""), "image-missing")
                }
'''
s = s.replace(anchor, add, 1)
old = "                z: root.windowZ\n                width: root.workspaceImplicitWidth"
assert old in s
s = s.replace(old, "                z: 50  // super-tab: above the (fullscreen) windows so the selected icon shows in front\n                width: root.workspaceImplicitWidth", 1)
open(p, "w").write(s)
