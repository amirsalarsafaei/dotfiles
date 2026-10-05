import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: ticker

    property bool running: false
    property int interval: Perf.frameInterval
    property real time: 0
    property real level: 0
    property real swell: 0

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    PwNodePeakMonitor {
        id: peaks
        node: Pipewire.defaultAudioSink
        enabled: ticker.running && !Perf.eco
    }

    Timer {
        property real last: Date.now()

        interval: ticker.interval
        repeat: true
        running: ticker.running
        onRunningChanged: {
            last = Date.now();
            if (!running) {
                ticker.level = 0;
                ticker.swell = 0;
            }
        }
        onTriggered: {
            const current = Date.now();
            const delta = Math.min(0.25, (current - last) / 1000);
            ticker.time += delta;
            last = current;
            const target = peaks.enabled ? Math.min(1, peaks.peak * 1.4) : 0;
            const next = target > ticker.level ? ticker.level + (target - ticker.level) * 0.5 : ticker.level * 0.82;
            ticker.level = next < 0.01 ? 0 : next;
            ticker.swell += (ticker.level - ticker.swell) * (1 - Math.exp(-delta / 2.5));
        }
    }
}
