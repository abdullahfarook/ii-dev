#!/usr/bin/env bash
# Left bar: hovering no longer slides the icons out inside the bar; a floating tray under the bar lists them in rounded groups (Communication, Dev, System) with a name card under the hovered icon. Pinned/badge icons stay in the bar.
# Run AFTER zbar-reveal and zbar-widget-layout (patches BarContent.qml, adds LeftTray.qml; idempotent).
set -euo pipefail
Q="$HOME/.config/quickshell/ii/modules/ii/bar"; D="$(dirname "$0")"
B="$HOME/backups/zbar-groups/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$B"; cp "$Q/BarContent.qml" "$Q/ActiveWindow.qml" "$B/"; echo "Backed up to $B"
# TRAY=0 (default, set in ./mode): old behaviour, icons slide out inside the bar. TRAY=1: floating tray.
TRAY=${TRAY:-$(cat "$D/mode" 2>/dev/null || echo 0)}
if [ "$TRAY" = 1 ]; then install -Dm644 "$D/LeftTray.qml" "$Q/LeftTray.qml"; python3 "$D/patch.py" "$Q/BarContent.qml"
else python3 "$D/patch.py" "$Q/BarContent.qml" --undo; fi
echo "Done. Restart the shell: qs -c ii kill; nohup qs -c ii >/dev/null 2>&1 & disown"
