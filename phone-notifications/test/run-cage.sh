#!/usr/bin/env bash
# Isolated GUI test of the panel in `cage` (a headless Wayland kiosk compositor): never touches the live Hyprland session,
# its seat or its input. The panel runs in a plain window (harness-shell.qml) against either the real NectarLink API
# (default) or the mock (./run-cage.sh mock). Drive it with IPC and look with grim:
#   XDG_RUNTIME_DIR=/run/user/1000/qtcage WAYLAND_DISPLAY=wayland-0 qs -p "$W/qscfg" ipc call t state
#   XDG_RUNTIME_DIR=/run/user/1000/qtcage WAYLAND_DISPLAY=wayland-0 grim shot.png
# Stop: ./run-cage.sh stop
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; W="${TEST_DIR:-${TMPDIR:-/tmp}/phone-notif-test}"
export XDG_RUNTIME_DIR=/run/user/1000/qtcage; mkdir -p "$XDG_RUNTIME_DIR" "$W"; chmod 700 "$XDG_RUNTIME_DIR"
if [ "${1:-}" = stop ]; then pkill -f "cage -- qs -p $W/qscfg" || true; pkill -f "mock_ap[i].py" || true; exit 0; fi
C="$W/qscfg"; rm -rf "$C"; mkdir -p "$C"
for e in "$HOME"/.config/quickshell/ii/*; do n=$(basename "$e"); [ "$n" = shell.qml ] || ln -s "$e" "$C/$n"; done
for f in PhoneNotifStore PhoneNotifPanel PhoneNotifCard PhoneNotifHistoryRow PhoneNotifRuleRow; do cp "$HERE/../$f.qml" "$C/$f.qml"; done
cp "$HERE/harness-shell.qml" "$C/shell.qml"
ENVV=()
if [ "${1:-}" = mock ]; then
  mkdir -p "$W/mock"; printf '{"port":53399,"token":"%s"}\n' "$(printf 'a%.0s' {1..64})" > "$W/mock/api-token.json"
  : > "$W/posts.log"; setsid nohup python3 -I "$HERE/mock_api.py" "$W/posts.log" >/dev/null 2>&1 < /dev/null &
  ENVV=(NECTARLINK_DATA="$W/mock")
fi
rm -f "$XDG_RUNTIME_DIR"/wayland-0*
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY "${ENVV[@]}" \
  WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 WLR_RENDER_DRM_DEVICE="${WLR_RENDER_DRM_DEVICE:-/dev/dri/renderD128}" \
  setsid nohup cage -- qs -p "$C" > "$W/cage.log" 2>&1 < /dev/null &
echo "started; config $C, log $W/cage.log (renderD128 is the Intel iGPU on this laptop; renderD129 is NVIDIA and gives a 0x0 output)"
