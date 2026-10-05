import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: ticker

    property bool running: false
    property int frames: Perf.frames
    readonly property real step: frames / 60
    property real time: 0
    property real level: 0
    property real swell: 0

    onStepChanged: {
        clock.due = Date.now();
        clock.interval = Math.round(step * 1000);
    }

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    PwNodePeakMonitor {
        id: peaks
        node: Pipewire.defaultAudioSink
        enabled: ticker.running && !Perf.eco
    }

    Timer {
        id: clock

        property real due: Date.now()

        interval: Math.round(ticker.step * 1000)
        repeat: true
        running: ticker.running
        onRunningChanged: {
            due = Date.now();
            interval = Math.round(ticker.step * 1000);
            if (!running) {
                ticker.level = 0;
                ticker.swell = 0;
            }
        }
        onTriggered: {
            const current = Date.now();
            const period = ticker.step * 1000;
            const steps = Math.max(1, Math.round((current - due) / period));
            due += steps * period;
            interval = Math.max(1, Math.round(due + period - current));
            const delta = Math.min(0.25, steps * ticker.step);
            ticker.time += delta;
            const target = peaks.enabled ? Math.min(1, peaks.peak * 1.4) : 0;
            const next = target > ticker.level ? ticker.level + (target - ticker.level) * 0.5 : ticker.level * 0.82;
            ticker.level = next < 0.01 ? 0 : next;
            ticker.swell += (ticker.level - ticker.swell) * (1 - Math.exp(-delta / 2.5));
        }
    }
}
