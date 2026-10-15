pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Загрузка CPU и памяти из /proc
Singleton {
    id: root

    property int cpu: 0          // %
    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property string user: Quickshell.env("USER") ?? "user"
    property string host: hostFile.text().trim()

    property var _prev: null

    FileView {
        id: hostFile
        path: "/etc/hostname"
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._prev) {
                const dt = total - root._prev.total;
                if (dt > 0)
                    root.cpu = Math.round(100 * (1 - (idle - root._prev.idle) / dt));
            }
            root._prev = { idle, total };
        }
    }

    FileView {
        id: mem
        path: "/proc/meminfo"
        onLoaded: {
            const get = key => Number(text().match(new RegExp(key + ":\\s+(\\d+)"))[1]);
            const total = get("MemTotal"), avail = get("MemAvailable");
            root.memTotal = total / 1048576;
            root.memUsed = (total - avail) / 1048576;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { stat.reload(); mem.reload(); }
    }
}
