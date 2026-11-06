#!/usr/bin/env bash
# While locked, Hyprland puts the monitor on a temp workspace (id ~2147483647-N). The bar workspace model and the overview
# followed it (overview clamped it to 100), so after unlocking they sometimes showed the "100th" workspace. Fix: ignore ids
# >= 100000 and keep the last real workspace. Idempotent.
set -euo pipefail
QS="$HOME/.config/quickshell/ii"
BACKUP="$HOME/backups/lock-workspace-fix/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BACKUP"
for f in modules/common/models/WorkspaceModel.qml modules/ii/overview/OverviewWidget.qml modules/ii/bar/Workspaces.qml; do cp "$QS/$f" "$BACKUP/$(basename "$f")"; done
python3 - "$QS" <<'PY'
import sys
qs = sys.argv[1]
def sub(f, old, new):
    p = qs + "/" + f; s = open(p).read()
    if new in s: return
    if old not in s: sys.exit(f"pattern not found in {f}: {old[:50]}")
    open(p, "w").write(s.replace(old, new, 1))
sub("modules/common/models/WorkspaceModel.qml",
    "    readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1\n",
    "    // lock-workspace-fix: ignore the lock screen's temp workspace (huge id), keep the last real one\n"
    "    readonly property int rawActiveWorkspace: monitor?.activeWorkspace?.id ?? 1\n"
    "    property int lastRealWorkspace: rawActiveWorkspace < 100000 ? rawActiveWorkspace : 1\n"
    "    onRawActiveWorkspaceChanged: if (rawActiveWorkspace < 100000) lastRealWorkspace = rawActiveWorkspace\n"
    "    readonly property int activeWorkspace: rawActiveWorkspace < 100000 ? rawActiveWorkspace : lastRealWorkspace\n")
sub("modules/ii/overview/OverviewWidget.qml",
    "    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))\n",
    "    // lock-workspace-fix: hold the last real workspace while the lock screen's temp workspace is active\n"
    "    readonly property int rawActiveId: monitor?.activeWorkspace?.id ?? 1\n"
    "    property int lastRealId: rawActiveId < 100000 ? rawActiveId : 1\n"
    "    onRawActiveIdChanged: if (rawActiveId < 100000) lastRealId = rawActiveId\n"
    "    readonly property int effectiveActiveWorkspaceId: Math.max(1, rawActiveId < 100000 ? rawActiveId : lastRealId)\n")
sub("modules/ii/bar/Workspaces.qml",
    "(monitor?.activeWorkspace?.id - 1) % wsModel.shownCount",
    "(wsModel.activeWorkspace - 1) % wsModel.shownCount")
PY
echo "Done. Restart the shell: qs -c ii kill; nohup qs -c ii >/dev/null 2>&1 & disown"
