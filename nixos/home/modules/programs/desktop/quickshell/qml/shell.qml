import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    property bool sidebarOpen: false
    property bool boardOpen: false
    property string screenName: ""

    function pickScreen(): void {
        const focused = Hyprland.focusedMonitor;
        root.screenName = focused ? focused.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
    }

    function openSidebar(): void {
        root.pickScreen();
        root.boardOpen = false;
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
        }
    }

    Variants {
        model: Quickshell.screens

        Sidebar {
            required property var modelData
            screen: modelData
            active: root.sidebarOpen && root.screenName === modelData.name
            onCloseRequested: root.sidebarOpen = false
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
                root.openSidebar();
        }

        function open(): void {
            root.openSidebar();
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
}
