# Ported from NectarLink's desktop app

`Theme`, `Tokens`, `Icons`, `Txt`, `Button`, `IconButton`, `Icon`, `Avatar`, `RoundedImage`, `Divider`, `Spinner`, `Sheet`, `Segmented`,
`NotificationItem` and `HistoryItem` are copied from `desktop/app/qml/` of https://github.com/thtbee/nectarlink (v0.1.5, GPL-3.0-or-later),
so the widget draws the notification section exactly like the app. Changes, kept small so a newer version can be diffed in:

- `import app.nectarlink` removed (the Rust singletons do not exist here);
- `Theme.qml`: `Preferences`/`AppController`/`MediaList` replaced by `cfg`, filled from NectarLink's `GET /v1/theme` through `Theme.apply()`;
- `NotificationItem.qml`: `NotificationList.x()` calls go to `item.list.x()` (the store); `replyInput` alias for the test harness; tighter padding for the narrow panel (card padding 12 -> 6, icon and text 12 -> 6 px from the top, right margin 84 -> 72, the `...` and dismiss buttons 8 -> 3 px from the top).

`fonts/Figtree.ttf` is the app's UI font (SIL OFL 1.1, see `fonts/OFL-Figtree.txt`).
