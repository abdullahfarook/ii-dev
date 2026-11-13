#!/usr/bin/env bash
# ALT+Tab like Windows, on workspaces: tap = jump to the previously used workspace, hold ALT and keep
# pressing Tab to go further back in most-recently-used order (ALT+Shift+Tab goes forward again).
# Releasing ALT (see super-tab-release.sh) closes the overview on the selected workspace.
. "$HOME/.config/hypr/custom/ws-mru-lib.sh"
flag="$rt/super-tab-active"; list="$rt/super-tab-list"
if [ ! -e "$flag" ]; then
    mru_push "$(hyprctl activeworkspace -j | jq -r .id)"
    mon=$(hyprctl activeworkspace -j | jq -r .monitor)  # only cycle workspaces of the focused monitor
    existing=$(hyprctl workspaces -j | jq -r --arg m "$mon" '.[] | select(.id > 0 and .monitor == $m) | .id')
    # float-mode workspaces (shell-extras FloatWorkspace) are expanded: each of their windows is its own step,
    # most recently focused first; other workspaces stay one step each, in the same MRU order as before
    clients=$(hyprctl clients -j)
    grep -Fx -f <(echo "$existing") "$mru_file" | while read -r ws; do
        if grep -Fxq "$ws" "$rt/float-workspaces" 2>/dev/null; then
            echo "$clients" | jq -r --argjson w "$ws" '[.[] | select(.mapped and .workspace.id == $w)] | sort_by(.focusHistoryID) | .[].address'
        else
            echo "$ws"
        fi
    done >"$list"
    echo 0 >"$flag"
    hyprctl dispatch 'hl.dsp.submap("super-tab")' >/dev/null
fi
n=$(wc -l <"$list"); i=$(cat "$flag")
if [ "$1" = prev ]; then i=$(( (i - 1 + n) % n )); else i=$(( (i + 1) % n )); fi
echo "$i" >"$flag"
t=$(sed -n "$((i + 1))p" "$list")
if [[ $t == 0x* ]]; then  # a window of a float-mode workspace: focus it and bring it to the front
    # Hyprland draws a fullscreen window above all others, except pinned windows. So if a sibling is fullscreen, pin
    # the chosen window (it shows over it, the fullscreen app stays fullscreen); pins of earlier steps are removed first.
    pins="$rt/super-tab-pinned"; touch "$pins"
    unpin_all() { while read -r a; do hyprctl dispatch "hl.dsp.window.pin({ action = 'disable', window = 'address:$a' })" >/dev/null; done <"$pins"; : >"$pins"; }
    unpin_all
    cl=$(hyprctl clients -j)
    ws=$(echo "$cl" | jq -r --arg a "$t" '.[] | select(.address == $a) | .workspace.id')
    if echo "$cl" | jq -e --arg a "$t" --argjson w "$ws" 'any(.[]; .mapped and .workspace.id == $w and .address != $a and .fullscreen > 0)' >/dev/null; then
        hyprctl dispatch "hl.dsp.window.pin({ action = 'enable', window = 'address:$t' })" >/dev/null
        echo "$t" >"$pins"
    fi
    # going back to the fullscreen app: apps shown over it keep an "allowed over fullscreen" flag, so they would stay
    # visible. Toggling fullscreen off and on again clears the flag (and brings the app back on top).
    m=$(echo "$cl" | jq -r --arg a "$t" '.[] | select(.address == $a) | .fullscreen')
    if [ "${m:-0}" -gt 0 ]; then
        for _ in 1 2; do hyprctl dispatch "hl.dsp.window.fullscreen({ mode = $m, window = 'address:$t' })" >/dev/null; done
    fi
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$t\" })" >/dev/null
    hyprctl dispatch "hl.dsp.window.alter_zorder({ mode = 'top', window = 'address:$t' })" >/dev/null
else
    touch "$rt/super-tab-pinned"
    while read -r a; do hyprctl dispatch "hl.dsp.window.pin({ action = 'disable', window = 'address:$a' })" >/dev/null; done <"$rt/super-tab-pinned"; : >"$rt/super-tab-pinned"
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$t\" })" >/dev/null
fi
hyprctl layers | grep -q "quickshell:overview" || qs -c ii ipc call search open
