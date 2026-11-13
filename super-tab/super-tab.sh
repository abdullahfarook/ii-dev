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
pins="$rt/super-tab-pinned"; touch "$pins"
cmds=()  # all changes go out in ONE hyprctl --batch call, so they land in one frame (no stepwise jerking)
while read -r a; do cmds+=("dispatch hl.dsp.window.pin({ action = 'disable', window = 'address:$a' })"); done <"$pins"; : >"$pins"
if [[ $t == 0x* ]]; then  # a window of a float-mode workspace: focus it and bring it to the front
    cl=$(hyprctl clients -j)
    ws=$(echo "$cl" | jq -r --arg a "$t" '.[] | select(.address == $a) | .workspace.id')
    # Hyprland draws a fullscreen window above all others, except pinned windows. So if a sibling is fullscreen, pin
    # the chosen window (it shows over it, the fullscreen app stays fullscreen).
    if echo "$cl" | jq -e --arg a "$t" --argjson w "$ws" 'any(.[]; .mapped and .workspace.id == $w and .address != $a and .fullscreen > 0)' >/dev/null; then
        cmds+=("dispatch hl.dsp.window.pin({ action = 'enable', window = 'address:$t' })")
        echo "$t" >"$pins"
    fi
    # going back to the fullscreen app: apps that were shown over it keep an "allowed over fullscreen" flag, so they would
    # stay visible. Toggling fullscreen off and on again (same batch, so no visible flicker) clears the flag.
    m=$(echo "$cl" | jq -r --arg a "$t" --argjson w "$ws" '(.[] | select(.address == $a) | .fullscreen) as $f
        | if $f > 0 and any(.[]; .workspace.id == $w and .address != $a and .allowedOverFullscreen) then $f else 0 end')
    if [ "${m:-0}" -gt 0 ]; then
        cmds+=("dispatch hl.dsp.window.fullscreen({ mode = $m, window = 'address:$t' })" "dispatch hl.dsp.window.fullscreen({ mode = $m, window = 'address:$t' })")
    fi
    cmds+=("dispatch hl.dsp.focus({ window = \"address:$t\" })" "dispatch hl.dsp.window.alter_zorder({ mode = 'top', window = 'address:$t' })")
else
    cmds+=("dispatch hl.dsp.focus({ workspace = \"$t\" })")
fi
hyprctl --batch "$(printf '%s ; ' "${cmds[@]}")" >/dev/null
hyprctl layers | grep -q "quickshell:overview" || qs -c ii ipc call search open
