import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "nectar"

// Test harness (cage only): the panel in a plain window; IPC "clicks" the real buttons of the real NectarLink components.
ShellRoot {
    FloatingWindow {
        id: win
        visible: true
        implicitWidth: 460; implicitHeight: 860
        color: "#101418"
        PhoneNotifStore { id: st; open: true }
        PhoneNotifPanel { id: pn; anchors.fill: parent; store: st }
        function card(i) { return pn.feedList.itemAtIndex(i) }
        function find(item, pred) {
            if (pred(item)) return item
            for (const c of item.children) { const r = find(c, pred); if (r) return r }
            return null
        }
        function click(root, pred) { const b = find(root, pred); if (!b) return false; b.clicked(); return true }
        IpcHandler {
            target: "t"
            function state(): string {
                return JSON.stringify({ connected: st.connected, count: st.count, feed: st.feed.count, hist: st.history.count, histCount: st.historyCount, undo: st.undoLabel,
                    dark: Theme.dark, seed: Theme.seed, primary: "" + Theme.primary, surface: "" + Theme.surface, card: "" + Theme.cardColor,
                    sheets: { history: pn.historySheet.opened, app: pn.appSheet.opened, rules: pn.rulesSheet.opened, preview: pn.previewSheet.opened },
                    titles: Array.from({ length: st.feed.count }, (_, i) => st.feed.get(i).title + "#" + st.feed.get(i).groupIndex),
                    replying: Array.from({ length: st.feed.count }, (_, i) => win.card(i) ? win.card(i).replying : null) })
            }
            function dbg(i: int): string {
                const c = win.card(i); const fl = win.find(c, it => it.flow !== undefined)
                return JSON.stringify({ h: c.height, ih: c.implicitHeight, w: c.width, flow: fl ? { w: fl.width, h: fl.height, ih: fl.implicitHeight, vis: fl.visible, n: fl.children.length } : null })
            }
            function button(i: int, label: string): bool { return win.click(win.card(i), it => it.text === label && typeof it.clicked === "function") }
            function icon(i: int, labelStart: string): bool { return win.click(win.card(i), it => typeof it.label === "string" && it.label.indexOf(labelStart) === 0 && typeof it.clicked === "function") }
            function replyTo(i: int, text: string): void { win.card(i).replying = true; win.card(i).replyInput.text = text; win.card(i).send() }
            function openReply(i: int): void { win.click(win.card(i), it => it.text === "Reply" && typeof it.clicked === "function") }
            function image(i: int): void { win.card(i).imageClicked(win.card(i).imageUrl) }
            function clearAll(): void { pn.clearAllButton.clicked() }
            function undo(): void { pn.undoButton.clicked() }
            function history(): void { pn.historyButton.clicked() }
            function search(q: string): void { pn.historySearch.text = q }
            function rules(): void { pn.openRules() }
            function pick(sheet: string, value: string): bool {
                const s = sheet === "app" ? pn.appSheet : pn.rulesSheet
                const seg = win.find(s, it => it.options !== undefined && typeof it.picked === "function")
                if (!seg) return false
                seg.picked(value); return true
            }
            function closeSheets(): void { pn.historySheet.close(); pn.appSheet.close(); pn.rulesSheet.close(); pn.previewSheet.close() }
        }
    }
}
