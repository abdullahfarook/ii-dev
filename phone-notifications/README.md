# Phone notifications widget

Bar button (phone icon + notification count) and a left side panel that **is** NectarLink's Notifications section: the same QML (`nectar/`, copied from the app) with the app's own theme (read from its API, so the wallpaper colors match), fonts, cards, sheets and spacing. It does everything the section does:

- live feed: app icon, app · sub · time, title, text, picture (click to enlarge), Live Updates (badge, progress, timer), grouping by app
  (`+N more` / `Show less` / `Clear N`), WhatsApp conversation replies shown under the card
- reply (inline box, Enter sends), the app's own buttons (`Mark as read`, `Interested`, ...), `Copy code` for one-time codes
- dismiss, `Clear all`, Undo bar, `ongoing` notifications can't be dismissed
- History sheet (last 24 h, search, clear), per-app options sheet from a card's `...` (Show / No pop-ups / Hide), all apps' rules (right-click menu > App rules), picture preview sheet, click a card to open the phone app in a window (when NectarLink says app windows work)
- states: NectarLink not running (with a Start button), phone offline, no notifications

Needs NectarLink with the notifications API: see `../nectarlink-api/`. Panel behavior comes from `../widget-base/` (`WidgetBase.qml`).

| File | What |
|---|---|
| `PhoneNotifButton.qml` | Bar button on `WidgetBase`: icon, badge, right-click menu (App rules, Open NectarLink, Reconnect, history on/off); `count` feeds the bar slot |
| `PhoneNotifStore.qml` | No UI: feed (a long poll that returns the moment something changes), NectarLink's theme, phone status, history, rules, the actions the cards call, instant removal on dismiss |
| `PhoneNotifPanel.qml` | Panel content drawn like the app's Home notifications card: header, Undo bar, list of `NotificationItem`, History / app options / rules / picture sheets |
| `nectar/` | NectarLink's own QML (Theme, Tokens, Icons, Txt, Button, IconButton, NotificationItem, HistoryItem, Sheet, Segmented, ...), see `nectar/README.md` for the few changes |
| `phone-notifications.sh` | Helper that talks to the API (`feed`, `history`, `rules`, `theme`, `post`, `devices`, `start`, `open`) |
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
