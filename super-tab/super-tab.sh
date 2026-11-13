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
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$t\" })" >/dev/null
    hyprctl dispatch "hl.dsp.window.alter_zorder({ mode = 'top', window = 'address:$t' })" >/dev/null
else
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$t\" })" >/dev/null
fi
hyprctl layers | grep -q "quickshell:overview" || qs -c ii ipc call search open
