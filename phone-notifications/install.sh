#!/usr/bin/env bash
# Phone notifications widget (idempotent): bar button with the notification count + side panel (feed, reply, actions,
# dismiss, Clear all + Undo, history, app rules) on top of NectarLink's local API (see ../nectarlink-api/).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
Q="$HOME/.config/quickshell/ii"; BAR="$Q/modules/ii/bar/BarContent.qml"
BACKUP="$HOME/backups/phone-notifications/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"; cp "$BAR" "$Q/modules/common/Config.qml" "$Q/modules/settings/BarConfig.qml" "$BACKUP/"
"$REPO/../widget-base/install.sh"   # shared panel behavior (WidgetBase.qml)
for f in PhoneNotifButton PhoneNotifStore PhoneNotifPanel; do
  [ -f "$Q/modules/ii/bar/$f.qml" ] && cp "$Q/modules/ii/bar/$f.qml" "$BACKUP/"
  install -Dm644 "$REPO/$f.qml" "$Q/modules/ii/bar/$f.qml"
done
rm -f "$Q/modules/ii/bar/PhoneNotifCard.qml" "$Q/modules/ii/bar/PhoneNotifHistoryRow.qml" "$Q/modules/ii/bar/PhoneNotifRuleRow.qml"   # replaced by the ported NectarLink components
rm -rf "$Q/modules/ii/bar/nectar"; cp -r "$REPO/nectar" "$Q/modules/ii/bar/nectar"   # NectarLink's own QML: Theme, components (see nectar/README.md)
install -Dm755 "$REPO/phone-notifications.sh" "$HOME/.config/hypr/custom/phone-notifications.sh"
python3 "$REPO/bar-slot.py" "$Q"   # own bar slot + Settings switch (like Mail, Docker, ...)
echo "Done. Restart the shell: qs -c ii kill; nohup qs -c ii >/dev/null 2>&1 & disown"
