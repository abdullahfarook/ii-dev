#!/usr/bin/env bash
# NectarLink with the notifications API (idempotent): builds the fork (branch feat/notifications-api of
# github.com/abdullahfarook/nectarlink, based on v0.1.5) and installs the binary next to the stock AppImage.
# The widget (../phone-notifications) starts it hidden in the tray and talks to /v1/notifications*.
#   ./install.sh            build + install
#   ./install.sh --no-build install the last build only
set -euo pipefail
SRC="${NECTARLINK_SRC:-$HOME/repos/nectarlink}"
DEST="$HOME/.local/share/nectarlink-patched"
DATA="$HOME/.local/share/Nectarlink"
BACKUP="$HOME/backups/nectarlink/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP" "$DEST"
[ -f "$DATA/desktop-settings.json" ] && cp "$DATA/desktop-settings.json" "$BACKUP/"
[ -x "$DEST/nectarlink-desktop" ] && cp "$DEST/nectarlink-desktop" "$BACKUP/"
if [ "${1:-}" != "--no-build" ]; then (cd "$SRC" && cargo build --release -p nectarlink-desktop); fi
BIN="$SRC/target/release/nectarlink-desktop"
[ -x "$BIN" ] || { echo "no build at $BIN" >&2; exit 1; }
# Swap while NectarLink is stopped (pgrep -x: the exact name, so this script is not matched)
if pgrep -x nectarlink-desk >/dev/null; then pkill -x nectarlink-desk; sleep 2; fi
install -Dm755 "$BIN" "$DEST/nectarlink-desktop"
# The local automation API is off by default: turn it on
python3 - "$DATA/desktop-settings.json" <<'PY'
import json, sys
p = sys.argv[1]
try: d = json.load(open(p))
except Exception: d = {}
if not d.get("localApiEnabled"):
    d["localApiEnabled"] = True
    json.dump(d, open(p, "w"), indent=2)
PY
echo "Installed $DEST/nectarlink-desktop. Start it: ~/.config/hypr/custom/phone-notifications.sh start"
