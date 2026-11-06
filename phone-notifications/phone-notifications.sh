#!/usr/bin/env bash
# Helper for the phone notifications widget: talks to NectarLink's local API (patched build, see nectarlink-api/).
# Usage:
#   phone-notifications.sh feed [SINCE]     live feed; with SINCE it waits (up to ~50 s) for news, so the widget updates at once
#   phone-notifications.sh history [QUERY]  dismissed notifications of the last 24 h (optionally filtered)
#   phone-notifications.sh rules            per-app rules and the history switch
#   phone-notifications.sh post PATH [JSON] POST to /v1/notifications/PATH
#   phone-notifications.sh devices          paired phones (battery, online)
#   phone-notifications.sh start            start NectarLink in the tray (no window) if it is not running
#   phone-notifications.sh copy TEXT        copy text to the clipboard
#   phone-notifications.sh open             show the NectarLink window on the current workspace (starts the app if needed)
# Prints JSON; when NectarLink or its API is down it prints {"ok":false,"error":"offline"} and exits 0.
set -u
DATA="${NECTARLINK_DATA:-$HOME/.local/share/Nectarlink}"
TOKEN_FILE="$DATA/api-token.json"
BIN_PATCHED="$HOME/.local/share/nectarlink-patched/nectarlink-desktop"
BIN_APPIMAGE="$HOME/Applications/Nectarlink.AppImage"

offline() { echo '{"ok":false,"error":"offline"}'; exit 0; }

api() { # METHOD PATH [BODY] [MAX_TIME]
  [ -r "$TOKEN_FILE" ] || offline
  local port token
  read -r port token < <(jq -r '"\(.port) \(.token)"' "$TOKEN_FILE" 2>/dev/null) || offline
  [ -n "$port" ] && [ -n "$token" ] || offline
  local args=(-s --max-time "${4:-10}" -X "$1" -H "Authorization: Bearer $token" "http://127.0.0.1:$port$2")
  if [ -n "${3:-}" ]; then args+=(-H "Content-Type: application/json" --data-binary "$3"); fi
  local out
  out=$(curl "${args[@]}") || offline
  [ -n "$out" ] || offline
  printf '%s\n' "$out"
}

enc() { jq -rn --arg v "$1" '$v|@uri'; }

case "${1:-}" in
  feed)
    if [ -n "${2:-}" ]; then api GET "/v1/notifications?since=$2&wait=50" "" 65; else api GET "/v1/notifications" "" 10; fi ;;
  history) api GET "/v1/notifications/history?q=$(enc "${2:-}")" ;;
  rules) api GET "/v1/notifications/rules" ;;
  devices) api GET "/v1/devices" ;;
  post) body="${3:-}"; [ -n "$body" ] || body="{}"; api POST "/v1/notifications/${2#/}" "$body" ;;
  copy) printf '%s' "${2:-}" | wl-copy ;;
  start)
    pgrep -x nectarlink-desk >/dev/null && exit 0
    pgrep -f 'Nectarlink.*AppImage' >/dev/null && exit 0
    if [ -x "$BIN_PATCHED" ]; then setsid nohup "$BIN_PATCHED" --minimized >/dev/null 2>&1 < /dev/null &
    elif [ -x "$BIN_APPIMAGE" ]; then setsid nohup "$BIN_APPIMAGE" --minimized >/dev/null 2>&1 < /dev/null &
    fi ;;
  open) # the window stays on the workspace it first opened on; bring it here (then raise it), or start the app
    pgrep -x nectarlink-desk >/dev/null || "$0" start-window
    for _ in $(seq 1 40); do
      addr=$(hyprctl clients -j | jq -r '[.[]|select(.class=="nectarlink-desktop")][0].address // empty')
      [ -n "$addr" ] && break; sleep 0.25
    done
    [ -n "${addr:-}" ] || exit 1
    ws=$(hyprctl activeworkspace -j | jq -r .id)
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ws\", window = \"address:$addr\", follow = false })" >/dev/null
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null ;;
  start-window) # like start, but with the window
    if [ -x "$BIN_PATCHED" ]; then setsid nohup "$BIN_PATCHED" >/dev/null 2>&1 < /dev/null &
    elif [ -x "$BIN_APPIMAGE" ]; then setsid nohup "$BIN_APPIMAGE" >/dev/null 2>&1 < /dev/null & fi ;;
  *) echo "usage: $0 feed|history|rules|devices|post|copy|start|open" >&2; exit 2 ;;
esac
