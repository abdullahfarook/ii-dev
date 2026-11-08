#!/usr/bin/env python3
# usage: patch.py BarContent.qml (idempotent): hovering the bar's left side no longer slides the icons out inside the bar; a floating grouped tray under the bar shows them instead
import re, sys
p = sys.argv[1]; s = open(p).read()
if "--undo" in sys.argv:   # back to the old inline slide-out (icons expand to the right inside the bar)
    s = s.replace("open: false\n", "open: iconRow.hot\n")
    s = re.sub(r"leftTray\.hovered \|\| (?:\w+\.menuOpen === true \|\| )*", "", s)
    s = s.replace("id: closeTimer; interval: 1000;", "id: closeTimer; interval: 700;", 1)
    s = re.sub(r"    LeftTray \{ // floating grouped tray under the bar \(zbar-groups\).*?\n    \}\n\n", "", s, flags=re.S)
    if "zbar-hide-title" not in s:   # hide the window title while the icons slide out
        t = "                visible: root.useShortenedForm === 0\n            }\n        }\n    }"
        assert s.count(t) == 1
        s = s.replace(t, "                visible: root.useShortenedForm === 0\n                opacity: iconRow.hot ? 0 : 1 // hide title while the icons slide out (zbar-hide-title)\n                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutCubic } }\n            }\n        }\n    }")
    open(p, "w").write(s)
    a = p.replace("BarContent.qml", "ActiveWindow.qml"); w = open(a).read()
    open(a, "w").write(w.replace("            active: false   // zbar-groups: no title tooltip (it covered the tray)\n", ""))
    print("tray off, inline slide-out back"); sys.exit(0)
done = "LeftTray {" in s
# key, button id, label, tray icon, icon size (optical: narrow/tall glyphs smaller so all look the same)
ENT = [("mail","mailBtn","Mail","mail",20),("teams","teamsBtn","Teams","forum",20),("phoneNotif","phoneBtn","Phone notifications","smartphone",17),
       ("git","gitBtn","Git","merge_type",20),("consolePanel","consoleBtn","Console","terminal",20),("docker","dockerBtn","Docker","deployed_code",20),
       ("gist","gistBtn","Gists","code",20),("agents","agentsBtn","Agent sessions","smart_toy",19),
       ("taskManager","taskBtn","Task manager","memory",20),("fileSearch","fileBtn","File search","manage_search",20),("google","googleBtn","Google search","public",20)]
GROUPS = [["mail","teams","phoneNotif"], ["git","consolePanel","docker","gist","agents"], ["taskManager","fileSearch","google"]]
by = {k: (b, l, i, z) for k, b, l, i, z in ENT}
def bar(s):
    # 1. no inline slide-out (pinned / badge / open-panel icons stay in the bar as before)
    n = s.count("open: iconRow.hot"); assert n >= 11, n
    s = s.replace("open: iconRow.hot", "open: false")
    # 2. the tray stays up while the pointer is on it
    s = s.replace("readonly property bool wantOpen: barLeftSideMouseArea.hovered ||", "readonly property bool wantOpen: barLeftSideMouseArea.hovered || leftTray.hovered ||", 1)
    # 2c. ...and while any widget's right-click menu is open (closing the tray under an open menu dismissed the menu)
    s = s.replace("leftTray.hovered ||", "leftTray.hovered || " + " || ".join(f"{b}.menuOpen === true" for _, b, *_ in ENT) + " ||", 1)
    # 2b. stay open a bit longer after the pointer leaves (the tray is a jump away from the bar)
    s = s.replace("id: closeTimer; interval: 700;", "id: closeTimer; interval: 1000;", 1)
    # 3. the tray itself
    def grp(keys):
        return "[" + ", ".join(f'{{ key: "{k}", btn: {by[k][0]}, slot: slot_{k}, label: "{by[k][1]}", icon: "{by[k][2]}", size: {by[k][3]} }}' for k in keys) + "]"
    groups = "[" + ", ".join(grp(g) for g in GROUPS) + "]"
    tray = f'''    LeftTray {{ // floating grouped tray under the bar (zbar-groups)
            id: leftTray
            shown: iconRow.hot
            anchorItem: leftSidebarButton
            groups: {groups}.map(g => g.filter(e => Config.options.bar.buttons[e.key] !== false && !e.slot.pinned)).filter(g => g.length > 0)
        }}

    '''
    m = re.search(r"    FocusedScrollMouseArea \{ // Right side", s); assert m, "right side not found"
    s = s[:m.start()] + tray + s[m.start():]
    return s
if done: print("bar already patched")
else: open(p, "w").write(bar(s)); print("patched")

# 4. no full-title tooltip under the window title: it covered the tray
a = p.replace("BarContent.qml", "ActiveWindow.qml"); w = open(a).read()
if "zbar-groups: no title tooltip" not in w:
    w2 = w.replace("        StyledPopup {\n            hoverTarget: hoverArea\n", "        StyledPopup {\n            hoverTarget: hoverArea\n            active: false   // zbar-groups: no title tooltip (it covered the tray)\n", 1)
    assert w2 != w, "title popup not found"; open(a, "w").write(w2); print("title tooltip off")
