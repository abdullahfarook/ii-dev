#!/usr/bin/env bash
# After a left-click snip (copy), show a toast with an "Edit" button that opens Satty. Patches upstream ScreenshotAction.qml (idempotent).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
F="$HOME/.config/quickshell/ii/modules/common/utils/ScreenshotAction.qml"
B="$HOME/backups/snip-edit/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$B"; cp "$F" "$B/"
command -v satty >/dev/null || pkexec pacman -S --noconfirm satty
install -Dm755 "$REPO/snip-edit.sh" "$HOME/.config/hypr/custom/snip-edit.sh"
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
if "snip-edit.sh" in s: sys.exit(0)
a = s.index("            case ScreenshotAction.Action.Copy:")
b = s.index("            case ScreenshotAction.Action.Edit:")
new = '''            case ScreenshotAction.Action.Copy: {
                // snip-edit: keep the crop in a file, copy it, then toast with an Edit button (Satty)
                const dir = saveDir !== "" ? saveDir : (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp")
                return [
                    "bash", "-c",
                    `mkdir -p '${StringUtils.shellSingleQuoteEscape(dir)}' && \\
                    f='${StringUtils.shellSingleQuoteEscape(dir)}'/screenshot-$(date '+%Y-%m-%d_%H.%M.%S').png && \\
                    ${cropToStdout} > "$f" && wl-copy < "$f" && ${cleanup} && \\
                    setsid -f ~/.config/hypr/custom/snip-edit.sh "$f" >/dev/null 2>&1`
                ]
            }
'''
open(p, "w").write(s[:a] + new + s[b:])
PY
echo "Done. Restart shell: qs -c ii kill; nohup qs -c ii >/dev/null 2>&1 & disown"
