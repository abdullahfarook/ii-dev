# Shared helpers for ALT+Tab window MRU (most recently used first, one window address per line).
rt=${XDG_RUNTIME_DIR:-/tmp}
mru_file="$rt/win-mru"
mru_push() {  # move window address $1 to the front
    [[ ${1:-} == 0x* ]] || return 0
    { echo "$1"; grep -vx "$1" "$mru_file" 2>/dev/null; } | head -n 200 >"$mru_file.tmp" && mv "$mru_file.tmp" "$mru_file"
}
