import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Whole-workspace float toggle (SUPER+ALT+G), like SUPER+ALT+Space but for every window of the focused workspace.
// On: floats all windows already there, and every window that opens there later. Off: tiles them all again.
// The set of workspaces in float mode lives in memory only (a shell restart clears it).
// Idle between events: reacts to the shortcut and Hyprland's openwindow only.
Scope {
    id: root
    property var floating: ({})   // workspace name -> true
    property string pendingId: ""
    property bool pendingOn: false

    function setFloat(address, on) {
        Hyprland.dispatch("hl.dsp.window.float({ action = '" + (on ? "enable" : "disable") + "', window = 'address:" + address + "' })");
    }

    GlobalShortcut {
        appid: "floatws"
        name: "toggle"
        description: "Float or tile every window of the focused workspace, now and later"
        onPressed: {
            const ws = Hyprland.focusedWorkspace;
            if (!ws) return;
            const f = Object.assign({}, root.floating);
            if (f[ws.name]) delete f[ws.name]; else f[ws.name] = true;
            root.floating = f;
            root.pendingOn = !!f[ws.name];
            root.pendingId = String(ws.id);
            // ids of float-mode workspaces, read by super-tab.sh (ALT+Tab cycles windows there)
            const ids = Object.keys(f).map(n => Hyprland.workspaces.values.find(w => w.name === n)).filter(w => w).map(w => w.id);
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$@\" > \"${XDG_RUNTIME_DIR:-/tmp}/float-workspaces\"", "sh"].concat(ids));
            console.log("floatws: workspace", ws.name, root.pendingOn ? "on" : "off");
            clients.running = true;   // apply to the windows already there
            Quickshell.execDetached(["notify-send", "-a", "Hyprland", "-t", "1500",
                "Float mode " + (root.pendingOn ? "on" : "off"), "Workspace " + ws.name]);
        }
    }

    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    JSON.parse(text).filter(c => c.mapped && String(c.workspace.id) === root.pendingId
                                                 && c.floating !== root.pendingOn)
                        .forEach(c => root.setFloat(c.address, root.pendingOn));
                } catch (e) { console.log("floatws: error", e); }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "openwindow") return;
            try {
                const p = ev.data.split(",");          // address,workspace,class,title
                if (!root.floating[p[1]]) return;
                console.log("floatws: float", p[0], "on", p[1]);
                root.setFloat("0x" + p[0], true);
            } catch (e) { console.log("floatws: error", e); }
        }
    }
}
