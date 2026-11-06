import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Test harness (cage only): the panel in a plain window; IPC "clicks" the real buttons of the real delegates.
ShellRoot {
    FloatingWindow {
        id: win
        visible: true
        implicitWidth: 460; implicitHeight: 860
        color: Appearance.m3colors.m3surfaceContainer
        PhoneNotifStore { id: st; open: true }
        PhoneNotifPanel { id: pn; anchors.fill: parent; store: st }
        function card(i) { return pn.feedList.itemAtIndex(i) }
        IpcHandler {
            target: "t"
            function view(v: string): void { pn.view = v }
            function rulesFor(app: string, name: string): void { pn.rulesApp = app; pn.rulesAppName = name; pn.view = "rules" }
            function search(q: string): void { st.loadHistory(q) }
            function state(): string { return JSON.stringify({ view: pn.view, connected: st.connected, count: st.count, feed: st.feed.count, hist: st.history.count, rules: st.rulesApps.length, undo: st.undoLabel, titles: Array.from({ length: st.feed.count }, (_, i) => st.feed.get(i).title + "#" + st.feed.get(i).groupIndex), replying: Array.from({ length: st.feed.count }, (_, i) => win.card(i) ? win.card(i).replying : null) }) }
            function replyTo(i: int, text: string): void { const c = win.card(i); c.replyButton.clicked(); c.replyInput.text = text; c.replyInput.accepted() }
            function openReply(i: int): void { win.card(i).replyButton.clicked() }
            function dismiss(i: int): void { win.card(i).dismissButton.clicked() }
            function options(i: int): void { win.card(i).optionsButton.clicked() }
            function action(i: int, j: int): void { win.card(i).actionButtons.itemAt(j).clicked() }
            function more(i: int): void { win.card(i).moreButton.clicked() }
            function clearGroup(i: int): void { win.card(i).clearGroupButton.clicked() }
            function copyCode(i: int): void { win.card(i).copyCodeButton.clicked() }
            function clearAll(): void { pn.clearAllButton.clicked() }
            function undo(): void { pn.undoButton.clicked() }
            function clearHistory(): void { pn.clearHistoryButton.clicked() }
            function image(i: int): void { pn.lightbox = win.card(i).imageUrl }
            function setRule(app: string, rule: string): void { st.setRule(app, rule) }
            function lightboxState(): string { return pn.lightbox }
        }
    }
}
