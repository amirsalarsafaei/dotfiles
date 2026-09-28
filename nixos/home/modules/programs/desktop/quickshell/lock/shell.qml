import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    property string buffer: ""
    property bool queued: false
    property bool checking: false
    property bool unlocking: false
    property bool failed: false
    property int failures: 0
    property int errors: 0
    property string notice: ""
    property string fingerprintNote: ""
    property bool fingerprintReady: false
    property bool capsLock: false
    property string layout: ""

    readonly property bool revealed: lock.secure && !unlocking
    readonly property string user: String(Quickshell.env("USER") ?? "")

    function type(text: string): void {
        if (root.checking || root.unlocking)
            return;
        root.buffer += text;
        root.failed = false;
        root.notice = "";
    }

    function erase(all: bool): void {
        if (root.checking || root.unlocking)
            return;
        root.buffer = all ? "" : root.buffer.slice(0, -1);
        root.failed = false;
        root.notice = "";
    }

    function submit(): void {
        if (root.buffer.length === 0 || root.checking || root.unlocking)
            return;
        root.checking = true;
        root.failed = false;
        root.notice = "";
        if (password.active && password.responseRequired) {
            password.respond(root.buffer);
            return;
        }
        root.queued = true;
        if (!password.active && !password.start())
            root.bail();
    }

    function reject(text: string): void {
        root.checking = false;
        root.queued = false;
        root.buffer = "";
        root.failed = true;
        root.failures += 1;
        root.notice = text;
    }

    function bail(): void {
        root.notice = "Authentication unavailable, switching to hyprlock";
        root.failed = true;
        bailTimer.start();
    }

    function unlock(): void {
        if (root.unlocking)
            return;
        root.unlocking = true;
        root.buffer = "";
        root.checking = false;
        if (fingerprint.active)
            fingerprint.abort();
        if (password.active)
            password.abort();
        unlockTimer.start();
    }

    PamContext {
        id: password
        config: "password"
        configDirectory: Sys.pamDir

        onPamMessage: {
            if (responseRequired) {
                if (root.queued) {
                    root.queued = false;
                    respond(root.buffer);
                }
            } else if (message.length > 0) {
                root.notice = message;
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            if (result === PamResult.Error) {
                root.errors += 1;
                if (root.errors >= 3) {
                    root.bail();
                    return;
                }
                root.reject("Authentication error, try again");
                return;
            }
            root.reject(result === PamResult.MaxTries ? "Too many attempts" : "Wrong password");
        }

        onError: error => {
            root.errors += 1;
            if (error === PamError.StartFailed || root.errors >= 3) {
                root.bail();
                return;
            }
            root.reject("Authentication error, try again");
        }
    }

    PamContext {
        id: fingerprint

        property bool listening: false

        config: "fingerprint"
        configDirectory: Sys.pamDir

        onPamMessage: {
            if (message.length === 0)
                return;
            listening = true;
            root.fingerprintReady = true;
            root.fingerprintNote = messageIsError ? message : "";
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.fingerprintReady = false;
            root.fingerprintNote = "";
            if (listening && !root.unlocking)
                fingerprintRetry.start();
            listening = false;
        }

        onError: {
            root.fingerprintReady = false;
            root.fingerprintNote = "";
            listening = false;
        }
    }

    Timer {
        id: fingerprintRetry
        interval: 1500
        onTriggered: {
            if (!root.unlocking && !fingerprint.active)
                fingerprint.start();
        }
    }

    Timer {
        id: unlockTimer
        interval: 340
        onTriggered: {
            lock.locked = false;
            quitTimer.start();
        }
    }

    Timer {
        id: quitTimer
        interval: 500
        onTriggered: Qt.quit()
    }

    Timer {
        id: bailTimer
        interval: 1200
        onTriggered: Qt.exit(3)
    }

    Process {
        id: readyProc
        command: [Sys.touch, Quickshell.env("LOCK_READY") || "/dev/null"]
    }

    Process {
        id: capsProc
        command: [Sys.action, "caps"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = this.text.trim() === "1"
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: lock.secure
        onTriggered: capsProc.running = true
    }

    Process {
        id: layoutProc
        running: true
        command: [Sys.hyprctl, "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(this.text).keyboards ?? [];
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    root.layout = main?.active_keymap ?? "";
                } catch (error) {
                    root.layout = "";
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name !== "activelayout")
                return;
            const data = event.data;
            root.layout = data.slice(data.indexOf(",") + 1);
        }
    }

    WlSessionLock {
        id: lock

        locked: true

        onSecureChanged: {
            if (!secure)
                return;
            readyProc.running = true;
            if (Sys.fingerprint)
                fingerprint.start();
        }

        WlSessionLockSurface {
            id: surface

            color: Theme.ink

            Image {
                id: wallpaper
                anchors.fill: parent
                source: "file://" + Sys.wallpaper
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: wallpaper
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                saturation: -0.2
                brightness: -0.12
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.ink, 0.5)
            }

            Item {
                id: stage

                property real progress: root.revealed ? 1 : 0

                Behavior on progress {
                    NumberAnimation {
                        duration: root.unlocking ? 300 : 620
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.unlocking ? [0.3, 0, 0.8, 0.15, 1, 1] : [0.05, 0.7, 0.1, 1, 1, 1]
                    }
                }

                anchors.fill: parent
                focus: true

                Component.onCompleted: {
                    forceActiveFocus();
                    board.refresh();
                }

                Keys.onPressed: event => {
                    event.accepted = true;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.submit();
                    else if (event.key === Qt.Key_Backspace)
                        root.erase((event.modifiers & Qt.ControlModifier) !== 0);
                    else if (event.key === Qt.Key_Escape)
                        root.erase(true);
                    else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) === 0)
                        root.type(event.text);
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => {
                        stage.forceActiveFocus();
                        mouse.accepted = false;
                    }
                }

                Item {
                    width: Math.min(1240, surface.width - 120)
                    height: board.implicitHeight
                    anchors.centerIn: parent
                    scale: Math.min(1, (surface.height - 40) / Math.max(1, height))

                    BoardContent {
                        id: board
                        width: parent.width
                        progress: stage.progress
                        shown: true

                        footer: AuthField {
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: stage.progress
                            length: root.buffer.length
                            checking: root.checking
                            failed: root.failed
                            failures: root.failures
                            notice: root.notice
                            fingerprint: root.fingerprintNote
                            fingerprintReady: root.fingerprintReady
                            capsLock: root.capsLock
                            layout: root.layout
                            user: root.user
                        }
                    }
                }
            }
        }
    }
}
