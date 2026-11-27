#!/usr/bin/env bash
# Tracks window focus history for ALT+Tab (Windows-style most-recently-used order).
# A window only counts once it stayed focused for 0.3s: Hyprland briefly focuses a workspace's last window when you jump
# to another window there, and those flashes must not count. Focus changes during an ALT+Tab session are ignored too;
# the release script records the chosen window.
exec 9>"$XDG_RUNTIME_DIR/ws-mru-watch.lock"; flock -n 9 || exit 0  # single instance
. "$HOME/.config/hypr/custom/ws-mru-lib.sh"
mru_push "$(hyprctl activewindow -j | jq -r '.address // empty')"
sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
pending=
socat -u "UNIX-CONNECT:$sock" - | while :; do
    if [ -n "$pending" ]; then
        IFS= read -r -t 0.3 line; rc=$?
        if [ $rc -gt 128 ]; then  # no event for 0.3s: the pending window stuck
            [ -e "$rt/super-tab-active" ] || mru_push "$pending"; pending=; continue
        fi
        [ $rc -eq 0 ] || break
    else
        IFS= read -r line || break
    fi
    case "$line" in activewindowv2\>\>*) a=${line#activewindowv2>>}; a=${a#0x}; pending=${a:+0x$a} ;; esac
done
