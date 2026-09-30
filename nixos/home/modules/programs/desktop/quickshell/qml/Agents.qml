pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: agents

    property var sessions: ({})
    property var live: ({})
    property bool probed: false
    property bool pending: false
    property string selected: ""
    readonly property string home: String(Quickshell.env("HOME") ?? "")
    readonly property string tracked: Object.keys(sessions).map(id => {
        const s = sessions[id];
        return s && s.zellij ? s.zellij.session + "/" + s.zellij.pane : id;
    }).sort().join(" ")
    readonly property var list: {
        const now = Date.now();
        const entries = Object.entries(sessions).filter(([id, s]) => s && typeof s === "object");
        const claimed = new Set();
        const paired = {};
        for (const [id, s] of entries) {
            const key = s.zellij ? s.zellij.session + "/" + s.zellij.pane : "";
            if (key !== "" && live[key] !== undefined) {
                claimed.add(key);
                paired[id] = live[key];
            }
        }
        const loose = entries.filter(([id, s]) => !s.zellij);
        for (const [id, s] of loose) {
            const title = clean(s.title ?? "");
            const free = Object.keys(live).filter(key => !claimed.has(key));
            let key = title !== "" ? free.find(k => clean(live[k].title) === title) : undefined;
            if (key === undefined && (s.cwd ?? "") !== "") {
                const sameCwd = free.filter(k => live[k].cwd === s.cwd);
                const rivals = loose.filter(([other, o]) => o.cwd === s.cwd && paired[other] === undefined);
                if (sameCwd.length === 1 && rivals.length === 1)
                    key = sameCwd[0];
            }
            if (key !== undefined) {
                claimed.add(key);
                paired[id] = live[key];
            }
        }
        const result = [];
        for (const [id, s] of entries) {
            const pane = paired[id];
            if (s.zellij && (!probed || pane === undefined))
                continue;
            if (!pane && s.state === "idle" && now - (s.at ?? 0) > 3600000)
                continue;
            result.push(agents.describe(id, s, pane));
        }
        const rank = realm => realm === "work" ? 0 : realm === "" ? 1 : 2;
        return result.sort((a, b) => rank(a.realm) - rank(b.realm) || a.started - b.started || a.id.localeCompare(b.id));
    }
    readonly property var ids: list.map(a => a.id)
    readonly property var byId: {
        const map = {};
        for (const agent of list)
            map[agent.id] = agent;
        return map;
    }

    function clean(text: string): string {
        return String(text ?? "").replace(/^[^0-9A-Za-z\u00C0-\u024F\u0400-\u04FF\u0600-\u06FF]+/, "").trim();
    }

    function tint(status: string): color {
        return status === "working" ? Theme.blue : status === "planning" ? Theme.cyan : status === "asking" ? Theme.heat : status === "error" ? Theme.danger : status === "done" ? Theme.muted : Theme.faint;
    }

    function ago(ms: real, now: real): string {
        const minutes = Math.floor(Math.max(0, now - ms) / 60000);
        if (ms <= 0)
            return "";
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return minutes + "m";
        if (minutes < 1440)
            return Math.floor(minutes / 60) + "h";
        return Math.floor(minutes / 1440) + "d";
    }

    function realmOf(s: var): string {
        const realm = String(s.realm ?? "");
        const cwd = String(s.cwd ?? "");
        const inside = dir => home !== "" && (cwd === home + "/" + dir || cwd.startsWith(home + "/" + dir + "/"));
        if (realm === "work" || realm === "personal")
            return realm;
        if (inside("divar"))
            return "work";
        if (inside("personal"))
            return "personal";
        return "";
    }

    function describe(id: string, s: var, pane: var): var {
        const status = s.state === "error" ? "error" : s.state === "waiting" ? "asking" : s.state === "working" ? (s.mode === "plan" ? "planning" : "working") : s.verb === "done" ? "done" : "ready";
        const activity = [s.verb ?? "", s.object ?? ""].filter(part => part !== "").join(" ");
        const name = clean(s.title ?? "") || clean(pane?.title ?? "") || s.project || "claude";
        return {
            id: id,
            name: name === "Claude Code" ? (s.project || name) : name,
            status: status,
            activity: status === "done" || status === "ready" ? "" : activity,
            todo: s.todo ?? null,
            project: s.project ?? "",
            variant: s.variant ?? "",
            realm: agents.realmOf(s),
            since: s.since ?? s.at ?? 0,
            started: s.started ?? 0,
            tools: s.tools ?? 0,
            agents: s.agents ?? 0,
            session: pane?.session ?? s.zellij?.session ?? "",
            pane: pane?.pane ?? s.zellij?.pane ?? "",
            tab: pane?.tab ?? ""
        };
    }

    function refresh(): void {
        if (probe.running)
            agents.pending = true;
        else
            probe.running = true;
    }

    function open(agent: var): void {
        if (agent && agent.session !== "" && agent.pane !== "")
            Quickshell.execDetached([Sys.agents, "open", agent.session, String(agent.pane)]);
    }

    onTrackedChanged: refresh()

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/" + Sys.agentsDir + "/state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                agents.sessions = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
            } catch (error) {
                agents.sessions = {};
            }
        }
        onLoadFailed: agents.sessions = {}
    }

    Process {
        id: probe

        command: [Sys.agents, "live"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    agents.live = parsed && typeof parsed === "object" ? parsed : {};
                } catch (error) {
                    agents.live = {};
                }
                agents.probed = true;
            }
        }
        onRunningChanged: {
            if (!running && agents.pending) {
                agents.pending = false;
                Qt.callLater(() => probe.running = true);
            }
        }
    }
}
