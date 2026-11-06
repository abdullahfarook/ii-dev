# Phone notifications widget

Bar button (phone icon + notification count) and a left side panel in the shell's own style (like the Gist and Docker panels): header with
icon, title and subtitle (count · phone · battery), icon buttons (History, App rules, Open NectarLink, Clear all), a filter box, app chips
(All / WhatsApp · 2 / ...), the list, an Undo bar and a footer hint. History and App rules are views of the panel with a back button.
The **notification cards are NectarLink's own** (`nectar/`: its `NotificationItem` and `HistoryItem` QML with its theme, read from its API so the
wallpaper colors match), with all their functions:

- app icon, app · sub · time, title, text, picture (click to enlarge), Live Updates (badge, progress, timer), grouping by app
  (`+N more` / `Show less` / `Clear N`), the replies you sent under the card
- reply (inline box, Enter sends), the app's own buttons (`Mark as read`, `Interested`, ...), `Copy code` for one-time codes
- dismiss, `Clear all`, Undo, `ongoing` notifications can't be dismissed, the card's `...` opens that app's rule (Show / No pop-ups / Hide)
- click a card to open the phone app in a window (only when NectarLink says app windows work)
- states: NectarLink not running (with a Start button), phone offline, no notifications

Needs NectarLink with the notifications API: see `../nectarlink-api/`. Panel behavior comes from `../widget-base/` (`WidgetBase.qml`).

| File | What |
|---|---|
| `PhoneNotifButton.qml` | Bar button on `WidgetBase`: icon, badge, right-click menu (App rules, Open NectarLink, Reconnect, history on/off); `count` feeds the bar slot |
| `PhoneNotifStore.qml` | No UI: feed (a long poll that returns the moment something changes), NectarLink's theme, phone status, history, rules, the actions the cards call, instant removal on dismiss |
| `PhoneNotifPanel.qml` | Panel content in the shell's style: header, filter, chips, list of NectarLink's `NotificationItem` cards, History and App rules views, Undo bar, picture preview |
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
