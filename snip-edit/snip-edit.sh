#!/usr/bin/env bash
# Usage: snip-edit.sh <image>
# Shows a toast "Screenshot copied" with an Edit button; Edit opens Satty (arrows, boxes, text, blur, crop).
# The popup hides after 6 s but the entry (and its Edit button) stays in the notification panel, so we listen for
# the click on D-Bus for up to 1 h (notify-send -A would quit when the popup expires).
# Temp files (under $XDG_RUNTIME_DIR) are deleted afterwards; saved ones (screenSnip.savePath) are kept.
img="$1"; [[ -f "$img" ]] || exit 1
tmp=0; [[ "$img" == "${XDG_RUNTIME_DIR:-/run/user/$UID}"/* ]] && tmp=1
log=$(mktemp); trap 'kill $mon 2>/dev/null; rm -f "$log"; [[ $tmp == 1 ]] && rm -f "$img"' EXIT
dbus-monitor --session "type='signal',interface='org.freedesktop.Notifications'" > "$log" 2>&1 & mon=$!
sleep 0.3
id=$(gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
     --method org.freedesktop.Notifications.Notify Screenshot 0 "$img" "Screenshot copied" \
     "Click Edit to draw, add text or crop" "['edit','Edit']" "{}" 6000 | sed -n 's/.*uint32 \([0-9]*\).*/\1/p')
[[ -n "$id" ]] || exit 1
for ((i = 0; i < 3600; i++)); do
    # ActionInvoked: "uint32 <id>" then 'string "edit"'
    if grep -A1 "member=ActionInvoked" "$log" | grep -q "uint32 $id$"; then
        out=(); [[ $tmp == 0 ]] && out=(-o "${img%.png}-edited.png")
        satty -f "$img" --copy-command wl-copy --early-exit copy --initial-tool arrow --disable-notifications \
              --actions-on-enter save-to-clipboard --actions-on-escape exit "${out[@]}"
        break
    fi
    # dismissed by the user (reason 2) or closed by a caller (3): stop waiting
    grep -A2 "member=NotificationClosed" "$log" | grep -A1 "uint32 $id$" | grep -q "uint32 [23]$" && break
    sleep 1
done
exit 0
