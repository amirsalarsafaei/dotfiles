import QtQuick

Item {
    id: die

    property var threads: []
    property var loads: []
    property string vendor: "intel"
    property string model: ""
    property real gpu: 0
    property color accent: Theme.cyan

    readonly property var plan: die.vendor === "amd" ? amd(groups(die.threads)) : intel(groups(die.threads))
    readonly property real aspect: plan.w
    readonly property real k: height
    readonly property real type: Math.max(6, Math.round(height * 0.042))
    readonly property var styles: ({
            die: [Qt.rgba(0.027, 0.039, 0.063, 1), Theme.alpha(Theme.muted, 0.32), 3],
            block: [Theme.alpha(Theme.muted, 0.06), Theme.alpha(Theme.muted, 0.28), 2],
            detail: ["transparent", Theme.alpha(Theme.muted, 0.18), 1],
            gpu: [Theme.alpha(Theme.blue, 0.07), Theme.alpha(Theme.blue, 0.38), 2],
            eu: [Theme.alpha(Theme.blue, 0.2), "transparent", 1],
            sram: [Theme.alpha(Theme.cyan, 0.06), Theme.alpha(Theme.cyan, 0.22), 1],
            bit: [Theme.alpha(Theme.cyan, 0.11), "transparent", 0],
            npu: [Theme.alpha(Theme.good, 0.16), "transparent", 1],
            phy: [Theme.alpha(Theme.warm, 0.18), "transparent", 1],
            ring: [Theme.alpha(die.accent, 0.55), "transparent", 1]
        })

    function groups(list: var): var {
        const out = [];
        const seen = {};
        for (const thread of list) {
            const kind = thread.kind === "e" ? "e" : "p";
            const key = kind + ":" + (thread.l3 ?? 0) + ":" + thread.core;
            if (seen[key] === undefined) {
                seen[key] = out.length;
                out.push({
                    kind: kind,
                    l2: thread.l2 ?? -1,
                    l2kb: thread.l2kb ?? 0,
                    l3: thread.l3 ?? 0,
                    l3kb: thread.l3kb ?? 0,
                    cpus: []
                });
            }
            out[seen[key]].cpus.push(thread.cpu);
        }
        return out;
    }

    function bucket(list: var, field: string): var {
        const out = [];
        const at = {};
        for (const item of list) {
            const key = String(item[field]);
            if (at[key] === undefined) {
                at[key] = out.length;
                out.push([]);
            }
            out[at[key]].push(item);
        }
        return out;
    }

    function megs(kb: real): string {
        return kb >= 1024 ? +(kb / 1024).toFixed(kb % 1024 === 0 ? 0 : 2) + "M" : Math.round(kb) + "K";
    }

    function grid(into: var, r: var, cols: int, rows: int, gap: real, style: string): void {
        const w = (r[2] - r[0] - gap * (cols - 1)) / cols;
        const h = (r[3] - r[1] - gap * (rows - 1)) / rows;
        for (let row = 0; row < rows; row++)
            for (let col = 0; col < cols; col++)
                into.push({
                    r: [r[0] + col * (w + gap), r[1] + row * (h + gap), r[0] + col * (w + gap) + w, r[1] + row * (h + gap) + h],
                    s: style
                });
    }

    function phy(blocks: var, labels: var, w: real, name: string): void {
        const r = [0.035, 0.895, w - 0.035, 0.965];
        labels.push({
            x: r[0],
            y: r[1] + 0.008,
            text: name,
            at: 0.55
        });
        grid(blocks, [r[0] + 0.24, r[1] + 0.016, r[2], r[3] - 0.016], 8, 1, 0.012, "phy");
    }

    function core(blocks: var, r: var, l2: string, flip: bool): void {
        const w = r[2] - r[0];
        const h = r[3] - r[1];
        const pad = Math.min(0.01, w * 0.08);
        const band = h * 0.2;
        const top = flip ? r[1] + band + pad : r[1] + pad;
        const bottom = flip ? r[3] - pad : r[3] - band - pad;
        const mid = top + (bottom - top) * 0.36;
        blocks.push({
            r: [r[0] + pad, top, r[2] - pad, mid - pad * 0.5],
            s: "detail"
        });
        blocks.push({
            r: [r[0] + pad, mid + pad * 0.5, r[0] + w * 0.52, bottom],
            s: "detail"
        });
        blocks.push({
            r: [r[0] + w * 0.56, mid + pad * 0.5, r[2] - pad, bottom],
            s: "detail"
        });
        if (l2 !== "")
            blocks.push({
                r: flip ? [r[0] + pad, r[1] + pad, r[2] - pad, r[1] + band] : [r[0] + pad, r[3] - band, r[2] - pad, r[3] - pad],
                s: "sram"
            });
    }

    function intel(list: var): var {
        const w = 1.32;
        const blocks = [];
        const labels = [];
        const cores = [];
        const big = list.filter(group => group.kind === "p");
        const clusters = bucket(list.filter(group => group.kind === "e"), "l2");
        const stops = big.length + clusters.length;
        const eus = /i[79]-/.test(die.model) ? 96 : /i5-/.test(die.model) ? 80 : 64;
        const gpu = [0.035, 0.035, 0.34, 0.86];
        const agent = [w - 0.215, 0.035, w - 0.035, 0.86];
        const x0 = gpu[2] + 0.025;
        const x1 = agent[0] - 0.025;
        const gap = 0.014;
        const sw = (x1 - x0 - gap * (Math.max(1, stops) - 1)) / Math.max(1, stops);
        const l3 = bucket(list, "l3").reduce((sum, domain) => sum + (domain[0].l3kb ?? 0), 0);

        blocks.push({
            r: [0, 0, w, 1],
            s: "die"
        });
        blocks.push({
            r: gpu,
            s: "gpu"
        });
        labels.push({
            x: gpu[0] + 0.015,
            y: gpu[1] + 0.012,
            text: "xe · " + eus + "eu",
            at: 0.8
        });
        const slices = Math.max(1, Math.round(eus / 16));
        const rows = Math.ceil(slices / 2);
        const area = [gpu[0] + 0.015, gpu[1] + 0.09, gpu[2] - 0.015, gpu[3] - 0.015];
        const subW = (area[2] - area[0] - 0.012) / 2;
        const subH = (area[3] - area[1] - 0.012 * (rows - 1)) / rows;
        for (let i = 0; i < slices; i++) {
            const col = i % 2;
            const row = Math.floor(i / 2);
            const r = [area[0] + col * (subW + 0.012), area[1] + row * (subH + 0.012), area[0] + col * (subW + 0.012) + subW, area[1] + row * (subH + 0.012) + subH];
            blocks.push({
                r: r,
                s: "block"
            });
            grid(blocks, [r[0] + 0.008, r[1] + 0.008, r[2] - 0.008, r[3] - 0.008], 4, 4, 0.006, "eu");
        }

        blocks.push({
            r: agent,
            s: "block"
        });
        const parts = ["disp", "media", "ipu", "tbt4", "imc"];
        const partH = (agent[3] - agent[1] - 0.02 - 0.01 * (parts.length - 1)) / parts.length;
        parts.forEach((name, i) => {
            const r = [agent[0] + 0.012, agent[1] + 0.01 + i * (partH + 0.01), agent[2] - 0.012, agent[1] + 0.01 + i * (partH + 0.01) + partH];
            blocks.push({
                r: r,
                s: "detail"
            });
            labels.push({
                x: r[0] + 0.01,
                y: r[1] + 0.008,
                text: name,
                at: 0.6
            });
        });

        let x = x0;
        big.forEach((group, i) => {
            const r = [x, 0.035, x + sw, 0.56];
            core(blocks, r, megs(group.l2kb), false);
            cores.push({
                r: r,
                kind: "p",
                name: "p" + i,
                cpus: group.cpus
            });
            x += sw + gap;
        });
        let eIndex = 0;
        for (const cluster of clusters) {
            const r = [x, 0.035, x + sw, 0.56];
            blocks.push({
                r: r,
                s: "block"
            });
            const mid = (r[1] + r[3]) / 2;
            const l2 = [r[0] + 0.008, mid - 0.03, r[2] - 0.008, mid + 0.03];
            blocks.push({
                r: l2,
                s: "sram"
            });
            grid(blocks, [l2[0] + 0.008, l2[1] + 0.012, l2[2] - 0.008, l2[3] - 0.012], 4, 1, 0.006, "bit");
            const half = (sw - 0.024) / 2;
            cluster.slice(0, 4).forEach((group, i) => {
                const cx = r[0] + 0.008 + (i % 2) * (half + 0.008);
                const cy = i < 2 ? r[1] + 0.012 : mid + 0.04;
                const tile = [cx, cy, cx + half, i < 2 ? mid - 0.04 : r[3] - 0.012];
                core(blocks, tile, "", false);
                cores.push({
                    r: tile,
                    kind: "e",
                    name: "e" + eIndex,
                    cpus: group.cpus
                });
                eIndex++;
            });
            x += sw + gap;
        }

        for (let i = 0; i < stops; i++) {
            const sx = x0 + i * (sw + gap);
            const r = [sx, 0.59, sx + sw, 0.735];
            blocks.push({
                r: r,
                s: "sram"
            });
            grid(blocks, [r[0] + 0.008, r[1] + 0.012, r[2] - 0.008, r[3] - 0.012], 2, 3, 0.008, "bit");
        }
        if (l3 > 0)
            labels.push({
                x: x0,
                y: 0.745,
                text: "l3 " + megs(l3) + " · ring",
                at: 0.6
            });
        blocks.push({
            r: [gpu[2], 0.836, agent[0], 0.843],
            s: "ring"
        });
        for (let i = 0; i < stops; i++) {
            const cx = x0 + i * (sw + gap) + sw / 2;
            blocks.push({
                r: [cx - 0.009, 0.83, cx + 0.009, 0.849],
                s: "ring"
            });
        }
        phy(blocks, labels, w, "lpddr5");

        return {
            w: w,
            blocks: blocks,
            labels: labels,
            cores: cores,
            gpu: gpu,
            summary: list.length > big.length ? big.length + "p+" + (list.length - big.length) + "e" : big.length + "c/" + die.threads.length + "t"
        };
    }

    function amd(list: var): var {
        const w = 1.32;
        const blocks = [];
        const labels = [];
        const cores = [];
        const domains = bucket(list, "l3").sort((a, b) => Number(a[0].kind === "e") - Number(b[0].kind === "e"));
        const npu = /ryzen ai/i.test(die.model);
        const radeon = /Radeon\s+(\d)(\d)0M/i.exec(die.model);
        const cus = radeon ? ({
                "9": 16,
                "8": 12,
                "6": 8,
                "4": 4
            })[radeon[2]] ?? 12 : 8;
        const arch = radeon ? ({
                "8": "rdna 3.5",
                "7": "rdna 3",
                "6": "rdna 2"
            })[radeon[1]] ?? "rdna" : "radeon";
        const zen = radeon ? ({
                "8": "zen 5",
                "7": "zen 4",
                "6": "zen 3+"
            })[radeon[1]] ?? "zen" : "zen";
        const left = [0.035, 0.035, 0.8, 0.86];
        const right = [0.83, 0.035, w - 0.035, 0.86];
        const gap = 0.03;
        const rowH = (left[3] - left[1] - gap * (Math.max(1, domains.length) - 1)) / Math.max(1, domains.length);

        blocks.push({
            r: [0, 0, w, 1],
            s: "die"
        });

        let index = 0;
        domains.forEach((domain, row) => {
            const y = left[1] + row * (rowH + gap);
            const box = [left[0], y, left[2], y + rowH];
            const flip = row % 2 === 1;
            blocks.push({
                r: box,
                s: "block"
            });
            const n = domain.length;
            const pad = 0.012;
            const tw = (box[2] - box[0] - 2 * pad - 0.01 * (n - 1)) / Math.max(1, n);
            const coreTop = flip ? y + rowH * 0.36 : y + pad;
            const coreBottom = flip ? y + rowH - pad : y + rowH * 0.64;
            const l3 = flip ? [box[0] + pad, y + pad, box[2] - pad, y + rowH * 0.32] : [box[0] + pad, y + rowH * 0.68, box[2] - pad, y + rowH - pad];
            blocks.push({
                r: l3,
                s: "sram"
            });
            grid(blocks, [l3[0] + 0.2, l3[1] + 0.014, l3[2] - 0.01, l3[3] - 0.014], 8, 2, 0.008, "bit");
            labels.push({
                x: l3[0] + 0.012,
                y: (l3[1] + l3[3]) / 2 - 0.024,
                text: zen + (domain[0].kind === "e" ? "c" : "") + "\nl3 " + megs(domain[0].l3kb),
                at: 0.8
            });
            domain.forEach((group, i) => {
                const tx = box[0] + pad + i * (tw + 0.01);
                const tile = [tx, coreTop, tx + tw, coreBottom];
                core(blocks, tile, megs(group.l2kb), flip);
                cores.push({
                    r: tile,
                    kind: group.kind,
                    name: "c" + index,
                    cpus: group.cpus
                });
                index++;
            });
        });

        let gpuTop = right[1];
        if (npu) {
            const r = [right[0], right[1], right[2], 0.3];
            blocks.push({
                r: r,
                s: "block"
            });
            labels.push({
                x: r[0] + 0.012,
                y: r[1] + 0.01,
                text: "xdna npu",
                at: 0.7
            });
            grid(blocks, [r[0] + 0.012, r[1] + 0.07, r[2] - 0.012, r[3] - 0.012], 8, 4, 0.006, "npu");
            gpuTop = 0.33;
        }
        const gpu = [right[0], gpuTop, right[2], right[3]];
        blocks.push({
            r: gpu,
            s: "gpu"
        });
        labels.push({
            x: gpu[0] + 0.012,
            y: gpu[1] + 0.01,
            text: arch + " · " + cus + "cu",
            at: 0.8
        });
        const cols = cus >= 12 ? 4 : 2;
        grid(blocks, [gpu[0] + 0.012, gpu[1] + 0.075, gpu[2] - 0.012, gpu[3] - 0.012], cols, Math.ceil(cus / cols), 0.01, "eu");
        phy(blocks, labels, w, "lpddr5x");

        return {
            w: w,
            blocks: blocks,
            labels: labels,
            cores: cores,
            gpu: gpu,
            summary: list.length + "c/" + die.threads.length + "t"
        };
    }

    function mean(cpus: var): real {
        if (cpus.length === 0)
            return 0;
        return cpus.reduce((sum, cpu) => sum + (die.loads[cpu] ?? 0), 0) / cpus.length;
    }

    function px(v: real): real {
        return Math.round(v * die.k);
    }

    Repeater {
        model: die.plan.blocks

        Rectangle {
            required property var modelData
            readonly property var look: die.styles[modelData.s]

            x: die.px(modelData.r[0])
            y: die.px(modelData.r[1])
            width: Math.max(1, die.px(modelData.r[2]) - x)
            height: Math.max(1, die.px(modelData.r[3]) - y)
            radius: look[2]
            color: look[0]
            border.width: look[1] === "transparent" ? 0 : 1
            border.color: look[1]
        }
    }

    Rectangle {
        readonly property var box: die.plan.gpu

        x: die.px(box[0]) + 1
        y: die.px(box[1]) + 1
        width: die.px(box[2]) - x - 1
        height: die.px(box[3]) - y - 1
        radius: 2
        color: Theme.alpha(Theme.blue, 0.3 * die.gpu)
        visible: die.gpu > 0.02
    }

    Repeater {
        model: die.plan.labels

        Text {
            required property var modelData

            x: die.px(modelData.x)
            y: die.px(modelData.y)
            text: modelData.text
            color: Theme.alpha(Theme.muted, modelData.at)
            lineHeight: 0.9
            font.family: Theme.mono
            font.pixelSize: die.type
            font.weight: Font.Medium
            font.letterSpacing: 0.6
            font.capitalization: Font.AllUppercase
            textFormat: Text.PlainText
        }
    }

    Repeater {
        model: die.plan.cores

        Item {
            id: tile

            required property var modelData
            readonly property real load: die.mean(modelData.cpus)
            readonly property color tone: load > 0.85 ? Theme.heat : modelData.kind === "e" ? Theme.blue : Theme.cyan
            readonly property real pip: Math.max(3, Math.round(die.type * 0.5))

            x: die.px(modelData.r[0])
            y: die.px(modelData.r[1])
            width: die.px(modelData.r[2]) - x
            height: die.px(modelData.r[3]) - y

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: Theme.alpha(tile.tone, 0.04 + 0.14 * tile.load)
                border.width: tile.load > 0.6 ? 1.5 : 1
                border.color: Theme.alpha(tile.tone, 0.32 + 0.68 * tile.load)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                height: Math.round((parent.height - 4) * tile.load)
                radius: 1
                color: Theme.alpha(tile.tone, 0.2 + 0.3 * tile.load)
                visible: height > 0
            }

            Text {
                x: 3
                y: 2
                text: tile.modelData.name
                visible: tile.width > die.type * 1.6
                color: Theme.alpha(Theme.fgBright, 0.6 + 0.4 * tile.load)
                font.family: Theme.mono
                font.pixelSize: Math.min(die.type, Math.floor(tile.width / 2.4))
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                textFormat: Text.PlainText
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 3
                spacing: 2
                visible: tile.width > tile.pip * 4

                Repeater {
                    model: tile.modelData.cpus

                    Rectangle {
                        required property int modelData

                        width: tile.pip
                        height: tile.pip
                        radius: 1
                        color: Qt.tint(Theme.alpha(Theme.muted, 0.3), Theme.alpha(Theme.fgBright, die.loads[modelData] ?? 0))
                    }
                }
            }
        }
    }
}
