// Embedded Google (QtWebEngine) window docked under the Google widget popup. Run by gsearch.sh via `qml6` (no Python).
// Args after `--`: <bg> <scrollbar thumb> <thumb hover>. Commands arrive through $XDG_RUNTIME_DIR/gsearch-cmd ("<seq>\t<cmd>\t<arg>",
// polled); status lines go to stderr as "GS <line>" and gsearch.sh appends them to $XDG_RUNTIME_DIR/gsearch-status.
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtWebEngine

Window {
    id: win
    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string bg: args[0] ?? "#1f1f1f"
    readonly property string thumb: args[1] ?? "#6a6a6a"
    readonly property string thumbHover: args[2] ?? "#9a9a9a"
    readonly property string cmdFile: "file://" + Qt.application.arguments.filter(a => a.indexOf("cmdfile=") === 0)[0].slice(8)

    visible: true; width: 440; height: 800; title: "gsearch"; color: bg

    property string lastQ: ""      // "" = blank state
    property bool revealed: false
    property bool altDown: false
    property string lastSeq: ""

    function emit(m) { console.log("GS " + m) }
    function external(u) { Qt.openUrlExternally(u) }

    readonly property var tlds: ("com org net io dev edu gov co ai app me info biz tv us uk de fr in pk ca au nl ru jp cn br it es se no ch xyz online site tech "
        + "cloud wiki news store blog tk cc ly gg to fm gl ws is eu nz za ae sa tr kr id vn sg hk tw cz gr pt ie be at dk fi")
    readonly property var urlRe: new RegExp("^(?:(?:https?|file)://\\S+|(?:www\\.)?(?:[a-z0-9-]+\\.)+(?:" + tlds.split(" ").join("|")
        + ")(?::\\d+)?(?:[/?#]\\S*)?|localhost(?::\\d+)?(?:[/?#]\\S*)?|\\d{1,3}(?:\\.\\d{1,3}){3}(?::\\d+)?(?:[/?#]\\S*)?)$", "i")
    // Address-like input opens the site; anything else is a Google search
    function targetUrl(q) {
        q = q.trim()
        if (urlRe.test(q)) {
            if (/^[a-z]+:\/\//i.test(q)) return q
            return (/^(localhost|\d)/i.test(q) ? "http://" : "https://") + q
        }
        return "https://www.google.com/search?q=" + encodeURIComponent(q).replace(/%20/g, "+")
    }
    function goto(u) { lastQ = u; revealed = false; view.url = u }
    function show(q) {
        if (q === "") {
            if (lastQ !== "") { lastQ = ""; revealed = false; view.url = "about:blank" }
            return
        }
        if (q !== lastQ) { lastQ = q; view.url = targetUrl(q) }
        else if (!revealed) { revealed = true; emit("shown"); emit("done") }
    }
    property bool quitting: false
    function quit() { quitting = true; Qt.quit() }  // Qt.quit() closes the window first: onClosing must let it
    function run(c, a) {
        if (c === "hide") quit()
        else if (c === "back") view.goBack()
        else if (c === "forward") view.goForward()
        else if (c === "reload") view.reload()
        else if (c === "stop") view.stop()
        else if (c === "open") external(view.url)
        else if (c === "resume") { // kept page: map it again exactly as it was (no reload)
            win.visible = true
            repaint.count = 0; repaint.restart() // a remapped window shows black until something repaints it
            if (revealed) { emit("shown"); emit("done"); emit("url " + view.url.toString()); emit("nav " + (view.canGoBack ? 1 : 0) + " " + (view.canGoForward ? 1 : 0)) }
            else goto(a)
        }
        else if (c === "goto") { win.visible = true; goto(a) }  // reopened: map again (hidden by the panel closing)
        else { win.visible = true; show(a) }
    }

    Timer {
        id: repaint; interval: 60; repeat: true; property int count: 0
        onTriggered: {
            view.visible = false; view.visible = true
            view.runJavaScript("window.dispatchEvent(new Event('resize'));window.scrollBy(0,1);window.scrollBy(0,-1)")
            if (++count >= 4) stop()
        }
    }

    // Esc: the panel closes (and hides this window); quit only if no panel reacts
    Shortcut { sequence: "Esc"; onActivated: { if (win.visibility === Window.FullScreen) view.fullScreenCancelled(); else { win.emit("exit"); orphanQuit.start() } } }
    Timer { id: orphanQuit; interval: 2000; onTriggered: if (win.visible) win.quit() }

    // Close request: the panel closing (it shows a still of this window and slides out with it). Only unmap (no animation, see
    // google-search-rules.lua): a quick reopen shows the same page again; gsearch-close.sh quits the helper a moment later.
    onClosing: (close) => {
        if (quitting) return
        close.accepted = false
        if (win.visibility === Window.FullScreen) view.fullScreenCancelled()
        win.visible = false
    }

    WebEngineProfile {
        id: profile
        storageName: "gsearch"
        persistentStoragePath: Qt.application.arguments.filter(a => a.indexOf("data=") === 0)[0].slice(5)
        offTheRecord: false
    }

    WebEngineView {
        id: view
        profile: profile
        anchors { fill: parent; topMargin: 8 }  // top padding is hidden under the popup card
        backgroundColor: win.bg
        settings.playbackRequiresUserGesture: true
        settings.fullScreenSupportEnabled: true
        // Video fullscreen button: the whole window goes fullscreen (the popup hides its card meanwhile, see "fullscreen" status)
        onFullScreenRequested: (req) => {
            req.accept()
            win.visibility = req.toggleOn ? Window.FullScreen : Window.Windowed
            win.emit("fullscreen " + (req.toggleOn ? 1 : 0))
        }

        // Themed scrollbars: thin rounded thumb, transparent track
        userScripts.collection: [ {
            name: "scrollbar", injectionPoint: WebEngineScript.DocumentReady,
            worldId: WebEngineScript.MainWorld, runsOnSubFrames: true,
            sourceCode: "(function(){var s=document.createElement('style');s.textContent="
                + JSON.stringify("::-webkit-scrollbar{width:12px!important;height:12px!important;background:transparent!important}"
                + "::-webkit-scrollbar-track{background:transparent!important}::-webkit-scrollbar-corner{background:transparent!important}"
                + "::-webkit-scrollbar-thumb{background:" + win.thumb + "!important;border-radius:8px!important;border:3px solid transparent!important;background-clip:padding-box!important;min-height:40px}"
                + "::-webkit-scrollbar-thumb:hover{background:" + win.thumbHover + "!important;background-clip:padding-box!important}")
                + ";(document.head||document.documentElement).appendChild(s)})()"
        } ]

        // Ctrl/Alt+click on a link opens it in the default browser (Alt state sampled from pointer events: the window never has keyboard focus)
        TapHandler { acceptedButtons: Qt.AllButtons; gesturePolicy: TapHandler.WithinBounds; onPressedChanged: if (pressed) win.altDown = (point.modifiers & (Qt.ControlModifier | Qt.AltModifier)) !== 0 }
        onNavigationRequested: (req) => {
            if (req.navigationType === WebEngineNavigationRequest.LinkClickedNavigation && win.altDown) {
                req.action = WebEngineNavigationRequest.IgnoreRequest; win.external(req.url)
            }
        }
        // Native Chromium menu's Copy does nothing here (window has no keyboard focus): own menu, text goes to wl-copy
        onContextMenuRequested: (req) => {
            req.accepted = true
            win.ctxText = req.selectedText; win.ctxLink = req.linkUrl.toString()
            if (win.ctxText !== "" || win.ctxLink !== "") ctxMenu.popup()
        }
        onNewWindowRequested: (req) => { if (win.altDown) win.external(req.requestedUrl); else view.url = req.requestedUrl }  // target=_blank / window.open: same view unless Ctrl/Alt held

        onLoadingChanged: (r) => {
            if (!win.lastQ) return
            if (r.status === WebEngineLoadingInfo.LoadStartedStatus) win.emit("loading")
            else {
                if (!win.revealed) { win.revealed = true; win.emit("shown") }  // first results: window is mapped behind the card; reveal in place
                win.emit(r.status === WebEngineLoadingInfo.LoadSucceededStatus ? "done" : "failed")
            }
            win.emit("nav " + (view.canGoBack ? 1 : 0) + " " + (view.canGoForward ? 1 : 0))
        }
        onLoadProgressChanged: if (win.lastQ) {
            win.emit("progress " + loadProgress)
            // Google's load event can lag seconds behind 100% progress: reveal at 100% instead of waiting for it
            if (loadProgress >= 100 && !win.revealed) { win.revealed = true; win.emit("shown"); win.emit("done") }
        }
        onUrlChanged: if (win.lastQ && url.toString() !== "about:blank") {
            win.emit("url " + url.toString())  // the popup remembers the page (memory only) to restore it on reopen
            win.emit("nav " + (canGoBack ? 1 : 0) + " " + (canGoForward ? 1 : 0))
        }
    }

    property string ctxText: ""
    property string ctxLink: ""
    function copyText(t) { emit("copy " + encodeURIComponent(t)) }  // gsearch.sh pipes it to wl-copy (Qt clipboard writes fail without keyboard focus)
    Menu {
        id: ctxMenu
        MenuItem { text: "Copy"; enabled: win.ctxText !== ""; onTriggered: win.copyText(win.ctxText) }
        MenuItem { text: "Copy link address"; enabled: win.ctxLink !== ""; onTriggered: win.copyText(win.ctxLink) }
    }


    // Command channel: gsearch.sh atomically replaces the file; a new sequence number = a new command
    Timer {
        interval: 60; running: true; repeat: true
        onTriggered: {
            var x = new XMLHttpRequest()
            x.open("GET", win.cmdFile, false)
            var t = ""
            try { x.send(); t = x.responseText } catch (e) { return }
            var p = t.split("\t")
            if (p.length < 2 || p[0] === win.lastSeq) return
            win.lastSeq = p[0]
            win.run(p[1], p.slice(2).join("\t"))
        }
    }
}
