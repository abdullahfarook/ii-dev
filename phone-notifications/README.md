# Phone notifications widget

Bar button (phone icon + notification count) and a left side panel with everything NectarLink's Notifications section does:

- live feed: app icon, app · sub · time, title, text, picture (click to enlarge), Live Updates (badge, progress, timer), grouping by app
  (`+N more` / `Show less` / `Clear N`), WhatsApp conversation replies shown under the card
- reply (inline box, Enter sends), the app's own buttons (`Mark as read`, `Interested`, ...), `Copy code` for one-time codes
- dismiss, `Clear all`, Undo bar, `ongoing` notifications can't be dismissed
- History (last 24 h, search, clear), per-app rules (Show / Quiet / Hidden, also from a card's `...`), phone name · battery · link status
- states: NectarLink not running (with a Start button), phone offline, no notifications

Needs NectarLink with the notifications API: see `../nectarlink-api/`. Panel behavior comes from `../widget-base/` (`WidgetBase.qml`).

| File | What |
|---|---|
| `PhoneNotifButton.qml` | Bar button on `WidgetBase`: icon, badge, right-click menu (Reconnect, history on/off); `count` feeds the bar slot |
| `PhoneNotifStore.qml` | No UI: feed (a long poll that returns the moment something changes), phone status, history, rules, actions, instant removal on dismiss |
| `PhoneNotifPanel.qml` | Panel content: header, Undo bar, feed list, history, rules, picture preview |
| `PhoneNotifCard.qml` / `PhoneNotifHistoryRow.qml` / `PhoneNotifRuleRow.qml` | List rows |
| `phone-notifications.sh` | Helper that talks to the API (`feed`, `history`, `rules`, `post`, `devices`, `start`) |
| `bar-slot.py` | Adds the bar slot (shown on hover, and always while there are notifications), the `phoneNotif` switch in Settings > Bar and the Config defaults |
| `test/` | Isolated GUI test, see below |

`./install.sh`, then restart the shell: `qs -c ii kill; nohup qs -c ii >/dev/null 2>&1 & disown`. Backups: `~/backups/phone-notifications/`.

## Testing without the live session

`test/run-cage.sh` runs the panel in `cage` (headless Wayland compositor, no layer shell, no real input) next to nothing else:
`./test/run-cage.sh` uses the real NectarLink API, `./test/run-cage.sh mock` uses `test/mock_api.py` (groups, a Live Update, a one-time code,
replies; every POST is recorded in `$TEST_DIR/posts.log`, nothing reaches a phone). `harness-shell.qml` exposes IPC (`qs -p <cfg> ipc call t ...`:
`state`, `replyTo`, `dismiss`, `action`, `more`, `clearGroup`, `clearAll`, `undo`, `view`, `search`, ...) that clicks the real buttons of the
real delegates; take pictures with `grim`. Use the Intel render node (`renderD128`; the NVIDIA one gives a 0x0 output).
`./test/run-cage.sh stop` ends it.
