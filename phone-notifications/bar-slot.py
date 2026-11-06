#!/usr/bin/env python3
"""Adds the phone notifications button to the left bar like the other widgets (idempotent): its own RevealSlot (shown while
the pointer is on the left of the bar, and always while there are notifications or its panel is open), the `phoneNotif`
switch and place in Settings > Bar, and the Config defaults. Run by install.sh with the quickshell ii folder as argument."""
import re, sys
Q = sys.argv[1]
def rw(path, fn):
    s = open(path).read(); n = fn(s)
    if n != s: open(path, "w").write(n)

def config(s):
    if "phoneNotif" in s: return s
    s = s.replace('"gist"]', '"gist", "phoneNotif"]', 1)
    s = re.sub(r"( *)property bool gist: true\n", lambda m: m.group(0) + f"{m.group(1)}property bool phoneNotif: true\n", s, 1)
    return s
rw(Q + "/modules/common/Config.qml", config)

def settings(s):
    if "phoneNotif" in s: return s
    return s.replace('gist: ["code", "Gists"] })', 'gist: ["code", "Gists"], phoneNotif: ["smartphone", "Phone notifications"] })', 1)
rw(Q + "/modules/settings/BarConfig.qml", settings)

def bar(s):
    # an earlier install put the bare button inside the Docker slot: take it out
    s = re.sub(r"\n *PhoneNotifButton \{ // phone notifications \(NectarLink\)\n(?:.*\n)*? *\}\n(?= *\})", "\n", s, 1) if "slot_phoneNotif" not in s else s
    if "slot_phoneNotif" in s: return s
    s = s.replace("gist: slot_gist }", "gist: slot_gist, phoneNotif: slot_phoneNotif }", 1)
    s = s.replace('"google", "gist"]', '"google", "gist", "phoneNotif"]', 1)
    col = "colBackground: barLeftSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)"
    m = None
    for m2 in re.finditer(r"^( *)RevealSlot \{\n.*?^\1\}\n", s, re.S | re.M):
        if "id: slot_gist" in m2.group(0): m = m2
    if not m: sys.exit("slot_gist not found")
    i = m.group(1)
    block = (f"\n{i}RevealSlot {{\n{i}    id: slot_phoneNotif\n{i}    Layout.row: 0\n{i}    Layout.column: iconRow.colOf(\"phoneNotif\")\n{i}    open: iconRow.hot\n"
             f"{i}    pinned: Config.options.bar.buttons.pinned.includes(\"phoneNotif\") || phoneBtn.count > 0 || phoneBtn.open || phoneBtn.menuOpen\n"
             f"{i}    sticky: Config.options.bar.buttons.pinned.includes(\"phoneNotif\") || phoneBtn.count > 0\n"
             f"{i}    active: Config.options.bar.buttons.phoneNotif\n"
             f"{i}    PhoneNotifButton {{ // phone notifications (NectarLink)\n{i}        id: phoneBtn\n{i}        Layout.alignment: Qt.AlignVCenter\n"
             f"{i}        Layout.leftMargin: 2\n{i}        {col}\n{i}    }}\n{i}}}\n")
    return s[:m.end()] + block + s[m.end():]
rw(Q + "/modules/ii/bar/BarContent.qml", bar)
