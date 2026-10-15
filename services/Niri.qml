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
    property bool overview: false

    readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) ?? null
    readonly property var focusedWindow: Object.values(windows).find(w => w.is_focused) ?? null
    readonly property string layout: (layoutNames[layoutIdx] ?? "").slice(0, 2).toLowerCase()
    readonly property bool urgent: workspaces.some(w => w.is_urgent) || Object.values(windows).some(w => w.is_urgent)

    function windowsOn(wsId) {
        return Object.values(windows).filter(w => w.workspace_id === wsId);
    }

    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    // номер стола относится к монитору, поэтому сначала фокусируем монитор
    function focusWorkspace(ws) {
        Quickshell.execDetached(["sh", "-c", 'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"',
            "sh", ws.output, String(ws.idx)]);
    }

    function handle(ev) {
        if (ev.OverviewOpenedOrClosed) {
            overview = ev.OverviewOpenedOrClosed.is_open;
        } else if (ev.WorkspaceUrgencyChanged) {
            const { id, urgent } = ev.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(w => w.id === id ? Object.assign({}, w, { is_urgent: urgent }) : w);
        } else if (ev.WindowUrgencyChanged) {
            const { id, urgent } = ev.WindowUrgencyChanged;
            if (windows[id]) windows = Object.assign({}, windows, { [id]: Object.assign({}, windows[id], { is_urgent: urgent }) });
        } else if (ev.WorkspacesChanged) {
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
