import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Phone notifications (NectarLink): bar button with the notification count + a side panel with everything NectarLink's
// Notifications section does: live feed with groups and Live Updates, reply / actions / Copy code, dismiss, Clear all with
// Undo, history with search, per-app rules. Talks to NectarLink's local API through phone-notifications.sh. Panel behavior
// (open/close, click-away, Esc, monitors) comes from WidgetBase; the panel content only exists while open, the feed
// (a long poll that returns the moment something changes) lives on the button so the badge is always right.

// State and talking to NectarLink for the phone notifications widget (no UI): the live feed (a long poll that returns the
// moment something changes), the phone's status, history, rules and the actions. Used by the bar button and the panel.
Item {
    id: root
    visible: false
    property bool open: false           // the panel is shown (set by the button)
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/custom/phone-notifications.sh"
    property bool connected: false      // NectarLink's API answers
    property bool phoneOnline: false
    property string phoneName: ""
    property int battery: -1
    property bool charging: false
    property int count: 0
    property string undoLabel: ""
    property bool historyEnabled: true
    property int rev: 0
    property int clock: 0               // ticks every minute while the panel is open (relative times)
    property var online: ({})
    property var rulesApps: []
    property int historyTotal: 0
    property string historyQuery: ""

    ListModel { id: feedModel }
    ListModel { id: historyModel }
    readonly property alias feed: feedModel
    readonly property alias history: historyModel

    function post(path, obj) {
        optimistic(path, obj || {});
        Quickshell.execDetached([helper, "post", path, JSON.stringify(obj || {})]);
    }
    // Rows go at once when dismissed; the next feed (a moment later) confirms or corrects it.
    function removeWhere(test) { for (let i = feedModel.count - 1; i >= 0; i--) if (test(feedModel.get(i))) feedModel.remove(i); }
    function optimistic(path, o) {
        if (path === "dismiss") removeWhere(r => r.key === o.key && !r.ongoing);
        else if (path === "dismiss-group") removeWhere(r => r.app === o.app && !r.ongoing);
        else if (path === "clear") removeWhere(r => !r.ongoing);
    }
    function copyCode(code) { post("copy-code", { "code": code }); }
    function startNectarLink() { Quickshell.execDetached([helper, "start"]); retry.interval = 1500; retry.restart(); }

    // ---- model sync (keeps delegates, scroll position and half-typed replies when the feed changes) ----
    function flat(it) {
        return {
            "uid": it.deviceId + "\u0001" + it.key, "deviceId": it.deviceId, "key": it.key, "app": it.app, "appName": it.appName,
            "title": it.title, "text": it.text, "sub": it.sub, "when": it.when, "iconUrl": it.iconUrl, "imageUrl": it.imageUrl,
            "actions": JSON.stringify(it.actions || []), "replyAction": it.replyAction, "replyLabel": it.replyLabel,
            "ongoing": it.ongoing, "replies": JSON.stringify(it.replies || []), "otpCode": it.otpCode,
            "live": it.live ? JSON.stringify(it.live) : "", "groupCount": it.groupCount, "groupIndex": it.groupIndex,
            "groupExpanded": it.groupExpanded, "groupSummary": it.groupSummary
        };
    }
    function syncModel(model, rows, keyOf) {
        for (let i = 0; i < rows.length; i++) {
            const k = keyOf(rows[i]);
            let j = -1;
            for (let n = i; n < model.count; n++) { if (keyOf(model.get(n)) === k) { j = n; break; } }
            if (j < 0) model.insert(i, rows[i]);
            else { if (j !== i) model.move(j, i, 1); model.set(i, rows[i]); }
        }
        if (model.count > rows.length) model.remove(rows.length, model.count - rows.length);
    }

    function applyFeed(j) {
        connected = true;
        rev = j.rev;
        count = j.count;
        undoLabel = j.undoLabel || "";
        historyEnabled = j.historyEnabled;
        online = j.online || ({});
        phoneOnline = Object.values(online).some(v => v);
        syncModel(feedModel, j.items.map(flat), r => r.uid);
    }
    function setOffline() {
        connected = false; phoneOnline = false; count = 0; undoLabel = ""; rev = 0;
        feedModel.clear();
    }

    // ---- the feed: a long poll, so changes show at once without busy polling ----
    property double _polled: 0
    function poll() {
        if (feedProc.running) return;
        _polled = Date.now();
        feedProc.command = [helper, "feed"].concat(rev > 0 ? [String(rev)] : []);
        feedProc.running = true;
    }
    Process {
        id: feedProc
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null;
                try { j = JSON.parse(text); } catch (e) { j = null; }
                if (j && j.ok) {
                    root.applyFeed(j);
                    // never spin: if the answer came back at once with the same revision, wait a little
                    retry.interval = Date.now() - root._polled < 300 ? 1000 : 10;
                } else {
                    root.setOffline();
                    retry.interval = 5000;
                }
                retry.restart();
            }
        }
        onExited: code => { if (code !== 0 && !retry.running) { retry.interval = 5000; retry.restart(); } }
    }
    Timer { id: retry; interval: 10; onTriggered: root.poll() }
    Component.onCompleted: { startupCheck.running = true; poll(); refreshPhone(); }
    Process { id: startupCheck; command: [root.helper, "start"] }   // NectarLink in the tray, no window, if it is not running

    // ---- phone status (battery, link) ----
    function refreshPhone() { if (!devProc.running) devProc.running = true; }
    Process {
        id: devProc
        command: [root.helper, "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (j.ok && j.devices.length > 0) {
                        const d = j.devices.find(x => x.online) || j.devices[0];
                        root.phoneName = d.name;
                        root.battery = d.battery ? d.battery.level : -1;
                        root.charging = d.battery ? d.battery.charging : false;
                    }
                } catch (e) {}
            }
        }
    }
    Timer { interval: 60000; repeat: true; running: root.connected; onTriggered: root.refreshPhone() }

    // ---- history and rules (fetched on demand) ----
    function loadHistory(q) {
        historyQuery = q || "";
        histProc.command = [helper, "history", historyQuery];
        histProc.running = true;
    }
    Process {
        id: histProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (!j.ok) return;
                    root.historyTotal = j.total;
                    root.syncModel(historyModel, j.items.map(h => ({
                        "uid": h.deviceId + "\u0001" + h.key + "\u0001" + h.removedAt, "deviceId": h.deviceId, "key": h.key, "app": h.app,
                        "appName": h.appName, "title": h.title, "text": h.text, "sub": h.sub, "when": h.when,
                        "removedAt": h.removedAt, "iconUrl": h.iconUrl
                    })), r => r.uid);
                } catch (e) {}
            }
        }
    }
    function loadRules() { rulesProc.running = true; }
    Process {
        id: rulesProc
        command: [root.helper, "rules"]
        stdout: StdioCollector {
            onStreamFinished: { try { const j = JSON.parse(text); if (j.ok) { root.rulesApps = j.apps; root.historyEnabled = j.historyEnabled; } } catch (e) {} }
        }
    }
    function setRule(app, rule) {
        post("rules", { "app": app, "rule": rule });
        rulesApps = rulesApps.map(a => a.app === app ? Object.assign({}, a, { "rule": rule }) : a);
    }
    function setHistoryEnabled(on) { post("rules", { "historyEnabled": on }); historyEnabled = on; }


    function onOpened() { clock++; refreshPhone(); poll(); }
}
