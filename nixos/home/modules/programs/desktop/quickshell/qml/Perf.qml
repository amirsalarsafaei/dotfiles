pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland

Singleton {
    id: perf

    property string mode: "auto"
    readonly property bool onBattery: UPower.onBattery
    readonly property bool saver: PowerProfiles.profile === PowerProfile.PowerSaver
    readonly property bool eco: mode === "eco" || (mode === "auto" && (onBattery || saver))
    readonly property bool away: idle.isIdle
    readonly property int frames: eco ? 6 : 2
    readonly property int pollScale: eco ? 2 : 1
    readonly property var windowEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspace", "workspacev2", "focusedmon", "focusedmonv2"]

    function cycle(): void {
        mode = mode === "auto" ? "eco" : mode === "eco" ? "full" : "auto";
    }

    function covered(workspace: var): bool {
        if (!workspace)
            return false;
        if (workspace.hasFullscreen)
            return true;
        return workspace.toplevels.values.some(toplevel => !(toplevel.lastIpcObject?.floating ?? false));
    }

    function veiled(monitor: var): bool {
        return (monitor?.lastIpcObject?.specialWorkspace?.name ?? "").length > 0;
    }

    IdleMonitor {
        id: idle

        timeout: Sys.idleTimeout
        respectInhibitors: true
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (perf.windowEvents.includes(event.name))
                refresh.restart();
            else if (event.name === "activespecial")
                Hyprland.refreshMonitors();
        }
    }

    Timer {
        id: refresh
        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
    }
}
