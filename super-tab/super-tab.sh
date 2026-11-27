#!/usr/bin/env bash
# ALT+Tab like Windows: tap = jump to the previously used window (on any workspace), hold ALT and keep
# pressing Tab to go further back in most-recently-used window order (ALT+Shift+Tab goes forward again).
# Releasing ALT (see super-tab-release.sh) closes the overview on the selected workspace.
. "$HOME/.config/hypr/custom/ws-mru-lib.sh"
flag="$rt/super-tab-active"; list="$rt/super-tab-list"
if [ ! -e "$flag" ]; then
    cur=$(hyprctl activewindow -j | jq -r '.address // empty'); mru_push "$cur"; touch "$mru_file"
    # every normal window (all workspaces and monitors, no special/scratch ones), most recently used first: the
    # watcher's history, then windows it never saw (in Hyprland's focus order); the focused one always first
    hyprctl clients -j | jq -r --rawfile m "$mru_file" --arg c "$cur" '
        ($m | split("\n") | map(select(. != ""))) as $mru
        | [.[] | select(.mapped and .workspace.id > 0)] as $w
        | ([$w[] | .address] | map({key: ., value: true}) | from_entries) as $ok
        | ($mru | map(select($ok[.]))) as $known
        | ($known + ([$w[] | select(.address as $a | $known | index($a) | not)] | sort_by(.focusHistoryID) | map(.address)))
        | (map(select(. == $c)) + map(select(. != $c))) | .[]' >"$list"
    echo 0 >"$flag"; : >"$rt/super-tab-seen"
    hyprctl dispatch 'hl.dsp.submap("super-tab")' >/dev/null
fi
n=$(wc -l <"$list"); i=$(cat "$flag")
[ "$n" -gt 0 ] || { hyprctl layers | grep -q "quickshell:overview" || qs -c ii ipc call search open; exit 0; }
if [ "$1" = prev ]; then i=$(( (i - 1 + n) % n )); else i=$(( (i + 1) % n )); fi
echo "$i" >"$flag"; echo "$i" >>"$rt/super-tab-seen"  # seen: windows passed on the way (release fixes their order)
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
