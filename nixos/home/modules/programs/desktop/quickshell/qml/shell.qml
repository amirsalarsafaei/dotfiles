//@ pragma UseQApplication
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    property bool sidebarOpen: false
    property string sidebarPage: "home"
    property bool boardOpen: false
    property bool barShown: true
    property bool dusk: false
    property string screenName: ""

    function pickScreen(): void {
        const focused = Hyprland.focusedMonitor;
        root.screenName = focused ? focused.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
    }

    function openSidebar(page: string): void {
        root.pickScreen();
        root.boardOpen = false;
        root.sidebarPage = page;
        root.sidebarOpen = true;
    }

    function openBoard(): void {
        root.pickScreen();
        root.sidebarOpen = false;
        root.boardOpen = true;
    }

    Variants {
        model: Quickshell.screens

        Wallpaper {
            required property var modelData
            screen: modelData
            overlay: root.boardOpen && root.screenName === modelData.name
            dusk: root.dusk
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
            shown: root.barShown
            onSidebarRequested: {
                root.screenName = modelData.name;
                root.boardOpen = false;
                if (!root.sidebarOpen)
                    root.sidebarPage = "home";
                root.sidebarOpen = !root.sidebarOpen;
            }
            onWidgetsRequested: {
                root.screenName = modelData.name;
                root.sidebarOpen = false;
                root.boardOpen = !root.boardOpen;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Sidebar {
            required property var modelData
            screen: modelData
            active: root.sidebarOpen && root.screenName === modelData.name
            page: root.sidebarPage
            onCloseRequested: root.sidebarOpen = false
            onPageRequested: name => root.sidebarPage = name
            onBoardRequested: root.openBoard()
        }
    }

    Variants {
        model: Quickshell.screens

        Board {
            required property var modelData
            screen: modelData
            active: root.boardOpen && root.screenName === modelData.name
            onCloseRequested: root.boardOpen = false
        }
    }

    IpcHandler {
        target: "sidebar"

        function toggle(): void {
            if (root.sidebarOpen)
                root.sidebarOpen = false;
            else
                root.openSidebar("home");
        }

        function open(): void {
            root.openSidebar("home");
        }

        function agents(): void {
            if (root.sidebarOpen && root.sidebarPage === "agents")
                root.sidebarOpen = false;
            else
                root.openSidebar("agents");
        }

        function close(): void {
            root.sidebarOpen = false;
        }
    }

    IpcHandler {
        target: "widgets"

        function toggle(): void {
            if (root.boardOpen)
                root.boardOpen = false;
            else
                root.openBoard();
        }

        function open(): void {
            root.openBoard();
        }

        function close(): void {
            root.boardOpen = false;
        }
    }

    Osd {
        id: osd
    }

    IpcHandler {
        target: "osd"

        function volume(): void {
            osd.volume();
        }

        function mic(): void {
            osd.microphone();
        }

        function brightness(percent: int): void {
            osd.brightness(percent);
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barShown = !root.barShown;
        }

        function show(): void {
            root.barShown = true;
        }

        function hide(): void {
            root.barShown = false;
        }
    }

    IpcHandler {
        target: "sky"

        function toggle(): string {
            root.dusk = !root.dusk;
            return root.dusk ? "dusk" : "now";
        }

        function dusk(): void {
            root.dusk = true;
        }

        function now(): void {
            root.dusk = false;
        }

        function status(): string {
            return root.dusk ? "dusk" : "now";
        }
    }

    IpcHandler {
        target: "lyrics"

        function toggle(): string {
            Prefs.floatingLyrics = !Prefs.floatingLyrics;
            return Prefs.floatingLyrics ? "on" : "off";
        }

        function show(): void {
            Prefs.floatingLyrics = true;
        }

        function hide(): void {
            Prefs.floatingLyrics = false;
        }
    }

    IpcHandler {
        target: "art"

        function toggle(): string {
            Prefs.albumArt = !Prefs.albumArt;
            return Prefs.albumArt ? "on" : "off";
        }
    }

    IpcHandler {
        target: "perf"

        function cycle(): string {
            Perf.cycle();
            return Perf.mode;
        }

        function set(mode: string): string {
            if (["auto", "eco", "full"].includes(mode))
                Perf.mode = mode;
            return Perf.mode;
        }

        function status(): string {
            return Perf.mode + (Perf.eco ? " eco" : " full");
        }
    }
}
