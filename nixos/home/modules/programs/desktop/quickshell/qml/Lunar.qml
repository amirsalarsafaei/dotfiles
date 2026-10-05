pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var names: ["new moon", "waxing crescent", "first quarter", "waxing gibbous", "full moon", "waning gibbous", "last quarter", "waning crescent"]

    function of(date: date): var {
        const synodic = 29.530588853;
        const days = (date.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        const phase = (((days % synodic) + synodic) % synodic) / synodic;
        return {
            phase: phase,
            lit: 0.5 - 0.5 * Math.cos(2 * Math.PI * phase),
            name: names[Math.round(phase * 8) % 8]
        };
    }
}
