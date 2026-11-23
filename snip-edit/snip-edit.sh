#!/usr/bin/env bash
# Usage: snip-edit.sh <image>
# Shows a toast "Screenshot copied" with an Edit button; Edit opens Satty (arrows, boxes, text, blur, crop).
# Temp files (under $XDG_RUNTIME_DIR) are deleted afterwards; saved ones (screenSnip.savePath) are kept.
img="$1"; [[ -f "$img" ]] || exit 1
tmp=0; [[ "$img" == "${XDG_RUNTIME_DIR:-/run/user/$UID}"/* ]] && tmp=1
# stay alive up to 1 h: the Edit button also lives in the notification panel after the popup is gone
choice=$(timeout 3600 notify-send -a Screenshot -i "$img" -t 0 -A edit=Edit "Screenshot copied" "Click Edit to draw, add text or crop" 2>/dev/null)
if [[ "$choice" == "edit" ]]; then
    out=(); [[ $tmp == 0 ]] && out=(-o "${img%.png}-edited.png")
    satty -f "$img" --copy-command wl-copy --early-exit copy --initial-tool arrow \
          --actions-on-enter save-to-clipboard --actions-on-escape exit "${out[@]}"
fi
[[ $tmp == 1 ]] && rm -f "$img"
exit 0
