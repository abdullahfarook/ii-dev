#!/usr/bin/env bash
# Keeps the SUPER+V clipboard / SUPER+. emoji overview open after releasing SUPER (idempotent).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
KEYBINDS="$HOME/.config/hypr/custom/keybinds.lua"
touch "$KEYBINDS"
python3 - "$KEYBINDS" "$REPO/clipboard-keybinds.lua" <<'PY'
import re, sys
target, snippet = sys.argv[1], open(sys.argv[2]).read().rstrip("\n")
s = open(target).read()
pattern = r"-- >>> clipboard-keep-open >>>.*?-- <<< clipboard-keep-open <<<"
if re.search(pattern, s, re.S):
    s = re.sub(pattern, lambda _: snippet, s, flags=re.S)
else:
    s = s.rstrip("\n") + "\n\n" + snippet + "\n"
open(target, "w").write(s)
PY
echo "Installed. Hyprland reloads automatically; if not: hyprctl reload"
