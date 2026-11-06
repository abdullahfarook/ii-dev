#!/usr/bin/env bash
# Runs Teams for Linux and restarts it (and re-docks the panel window) if it crashes (non-zero exit / killed by a signal).
# A clean quit (tray -> Quit, exit 0) ends the watchdog. Gives up after 5 crashes within 2 minutes.
# EVERY launcher (autostart, .desktop, bar button, tray click) must go through this script: when a watchdog is already running, this
# invocation just starts Teams as a 2nd instance (shows/focuses the window) and returns; otherwise it becomes the watchdog, so a Teams
# started by hand is supervised too (an unsupervised one that crashed was never restarted).
T=${TEAMS_BIN:-/opt/teams-for-linux/teams-for-linux}
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/teams-watchdog.lock"
flock -n 9 || exec "$T" --ozone-platform=x11 "$@" >/dev/null 2>&1 9>&-
crashes=0; first=$(date +%s)
while true; do
    if pgrep -x "${T##*/}" >/dev/null; then   # one is already running (started outside us): adopt it, restart it when it dies
        while pgrep -x "${T##*/}" >/dev/null; do sleep 5; done
        sleep 3; continue
    fi
    "$T" --ozone-platform=x11 >/dev/null 2>&1 9>&- &
    pid=$!
    ~/.config/hypr/custom/teams-panel.sh dock >/dev/null 2>&1 9>&- &
    wait "$pid"; rc=$?
    [ $rc -eq 0 ] && exit 0
    now=$(date +%s); [ $((now - first)) -gt 120 ] && { crashes=0; first=$now; }
    crashes=$((crashes + 1)); [ $crashes -ge 5 ] && exit 1
    sleep 3
done
