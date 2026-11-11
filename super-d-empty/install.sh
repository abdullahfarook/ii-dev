#!/usr/bin/env bash
# SUPER+D jumps to the next empty workspace when the current one has windows (idempotent).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
KEYBINDS="$HOME/.config/hypr/custom/keybinds.lua"
BACKUP="$HOME/backups/super-d-empty/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"; cp "$KEYBINDS" "$BACKUP/"
python3 - "$KEYBINDS" "$REPO/super-d-empty.lua" <<'PY'
import re, sys
target, snippet = sys.argv[1], open(sys.argv[2]).read().rstrip("\n")
s = open(target).read()
pat = r"-- >>> super-d-empty >>>.*?-- <<< super-d-empty <<<"
s = re.sub(pat, lambda _: snippet, s, flags=re.S) if re.search(pat, s, re.S) else s.rstrip("\n") + "\n\n" + snippet + "\n"
open(target, "w").write(s)
PY
echo "Done."
