# NectarLink with a notifications API

[NectarLink](https://github.com/thtbee/nectarlink) pairs the phone with the PC. Its local automation API has no way to read or answer
phone notifications, so this folder builds a patched copy that does. The widget in `../phone-notifications/` uses it.

- Fork: https://github.com/abdullahfarook/nectarlink, branch `feat/notifications-api` (based on `v0.1.5`, the version the phone is paired with).
- `notifications-api.patch` is the same change as a patch against `v0.1.5` (`git apply`).
- New module `desktop/app/src/notifications_api.rs`: `GET /v1/notifications` (live feed, groups, Live Updates, long poll with `since`/`wait`),
  `POST .../action` (reply and the app's own buttons), `dismiss`, `dismiss-group`, `clear`, `undo`, `toggle-group`, history (+ search, clear),
  per-app rules, `copy-code`, `open-app`. The rows come from the same builder as NectarLink's own feed. Documented in `docs/api.md` of the fork.
- The dismiss code moved from the Qt bridge into `notifications.rs`, so the window and the API share it. A request may now last up to 65 s
  (the feed waits for news); reading the request is still limited to 5 s.
- Tests: `cargo test -p nectarlink-desktop notifications` (needs Qt 6.12 + Rust).

## Install

```bash
./install.sh             # builds the fork (~4 min after the first build), installs ~/.local/share/nectarlink-patched/nectarlink-desktop,
                         # stops the running NectarLink, turns the local API on (localApiEnabled in desktop-settings.json)
./install.sh --no-build  # only install the last build
~/.config/hypr/custom/phone-notifications.sh start   # NectarLink in the tray, no window
```

It runs beside the stock AppImage (`~/Applications/Nectarlink.AppImage`); only one of them runs at a time (same data folder, same port).
The patched build does not update itself. Backups go to `~/backups/nectarlink/<timestamp>/`.
