pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Состояние niri из `niri msg --json event-stream`
Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property var layoutNames: []
    property int layoutIdx: 0

    readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) ?? null
    readonly property var focusedWindow: Object.values(windows).find(w => w.is_focused) ?? null
    readonly property string layout: (layoutNames[layoutIdx] ?? "").slice(0, 2).toLowerCase()

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces.sort((a, b) => a.idx - b.idx);
        } else if (ev.WorkspaceActivated) {
            const { id, focused } = ev.WorkspaceActivated;
            const output = workspaces.find(w => w.id === id)?.output;
            workspaces = workspaces.map(w => Object.assign({}, w, {
                is_active: w.output === output ? w.id === id : w.is_active,
                is_focused: focused ? w.id === id : w.is_focused
            }));
        } else if (ev.WindowsChanged) {
            const map = {};
            for (const w of ev.WindowsChanged.windows) map[w.id] = w;
            windows = map;
        } else if (ev.WindowOpenedOrChanged) {
            const win = ev.WindowOpenedOrChanged.window;
            const map = Object.assign({}, windows);
            if (win.is_focused)
                for (const k in map) map[k] = Object.assign({}, map[k], { is_focused: false });
            map[win.id] = win;
            windows = map;
        } else if (ev.WindowClosed) {
            const map = Object.assign({}, windows);
            delete map[ev.WindowClosed.id];
            windows = map;
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            const map = {};
            for (const k in windows) map[k] = Object.assign({}, windows[k], { is_focused: windows[k].id === id });
            windows = map;
        } else if (ev.KeyboardLayoutsChanged) {
            layoutNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
            layoutIdx = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIdx = ev.KeyboardLayoutSwitched.idx;
        }
    }

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try { root.handle(JSON.parse(line)); } catch (e) { console.warn("niri:", e); }
            }
        }
        onExited: restart.start()
    }

    // если niri перезапустился или поток оборвался — переподключаемся
    Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = true
    }
}
