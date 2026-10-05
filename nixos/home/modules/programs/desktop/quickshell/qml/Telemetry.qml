import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: hw

    property bool running: false
    property int interval: 1000
    property var info: ({})
    property real cpu: 0
    property var loads: []
    property var clocks: []
    property real clock: 0
    property real temp: 0
    property real fan: 0
    property real gpu: 0
    property real gpuClock: 0
    property real mem: 0
    property real memUsed: 0
    property real memCached: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real diskRead: 0
    property real diskWrite: 0
    property real diskTemp: 0
    property real rx: 0
    property real tx: 0
    property var tunnels: []
    property real watts: 0
    property real battery: -1
    property bool charging: false
    property bool plugged: true
    property real uptime: 0
    property var load: [0, 0, 0]
    property int tasks: 0

    property var prev: ({})

    readonly property bool probed: info.model !== undefined
    readonly property var threads: info.threads ?? []
    readonly property string vendor: String(info.vendor ?? "").includes("AMD") ? "amd" : "intel"
    readonly property string gpuKind: String(info.gpu ?? "").split(" ")[0]
    readonly property string gpuPath: String(info.gpu ?? "").split(" ").slice(1).join(" ")
    readonly property string gpuClockKind: String(info.gpuClock ?? "").split(" ")[0]
    readonly property string gpuClockPath: String(info.gpuClock ?? "").split(" ").slice(1).join(" ")

    function delta(key: string, values: var): var {
        const now = Date.now();
        const last = prev[key];
        prev[key] = {
            values: values,
            at: now
        };
        if (!last || now <= last.at)
            return null;
        return {
            values: values.map((value, i) => value - last.values[i]),
            seconds: (now - last.at) / 1000
        };
    }

    function value(file: var): real {
        return Number(file.text().trim());
    }

    function poll(): void {
        statFile.reload();
        memFile.reload();
        loadFile.reload();
        netFile.reload();
        infoFile.reload();
        uptimeFile.reload();
        diskFile.reload();
        for (const file of [tempFile, fanFile, gpuFile, gpuClockFile, diskTempFile, capacityFile, statusFile, powerFile, plugFile])
            if (file.path !== "")
                file.reload();
    }

    Process {
        running: true
        command: [Sys.hwProbe]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    hw.info = JSON.parse(this.text);
                } catch (error) {
                    hw.info = {};
                }
            }
        }
    }

    Timer {
        interval: hw.interval
        repeat: true
        running: hw.running && hw.probed
        triggeredOnStart: true
        onTriggered: hw.poll()
    }

    FileView {
        id: statFile

        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const rows = text().split("\n").filter(line => line.startsWith("cpu"));
            const busy = [];
            for (const row of rows) {
                const fields = row.trim().split(/\s+/);
                const numbers = fields.slice(1, 9).map(Number);
                const total = numbers.reduce((sum, value) => sum + value, 0);
                const step = hw.delta(fields[0], [numbers[3] + numbers[4], total]);
                busy.push(step && step.values[1] > 0 ? 100 * (1 - step.values[0] / step.values[1]) : 0);
            }
            hw.cpu = busy[0] ?? 0;
            hw.loads = busy.slice(1);
            const match = /procs_running\s+(\d+)/.exec(text());
            hw.tasks = match ? Number(match[1]) : 0;
        }
    }

    FileView {
        id: infoFile

        path: "/proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const clocks = [];
            const pattern = /^cpu MHz\s*:\s*([\d.]+)/gm;
            const body = text();
            let match;
            while ((match = pattern.exec(body)) !== null)
                clocks.push(Number(match[1]));
            hw.clocks = clocks;
            hw.clock = clocks.length > 0 ? clocks.reduce((sum, value) => sum + value, 0) / clocks.length : 0;
        }
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const field = name => Number((new RegExp("^" + name + ":\\s+(\\d+)", "m").exec(text()) ?? [0, 0])[1]) / 1048576;
            const total = field("MemTotal");
            if (total <= 0)
                return;
            hw.memTotal = total;
            hw.memUsed = total - field("MemAvailable");
            hw.memCached = field("Cached") + field("Buffers");
            hw.swapUsed = field("SwapTotal") - field("SwapFree");
            hw.mem = 100 * hw.memUsed / total;
        }
    }

    FileView {
        id: loadFile

        path: "/proc/loadavg"
        printErrors: false
        onLoaded: hw.load = text().trim().split(/\s+/).slice(0, 3).map(Number)
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false
        onLoaded: hw.uptime = Number(text().trim().split(/\s+/)[0])
    }

    FileView {
        id: netFile

        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            let rx = 0;
            let tx = 0;
            const tunnels = [];
            for (const line of text().split("\n").slice(2)) {
                const colon = line.indexOf(":");
                if (colon < 0)
                    continue;
                const name = line.slice(0, colon).trim();
                if (name === "lo" || /^(br-|veth|docker|virbr)/.test(name))
                    continue;
                if (/^(tun|tap|ppp|wt)\d+$|^wg/.test(name)) {
                    tunnels.push(name);
                    continue;
                }
                const fields = line.slice(colon + 1).trim().split(/\s+/).map(Number);
                rx += fields[0];
                tx += fields[8];
            }
            if (tunnels.join(" ") !== hw.tunnels.join(" "))
                hw.tunnels = tunnels;
            const step = hw.delta("net", [rx, tx]);
            if (step) {
                hw.rx = Math.max(0, step.values[0] / step.seconds);
                hw.tx = Math.max(0, step.values[1] / step.seconds);
            }
        }
    }

    FileView {
        id: diskFile

        path: "/proc/diskstats"
        printErrors: false
        onLoaded: {
            const disk = String(hw.info.disk ?? "");
            const row = text().split("\n").map(line => line.trim().split(/\s+/)).find(fields => fields[2] === disk);
            if (!row)
                return;
            const step = hw.delta("disk", [Number(row[5]) * 512, Number(row[9]) * 512]);
            if (step) {
                hw.diskRead = Math.max(0, step.values[0] / step.seconds);
                hw.diskWrite = Math.max(0, step.values[1] / step.seconds);
            }
        }
    }

    FileView {
        id: tempFile

        path: hw.info.temp ?? ""
        printErrors: false
        onLoaded: hw.temp = hw.value(tempFile) / 1000
    }

    FileView {
        id: fanFile

        path: hw.info.fan ?? ""
        printErrors: false
        onLoaded: hw.fan = hw.value(fanFile)
    }

    FileView {
        id: diskTempFile

        path: hw.info.nvme ?? ""
        printErrors: false
        onLoaded: hw.diskTemp = hw.value(diskTempFile) / 1000
    }

    FileView {
        id: gpuFile

        path: hw.gpuPath
        printErrors: false
        onLoaded: {
            const value = hw.value(gpuFile);
            if (hw.gpuKind === "busy") {
                hw.gpu = value;
                return;
            }
            const step = hw.delta("gpu", [value]);
            if (step)
                hw.gpu = Math.max(0, Math.min(100, 100 - step.values[0] / step.seconds / 10));
        }
    }

    FileView {
        id: gpuClockFile

        path: hw.gpuClockPath
        printErrors: false
        onLoaded: hw.gpuClock = hw.value(gpuClockFile) / (hw.gpuClockKind === "hz" ? 1e6 : 1)
    }

    FileView {
        id: capacityFile

        path: hw.info.battery ? hw.info.battery + "/capacity" : ""
        printErrors: false
        onLoaded: hw.battery = hw.value(capacityFile)
    }

    FileView {
        id: statusFile

        path: hw.info.battery ? hw.info.battery + "/status" : ""
        printErrors: false
        onLoaded: hw.charging = text().trim() === "Charging"
    }

    FileView {
        id: powerFile

        path: hw.info.battery ? hw.info.battery + "/power_now" : ""
        printErrors: false
        onLoaded: hw.watts = Math.abs(hw.value(powerFile)) / 1e6
    }

    FileView {
        id: plugFile

        path: hw.info.ac ? hw.info.ac + "/online" : ""
        printErrors: false
        onLoaded: hw.plugged = text().trim() === "1"
    }
}
