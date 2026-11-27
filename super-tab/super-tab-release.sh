#!/usr/bin/env bash
# On ALT release after a ALT+Tab session: close the overview, keeping the selected window.
. "$HOME/.config/hypr/custom/ws-mru-lib.sh"
flag="$rt/super-tab-active"
[ -e "$flag" ] || exit 0
rm -f "$flag"
mru_push "$(hyprctl activewindow -j | jq -r '.address // empty')"
hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
sleep 0.15  # let the shell's own release handler run first
qs -c ii ipc call search close
