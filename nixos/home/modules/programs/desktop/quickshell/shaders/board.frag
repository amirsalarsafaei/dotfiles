#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float lift;
    float band;
    vec2 resolution;
    vec4 frame;
    vec4 pump;
    vec4 vrmL;
    vec4 vrmT;
    vec4 dimm;
    vec4 atx;
    vec4 gpu;
    vec4 io;
    vec4 dash;
    vec4 ssd;
    vec4 eps;
    vec4 qcode;
    vec4 cmos;
    vec4 button;
    vec4 heights;
    vec4 fans;
    vec4 memA0;
    vec4 memA1;
    vec4 memB0;
    vec4 memB1;
    vec4 pcie0;
    vec4 pcie1;
    vec4 nvme0;
    vec4 nvme1;
    vec4 pwr0;
    vec4 pwr1;
    vec4 lanes0;
    vec4 lanes1;
    vec4 lanes2;
    vec4 cyan;
    vec4 rimA;
    vec4 rimB;
};

const vec2 KEY = vec2(-0.6, -0.8);
const vec2 CAST = vec2(0.46, 0.32);
const vec3 LINE = vec3(0.012, 0.016, 0.03);
const vec3 SHADE = vec3(0.6, 0.66, 0.88);
const vec3 DEEP = vec3(0.38, 0.43, 0.66);
const vec3 SHADOW = vec3(0.46, 0.52, 0.76);
const vec3 HILITE = vec3(0.86, 0.92, 1.0);
const vec3 PCB = vec3(0.062, 0.08, 0.112);
const vec3 TRACE = vec3(0.092, 0.118, 0.162);
const vec3 SILK = vec3(0.6, 0.66, 0.76);
const vec3 METAL = vec3(0.3, 0.335, 0.4);
const vec3 STEEL = vec3(0.5, 0.54, 0.61);
const vec3 PLASTIC = vec3(0.095, 0.105, 0.135);
const vec3 EPOXY = vec3(0.07, 0.077, 0.098);
const vec3 SHELL = vec3(0.115, 0.125, 0.16);
const vec3 SLEEVE = vec3(0.16, 0.175, 0.22);
const vec3 TIN = vec3(0.44, 0.47, 0.52);
const vec3 GILT = vec3(0.5, 0.44, 0.32);
const vec3 GLASS = vec3(0.012, 0.015, 0.025);
const float CHOKE_Z = 0.032;
const float CAP_Z = 0.036;
const float EPS_Z = 0.035;
const float ATX_Z = 0.05;
const float SLOT_Z = 0.014;
const float LATCH_Z = 0.026;
const float SSD_Z = 0.008;
const float COIN_Z = 0.014;
const float PORT_Z = 0.07;
const float QCODE_Z = 0.008;
const float BUTTON_Z = 0.014;

float px;
float lw;
vec3 accent;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float box(vec2 p, vec2 center, vec2 extent, float radius) {
    vec2 d = abs(p - center) - extent + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

float rect(vec2 p, vec4 r, float radius) {
    return box(p, 0.5 * (r.xy + r.zw), 0.5 * (r.zw - r.xy), radius);
}

float fill(float d) {
    return clamp(0.5 - d / px, 0.0, 1.0);
}

float stroke(float d, float width) {
    return fill(abs(d) - 0.5 * width);
}

float glowOf(float d, float radius) {
    return exp(-max(d, 0.0) / radius);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

vec4 inset(vec4 r, float by) {
    return r + vec4(by, by, -by, -by);
}

vec4 lifted(vec4 r, float z) {
    return r - vec4(0.0, lift * z, 0.0, lift * z);
}

vec4 hull(vec4 r, float z) {
    return vec4(r.x, r.y - lift * z, r.z, r.w);
}

vec3 cel(vec3 base, float dShade, float dLight) {
    vec3 c = mix(base, base * SHADE, 1.0 - fill(dShade));
    return mix(c, mix(base, HILITE, 0.42), 1.0 - fill(dLight));
}

vec3 celRect(vec3 base, vec2 b, vec4 t, float radius, float bevel) {
    return cel(base, rect(b - KEY * bevel, t, radius), rect(b + KEY * bevel * 0.5, t, radius));
}

vec3 celDisc(vec3 base, vec2 b, vec2 c, float r, float bevel) {
    return cel(base, length(b - KEY * bevel - c) - r, length(b + KEY * bevel * 0.5 - c) - r);
}

vec3 wall(vec3 base, vec2 b, vec4 r, float z) {
    return mix(base * SHADE, base * DEEP, fill(r.w - 0.4 * lift * z - b.y));
}

vec3 inked(vec3 color, vec3 c, float d, float rim, float dRim) {
    c = mix(c, accent, rim * (1.0 - fill(dRim)) * fill(d));
    c = mix(c, LINE, fill(abs(d) - 0.5 * lw));
    return mix(color, c, fill(d - 0.5 * lw));
}

vec3 block(vec3 color, vec2 b, vec4 r, float radius, float z, vec3 top, vec3 side, float rim) {
    vec4 h = hull(r, z);
    float dt = rect(b, lifted(r, z), radius);
    vec3 c = mix(side, top, fill(dt));
    c = mix(c, LINE, 0.8 * fill(abs(dt) - 0.3 * lw));
    return inked(color, c, rect(b, h, radius), rim, rect(b + vec2(0.0035, 0.0), h, radius));
}

vec3 can(vec3 color, vec2 b, vec2 c, float r, float z, vec3 top, vec3 base, float rim) {
    vec2 t = c - vec2(0.0, lift * z);
    float d = segment(b, c, t) - r;
    if (d > lw)
        return color;
    float x = (b.x - c.x) / r;
    vec3 side = base * SHADE;
    side = mix(side, base, fill((x + 0.38) * r));
    side = mix(side, base * DEEP, fill((0.42 - x) * r));
    side = mix(side, mix(base, HILITE, 0.55), fill(abs(x + 0.66) * r - 0.07 * r));
    float dt = length(b - t) - r;
    vec3 col = mix(side, top, fill(dt));
    col = mix(col, LINE, 0.8 * fill(abs(dt) - 0.3 * lw));
    return inked(color, col, d, rim, segment(b + vec2(0.003, 0.0), c, t) - r);
}

vec3 cylinder(vec3 base, float x, float r) {
    vec3 c = mix(base * SHADE, base, fill((x + 0.2) * r));
    c = mix(c, base * DEEP, fill((0.52 - x) * r));
    return mix(c, mix(base, HILITE, 0.5), fill(abs(x + 0.56) * r - 0.07 * r));
}

float castRect(vec2 b, vec4 r, float radius, float z) {
    vec2 o = CAST * z;
    return min(rect(b - o, r, radius), rect(b - 0.5 * o, r, radius));
}

float castDisc(vec2 b, vec2 c, float r, float z) {
    return segment(b, c, c + CAST * z) - r;
}

float glint(vec2 b, vec4 t, float at, float width) {
    vec2 c = 0.5 * (t.xy + t.zw);
    float span = 0.35355339 * (t.z - t.x + t.w - t.y);
    return fill(abs(dot(b - c, vec2(0.70710678)) - at * span) - width);
}

float ribs(float x, float pitch, out float shaded) {
    float f = fract(x / pitch) * pitch;
    shaded = clamp((f - 0.56 * pitch) / px + 0.5, 0.0, 1.0);
    return clamp(min(f - 0.14 * pitch, 0.82 * pitch - f) / px + 0.5, 0.0, 1.0);
}

void busFrame(vec2 p, vec2 points[4], out float lateral, out float along, out float total) {
    vec2 dirs[3];
    float lens[3];
    total = 0.0;
    for (int i = 0; i < 3; i++) {
        vec2 d = points[i + 1] - points[i];
        lens[i] = length(d);
        dirs[i] = lens[i] > 1e-5 ? d / lens[i] : vec2(0.0);
        total += lens[i];
    }
    int seg = lens[0] > 1e-5 ? 0 : lens[1] > 1e-5 ? 1 : 2;
    float offset = 0.0;
    float start = 0.0;
    for (int j = 1; j < 3; j++) {
        offset += lens[j - 1];
        if (lens[j] < 1e-5 || j <= seg)
            continue;
        vec2 n = normalize(dirs[seg] + dirs[j]);
        if (dot(p - points[j], n) >= 0.0) {
            seg = j;
            start = offset;
        }
    }
    vec2 d = dirs[seg];
    lateral = dot(p - points[seg], vec2(-d.y, d.x));
    along = start + dot(p - points[seg], d);
}

float bus(vec2 p, vec4 ab, vec4 cd, float count, float pitch, float width) {
    vec2 points[4] = vec2[4](ab.xy, ab.zw, cd.xy, cd.zw);
    float lateral;
    float along;
    float total;
    busFrame(p, points, lateral, along, total);
    float extent = 0.5 * (count - 1.0) * pitch;
    if (abs(lateral) > extent + pitch || along < -px || along > total + px)
        return 0.0;
    float lane = clamp(floor((lateral + extent) / pitch + 0.5), 0.0, count - 1.0);
    float ends = clamp(along / px + 0.5, 0.0, 1.0) * clamp((total - along) / px + 0.5, 0.0, 1.0);
    return stroke(lateral - (lane * pitch - extent), width) * ends;
}

float corridor(vec2 p, vec4 ab, vec4 cd, float count, float pitch) {
    vec2 points[4] = vec2[4](ab.xy, ab.zw, cd.xy, cd.zw);
    float lateral;
    float along;
    float total;
    busFrame(p, points, lateral, along, total);
    float reach = 0.5 * (count + 1.0) * pitch;
    return (1.0 - smoothstep(reach, reach + 0.006, abs(lateral))) * step(-0.006, along) * step(along, total + 0.006);
}

float field(vec2 q, out float via) {
    via = 0.0;
    float blockSize = 0.11;
    vec2 block = floor(q / blockSize);
    vec2 local = q - (block + 0.5) * blockSize;
    float h = hash(block * 1.37 + 4.2);
    if (h < 0.3)
        return 0.0;
    float kind = floor(hash(block + 9.1) * 4.0);
    vec2 uv = local;
    if (kind == 1.0)
        uv = vec2(local.y, -local.x);
    else if (kind == 2.0)
        uv = vec2(local.x + local.y, local.y - local.x) * 0.70710678;
    else if (kind == 3.0)
        uv = vec2(local.x - local.y, local.y + local.x) * 0.70710678;
    float pitch = 0.0072;
    float lane = floor(uv.y / pitch + 0.5);
    float center = lane * pitch;
    float r1 = hash(vec2(lane, h * 91.0));
    float r2 = hash(vec2(lane * 1.3, h * 17.0));
    float limit = blockSize * (kind >= 2.0 ? 0.52 : 0.46);
    if (abs(center) > limit)
        return 0.0;
    if (r1 < 0.32 || abs(lane - floor(hash(block + 3.3) * 9.0 - 4.0)) > 4.0 + 5.0 * hash(block + 6.6))
        return 0.0;
    float start = -limit + r2 * limit * 0.9;
    float stop = limit - hash(vec2(lane * 2.1, h * 5.0)) * limit * 0.9;
    if (stop - start < 0.012)
        return 0.0;
    float u = clamp(uv.x, start, stop);
    float trace = stroke(length(vec2(uv.x - u, uv.y - center)), 0.0021);
    float pad = min(length(uv - vec2(start, center)), length(uv - vec2(stop, center)));
    via = fill(pad - 0.0029);
    return max(trace, via);
}

vec3 smd(vec2 q, float density, inout float shade) {
    vec2 cellSize = vec2(0.0105, 0.0095);
    vec2 cell = floor(q / cellSize);
    vec2 local = q - (cell + 0.5) * cellSize;
    vec2 group = floor(cell / vec2(5.0, 3.0));
    if (hash(group + 1.9) > density * 1.6 || hash(cell + 2.7) > 0.78)
        return vec3(-1.0);
    bool cap = hash(group + 3.9) < 0.62;
    vec2 size = cap ? vec2(0.0031, 0.0016) : vec2(0.0027, 0.0014);
    bool turned = hash(group + 5.3) < 0.5;
    if (turned)
        size = size.yx;
    shade = min(shade, box(local - vec2(0.0016, 0.0011), vec2(0.0), size, 0.0003));
    float body = box(local, vec2(0.0), size, 0.0003);
    if (body > px)
        return vec3(-1.0);
    vec3 c = cap ? vec3(0.3, 0.28, 0.25) : vec3(0.05, 0.055, 0.07);
    c = mix(c, c * SHADE, step(0.0, turned ? local.x : local.y));
    c = mix(c, TIN, step((turned ? size.y : size.x) - 0.0008, turned ? abs(local.y) : abs(local.x)));
    return mix(PCB, c, fill(body));
}

vec3 chip(vec3 color, vec2 q, vec2 center, vec2 size, float pins) {
    vec2 rel = q - center;
    if (max(abs(rel.x) - size.x, abs(rel.y) - size.y) > 0.012)
        return color;
    color = mix(color, color * SHADOW, fill(box(q - vec2(0.004, 0.003), center, size, 0.0012)));
    vec2 a = abs(rel);
    float pitch = 2.0 * size.x / pins;
    float alongX = fract((rel.x + size.x) / pitch);
    float alongY = fract((rel.y + size.y) / pitch);
    float legX = step(size.y, a.y) * step(a.y, size.y + 0.0034) * step(a.x, size.x - pitch * 0.5) * step(0.3, alongX) * step(alongX, 0.7);
    float legY = step(size.x, a.x) * step(a.x, size.x + 0.0034) * step(a.y, size.y - pitch * 0.5) * step(0.3, alongY) * step(alongY, 0.7);
    color = mix(color, TIN, max(legX, legY));
    vec4 r = vec4(center - size, center + size);
    vec3 c = celRect(EPOXY, q, r, 0.0012, 0.0025);
    c = mix(c, EPOXY * 0.55, fill(length(rel + size * 0.68) - 0.0017));
    c = mix(c, SILK * 0.4, 0.5 * stroke(rel.y + size.y * 0.1, 0.0009) * step(a.x, size.x * 0.55));
    return inked(color, c, rect(q, r, 0.0012), 0.0, 1.0);
}

float ghostDigit(vec2 p) {
    vec2 segs[7] = vec2[7](vec2(0.0, -1.0), vec2(0.5, -0.5), vec2(0.5, 0.5), vec2(0.0, 1.0), vec2(-0.5, 0.5), vec2(-0.5, -0.5), vec2(0.0, 0.0));
    float m = 0.0;
    for (int i = 0; i < 7; i++) {
        bool vertical = (i == 1 || i == 2 || i == 4 || i == 5);
        m = max(m, clamp(0.5 - box(p, segs[i], vertical ? vec2(0.09, 0.4) : vec2(0.4, 0.09), 0.08) * 30.0, 0.0, 1.0));
    }
    return m;
}

vec3 heatsink(vec3 color, vec2 b, vec4 r, float z) {
    if (rect(b, hull(r, z), 0.006) > lw)
        return color;
    vec4 t = lifted(r, z);
    vec4 inner = vec4(t.x + 0.007, t.y + 0.008, t.z - 0.007, t.w - 0.007);
    float shaded;
    float fin = ribs(b.x - t.x, 0.0105, shaded);
    vec3 top = celRect(METAL, b, t, 0.006, 0.006);
    vec3 fins = mix(METAL * 1.08, METAL * SHADE, shaded);
    fins = mix(METAL * DEEP * 0.62, fins, fin);
    top = mix(top, fins, fill(rect(b, inner, 0.002)));
    top = mix(top, LINE, 0.5 * stroke(rect(b, inner, 0.002), 0.6 * lw));
    top = mix(top, HILITE, 0.32 * clamp(glint(b, t, -0.55, 0.014) + 0.8 * glint(b, t, -0.2, 0.004), 0.0, 1.0));
    vec3 side = wall(METAL, b, r, z);
    float within = step(inner.x, b.x) * step(b.x, inner.z);
    side = mix(side, METAL * DEEP * 0.5, (1.0 - fin) * within * fill(r.w - lift * z * 0.85 - b.y));
    return block(color, b, r, 0.006, z, top, side, 0.55);
}

vec4 chokeRect(int i, bool column) {
    float s = 0.0155;
    vec2 c = column ? vec2(vrmL.z + 0.03, vrmL.y + 0.04 + float(i) * (vrmL.w - vrmL.y - 0.07) / 5.0) : vec2(vrmT.x + 0.04 + float(i) * (vrmT.z - vrmT.x - 0.075) / 5.0, vrmT.w + 0.023);
    return vec4(c - s, c + s);
}

vec2 capAt(int i, bool column) {
    return column ? vec2(vrmL.z + 0.062, vrmL.y + 0.068 + float(i) * (vrmL.w - vrmL.y - 0.07) / 5.0) : vec2(vrmT.x + 0.072 + float(i) * (vrmT.z - vrmT.x - 0.075) / 5.0, vrmT.w + 0.052);
}

vec3 choke(vec3 color, vec2 b, vec4 r) {
    if (rect(b, hull(r, CHOKE_Z), 0.003) > lw)
        return color;
    vec3 base = vec3(0.18, 0.19, 0.23);
    vec4 t = lifted(r, CHOKE_Z);
    vec3 top = celRect(base, b, t, 0.003, 0.004);
    vec2 c = 0.5 * (t.xy + t.zw);
    top = mix(top, vec3(0.1, 0.11, 0.14), stroke(box(b, c, vec2(0.0085), 0.002), 0.0012));
    top = mix(top, SILK * 0.6, 0.6 * fill(box(b, c, vec2(0.0042, 0.0007), 0.0)));
    return block(color, b, r, 0.003, CHOKE_Z, top, wall(base, b, r, CHOKE_Z), 0.3);
}

vec3 polymer(vec3 color, vec2 b, vec2 c, float r) {
    vec2 t = c - vec2(0.0, lift * CAP_Z);
    if (segment(b, c, t) - r > lw)
        return color;
    vec3 top = celDisc(STEEL, b, t, r, 0.0028);
    vec2 rel = b - t;
    top = mix(top, STEEL * DEEP, fill(min(abs(rel.x), abs(rel.y)) - 0.0005) * step(length(rel), r * 0.6));
    top = mix(top, HILITE, fill(length(rel + vec2(0.36, 0.42) * r) - 0.18 * r));
    vec3 col = can(color, b, c, r, CAP_Z, top, STEEL * 0.92, 0.35);
    float band = fill(abs(b.y - (c.y - 0.55 * lift * CAP_Z)) - 0.0018) * fill(abs(b.x - c.x) - r) * (1.0 - fill(length(b - t) - r));
    return mix(col, vec3(0.1, 0.13, 0.22), band * 0.85);
}

vec3 wires(vec2 b, float k, float pitch, float lengthwise) {
    float x = k * 2.0 - 1.0;
    vec3 w = cylinder(SLEEVE, x, 0.5 * pitch);
    w *= 0.9 + 0.1 * step(0.5, fract((lengthwise + k * 0.01) / 0.006));
    return mix(LINE, w, clamp(min(k, 1.0 - k) * pitch / px - 0.6, 0.0, 1.0));
}

vec3 board(vec3 color, vec2 b) {
    vec4 outline = vec4(0.0, 0.0, 1.0, 1.7);
    float dBoard = rect(b, outline, 0.014);
    color = mix(color, color * SHADOW * 0.72, fill(rect(b - vec2(0.022, 0.016), outline, 0.014)));
    if (dBoard > lw)
        return color;

    vec3 c = PCB * (1.1 - 0.16 * length(b - vec2(0.15, 0.0)));
    vec2 pourSize = vec2(0.14, 0.09);
    vec2 pourCell = floor(b / pourSize);
    float pourD = box(b, (pourCell + 0.5) * pourSize, pourSize * 0.5 - 0.005, 0.008);
    float pour = step(0.62, hash(pourCell + 0.7)) * fill(pourD);
    c = mix(c, c * 1.22, pour);
    c = mix(c, c * 0.8, pour * stroke(pourD, 0.0012));

    float via;
    float trace = field(b, via);
    float near = min(min(rect(b, pump, 0.05), rect(b, dimm, 0.0)), min(rect(b, ssd, 0.003), rect(b, atx, 0.004)));
    near = min(near, min(rect(b, vrmL, 0.0), rect(b, vrmT, 0.0)));
    float lanes = max(corridor(b, memA0, memA1, lanes0.x, lanes1.y), corridor(b, memB0, memB1, lanes0.y, lanes1.y));
    lanes = max(lanes, max(corridor(b, pcie0, pcie1, lanes0.z, lanes1.y), corridor(b, nvme0, nvme1, lanes0.w, lanes1.y)));
    lanes = max(lanes, corridor(b, pwr0, pwr1, lanes1.x, lanes2.x));
    float clear = smoothstep(0.004, 0.012, near) * (1.0 - lanes);
    c = mix(c, TRACE * (1.0 + 0.2 * pour), trace * clear);
    c = mix(c, TIN * 0.7, via * clear);

    float copper = bus(b, memA0, memA1, lanes0.x, lanes1.y, lanes1.z);
    copper = max(copper, bus(b, memB0, memB1, lanes0.y, lanes1.y, lanes1.z));
    copper = max(copper, bus(b, pcie0, pcie1, lanes0.z, lanes1.y, lanes1.z));
    copper = max(copper, bus(b, nvme0, nvme1, lanes0.w, lanes1.y, lanes1.z));
    copper = max(copper, bus(b, pwr0, pwr1, lanes1.x, lanes2.x, lanes2.y));
    c = mix(c, TRACE * 1.25, copper);

    vec2 pc = 0.5 * (pump.xy + pump.zw);
    vec2 ph = 0.5 * (pump.zw - pump.xy) + 0.014;
    vec2 pr = abs(b - pc);
    float silk = stroke(box(b, pc, ph, 0.02), 0.0014) * step(ph.x - 0.04, pr.x) * step(ph.y - 0.04, pr.y);
    silk = max(silk, stroke(rect(b, inset(dimm, -0.007), 0.004), 0.0012) * 0.7);
    silk = max(silk, stroke(rect(b, inset(ssd, -0.006), 0.003), 0.0012));
    silk = max(silk, stroke(rect(b, inset(atx, -0.006), 0.003), 0.0012) * 0.8);
    vec4 audio = vec4(-0.02, io.w + 0.006, vrmL.z + 0.02, gpu.y + 0.2);
    silk = max(silk, stroke(rect(b, audio, 0.012), 0.0013) * step(0.5, fract((b.x + b.y) / 0.012)));
    c = mix(c, SILK, 0.5 * silk);

    float dens = 0.07;
    dens += 0.5 * (1.0 - smoothstep(0.0, 0.05, rect(b, pump, 0.05)));
    dens += 0.25 * (1.0 - smoothstep(0.0, 0.03, rect(b, dimm, 0.0)));
    dens += 0.25 * (1.0 - smoothstep(0.0, 0.025, rect(b, ssd, 0.0)));
    dens += 0.2 * (1.0 - smoothstep(0.0, 0.03, rect(b, vrmL, 0.0)));
    dens *= smoothstep(0.003, 0.012, near) * (1.0 - lanes);
    float shade = 1.0;
    vec3 part = smd(b, dens, shade);
    c = mix(c, c * SHADOW, fill(shade));
    if (part.x >= 0.0)
        c = part;

    c = chip(c, b, vec2(audio.x + 0.07, audio.y + 0.03), vec2(0.013, 0.013), 8.0);
    c = chip(c, b, vec2(pump.x - 0.02, pump.w - 0.015), vec2(0.009, 0.009), 5.0);
    c = chip(c, b, vec2(dimm.z - 0.012, dimm.w + 0.052), vec2(0.015, 0.015), 8.0);
    c = chip(c, b, vec2(dimm.x + 0.112, dimm.w + 0.055), vec2(0.009, 0.006), 4.0);

    for (int i = 0; i < 3; i++) {
        vec2 hole = i == 0 ? vec2(0.03, 0.03) : i == 1 ? vec2(0.5 * (vrmT.z + dimm.x), vrmT.w + 0.022) : vec2(0.972, dimm.w + 0.03);
        vec3 ring = celDisc(TIN, b, hole, 0.011, 0.003);
        ring = mix(ring, color * 0.9, fill(length(b - hole) - 0.0062));
        ring = mix(ring, LINE, stroke(length(b - hole) - 0.0062, 0.7 * lw));
        c = inked(c, ring, length(b - hole) - 0.011, 0.0, 1.0);
    }

    vec2 hc = vec2(dimm.x + 0.14, dimm.w + 0.055);
    vec4 xtal = vec4(hc - vec2(0.01, 0.0065), hc + vec2(0.01, 0.0065));
    c = mix(c, c * SHADOW, fill(rect(b - vec2(0.003, 0.002), xtal, 0.003)));
    c = inked(c, celRect(STEEL, b, xtal, 0.003, 0.0025), rect(b, xtal, 0.003), 0.0, 1.0);

    c = mix(c, mix(PCB, HILITE, 0.3), (1.0 - fill(rect(b + KEY * 0.0028, outline, 0.014))) * fill(dBoard));
    return inked(color, c, dBoard, 0.0, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);
    vec2 b = (p - frame.xy) / frame.z;
    px = 1.0 / max(resolution.y, 1.0) / frame.z;
    lw = max(1.6 * px, 0.0013);
    accent = mix(rimA.rgb, rimB.rgb, 0.5 + 0.5 * sin(b.x * 2.4 - b.y * 1.3));

    vec3 color = mix(vec3(0.024, 0.03, 0.047), vec3(0.05, 0.063, 0.094), smoothstep(1.7, 0.0, length(p - vec2(0.55, -0.3))));
    color += rimA.rgb * 0.01;
    vec2 ray = normalize(vec2(1.0, 0.72));
    float across = dot(p - vec2(0.3, 0.0), vec2(-ray.y, ray.x));
    float along = dot(p, ray);
    float shafts = smoothstep(0.07, 0.0, abs(across + 0.18) - 0.03) + 0.7 * smoothstep(0.05, 0.0, abs(across + 0.02) - 0.015) + 0.5 * smoothstep(0.09, 0.0, abs(across - 0.2) - 0.05);
    color += vec3(0.05, 0.065, 0.095) * 0.32 * shafts * exp(-max(along, 0.0) * 0.9);
    vec2 grid = fract(p / 0.034) * 0.034 - 0.017;
    color += vec3(0.022, 0.028, 0.042) * clamp(0.5 - (length(grid) - 0.0015) * resolution.y, 0.0, 1.0);

    color = board(color, b);

    float slotPitch = (dimm.z - dimm.x - 0.04) / 3.0;
    float sh = 1e9;
    sh = min(sh, castRect(b, eps, 0.003, EPS_Z));
    sh = min(sh, castRect(b, vrmT, 0.006, heights.z));
    sh = min(sh, castRect(b, vrmL, 0.006, heights.z));
    sh = min(sh, castRect(b, io, 0.012, heights.w));
    sh = min(sh, castRect(b, vec4(io.x - 0.035, io.y + 0.02, io.x, io.w - 0.04), 0.004, PORT_Z));
    sh = min(sh, castRect(b, pump, 0.05, heights.x));
    sh = min(sh, castRect(b, atx, 0.004, ATX_Z));
    sh = min(sh, castRect(b, ssd, 0.003, SSD_Z));
    sh = min(sh, castDisc(b, cmos.xy, cmos.z, COIN_Z));
    sh = min(sh, castDisc(b, button.xy, button.z, BUTTON_Z));
    sh = min(sh, castRect(b, qcode, 0.002, QCODE_Z));
    for (int i = 0; i < 4; i++) {
        float sx = dimm.x + float(i) * slotPitch;
        sh = min(sh, castRect(b, vec4(sx + 0.007, dimm.y + 0.012, sx + 0.033, dimm.w - 0.012), 0.002, heights.y));
        sh = min(sh, castRect(b, vec4(sx, dimm.y, sx + 0.04, dimm.w), 0.002, SLOT_Z));
    }
    for (int i = 0; i < 6; i++) {
        sh = min(sh, castRect(b, chokeRect(i, false), 0.003, CHOKE_Z));
        sh = min(sh, castRect(b, chokeRect(i, true), 0.003, CHOKE_Z));
        sh = min(sh, castDisc(b, capAt(i, false), 0.0092, CAP_Z));
        if (i < 5)
            sh = min(sh, castDisc(b, capAt(i, true), 0.0092, CAP_Z));
    }
    sh = min(sh, castDisc(b, vec2(vrmT.x - 0.032, eps.y + 0.006), 0.0085, CAP_Z));
    sh = min(sh, castDisc(b, vec2(vrmT.x - 0.012, eps.y + 0.006), 0.0085, CAP_Z));
    color = mix(color, color * SHADOW, fill(sh));

    for (int i = 0; i < 4; i++) {
        float sx = dimm.x + float(i) * slotPitch;
        vec4 slot = vec4(sx, dimm.y, sx + 0.04, dimm.w);
        if (rect(b, hull(slot, SLOT_Z), 0.002) < lw) {
            vec4 t = lifted(slot, SLOT_Z);
            vec3 top = celRect(PLASTIC, b, t, 0.002, 0.003);
            top = mix(top, PLASTIC * 0.5, fill(rect(b, vec4(sx + 0.012, t.y + 0.02, sx + 0.028, t.w - 0.02), 0.001)));
            color = block(color, b, slot, 0.002, SLOT_Z, top, wall(PLASTIC, b, slot, SLOT_Z), 0.0);
        }
        for (int e = 0; e < 2; e++) {
            vec4 latch = e == 0 ? vec4(sx - 0.002, dimm.y - 0.006, sx + 0.042, dimm.y + 0.016) : vec4(sx - 0.002, dimm.w - 0.016, sx + 0.042, dimm.w + 0.006);
            if (rect(b, hull(latch, LATCH_Z), 0.003) < lw) {
                vec3 base = vec3(0.4, 0.43, 0.5);
                color = block(color, b, latch, 0.003, LATCH_Z, celRect(base, b, lifted(latch, LATCH_Z), 0.003, 0.003), wall(base, b, latch, LATCH_Z), 0.0);
            }
        }
    }

    {
        vec4 t = lifted(eps, EPS_Z);
        float pitch = (eps.z - eps.x) / 4.0;
        if (b.y < t.y + 0.004 && b.x > eps.x && b.x < eps.z) {
            vec3 w = wires(b, fract((b.x - eps.x) / pitch), pitch, b.y);
            vec4 comb = vec4(eps.x - 0.003, t.y - 0.035, eps.z + 0.003, t.y - 0.025);
            color = inked(w, celRect(PLASTIC * 1.4, b, comb, 0.002, 0.002), rect(b, comb, 0.002), 0.0, 1.0);
        }
        if (rect(b, hull(eps, EPS_Z), 0.003) < lw) {
            vec3 top = celRect(PLASTIC, b, t, 0.003, 0.003);
            vec2 cell = (b - t.xy) / (t.zw - t.xy) * vec2(4.0, 2.0);
            top = mix(top, PLASTIC * 0.4, fill(box(fract(cell) - 0.5, vec2(0.0), vec2(0.3), 0.08) * pitch));
            color = block(color, b, eps, 0.003, EPS_Z, top, wall(PLASTIC, b, eps, EPS_Z), 0.0);
        }
    }
    for (int i = 0; i < 2; i++)
        color = polymer(color, b, vec2(vrmT.x - 0.032 + float(i) * 0.02, eps.y + 0.006), 0.0085);

    if (rect(b, hull(qcode, QCODE_Z), 0.002) < lw) {
        vec4 t = lifted(qcode, QCODE_Z);
        vec3 top = celRect(PLASTIC, b, t, 0.002, 0.002);
        vec4 win = inset(t, 0.004);
        float hgt = win.w - win.y;
        vec3 glass = GLASS;
        for (int i = 0; i < 2; i++) {
            vec2 local = (b - vec2(win.x + (win.z - win.x) * (0.28 + 0.44 * float(i)), win.y + hgt * 0.5)) / (hgt * 0.38);
            local.x += local.y * 0.12;
            glass += cyan.rgb * 0.07 * ghostDigit(local);
        }
        top = mix(top, glass, fill(rect(b, win, 0.0015)));
        top = mix(top, HILITE, 0.18 * glint(b, win, -0.4, 0.004) * fill(rect(b, win, 0.0015)));
        color = block(color, b, qcode, 0.002, QCODE_Z, top, wall(PLASTIC, b, qcode, QCODE_Z), 0.0);
    }

    {
        vec2 c = button.xy;
        vec2 t = c - vec2(0.0, lift * BUTTON_Z);
        vec3 top = celDisc(STEEL, b, t, button.z, 0.003);
        top = mix(top, STEEL * DEEP, fill(box(b, t - vec2(0.0, button.z * 0.12), vec2(0.0011, button.z * 0.32), 0.0005)));
        top = mix(top, GLASS, stroke(length(b - t) - button.z * 0.62, 0.0026));
        color = can(color, b, c, button.z, BUTTON_Z, top, STEEL * 0.85, 0.2);
        vec2 rc = c + vec2(button.z * 2.6, 0.0);
        vec3 grey = vec3(0.22, 0.24, 0.3);
        color = can(color, b, rc, button.z * 0.62, 0.012, celDisc(grey, b, rc - vec2(0.0, lift * 0.012), button.z * 0.62, 0.002), grey, 0.0);
    }

    {
        vec4 hdr = vec4(vrmT.z + 0.018, vrmT.y + 0.006, vrmT.z + 0.05, vrmT.y + 0.02);
        if (rect(b, hull(hdr, 0.018), 0.001) < lw) {
            vec4 t = lifted(hdr, 0.018);
            vec3 top = celRect(PLASTIC * 1.2, b, t, 0.001, 0.002);
            float pitch = (t.z - t.x) / 4.0;
            vec2 pin = vec2((fract((b.x - t.x) / pitch) - 0.5) * pitch, b.y - 0.5 * (t.y + t.w));
            top = mix(top, GILT, fill(box(pin, vec2(0.0), vec2(0.0013), 0.0003)));
            color = block(color, b, hdr, 0.001, 0.018, top, wall(PLASTIC * 1.2, b, hdr, 0.018), 0.0);
        }
    }

    color = heatsink(color, b, vrmT, heights.z);
    for (int i = 0; i < 6; i++)
        color = choke(color, b, chokeRect(i, false));
    for (int i = 0; i < 6; i++)
        color = polymer(color, b, capAt(i, false), 0.0092);

    if (rect(b, io, 0.012) < 0.08) {
        for (int i = 0; i < 5; i++) {
            float y0 = io.y + 0.035 + float(i) * (io.w - io.y - 0.08) / 5.0;
            vec4 port = vec4(io.x - 0.034, y0, io.x + 0.004, y0 + (i == 4 ? 0.06 : 0.05));
            if (rect(b, hull(port, PORT_Z), 0.003) < lw) {
                vec4 t = lifted(port, PORT_Z);
                vec3 base = i == 4 ? vec3(0.32, 0.35, 0.42) : STEEL * 0.8;
                vec3 top = celRect(base, b, t, 0.003, 0.003);
                top = mix(top, PLASTIC * 0.5, fill(rect(b, vec4(t.x + 0.006, t.y + 0.008, t.z - 0.01, t.w - 0.008), 0.002)));
                color = block(color, b, port, 0.003, PORT_Z, top, wall(base, b, port, PORT_Z), 0.0);
            }
        }
        if (rect(b, hull(io, heights.w), 0.012) < lw) {
            vec4 t = lifted(io, heights.w);
            vec3 shell = mix(SHELL, METAL, 0.3);
            vec3 top = celRect(shell, b, t, 0.012, 0.006);
            vec4 bezel = inset(dash, -0.0045);
            float dBezel = rect(b, bezel, 0.009);
            float dScreen = rect(b, dash, 0.006);
            top = mix(top, top * SHADOW, fill(rect(b - vec2(0.002, 0.0015), bezel, 0.009)) * (1.0 - fill(dBezel)));
            top = mix(top, celRect(SHELL * 0.82, b, bezel, 0.009, 0.003), fill(dBezel));
            top = mix(top, LINE, fill(abs(dBezel) - 0.4 * lw));
            top = mix(top, GLASS, fill(dScreen));
            top = mix(top, LINE, stroke(dScreen, 0.6 * lw));
            float ledY = bezel.w + 0.008;
            float led = fill(abs(b.y - ledY) - 0.0012) * step(bezel.x + 0.004, b.x) * step(b.x, bezel.z - 0.004);
            top = mix(top, accent * 0.8 + 0.1 * HILITE, led);
            top += accent * 0.08 * glowOf(abs(b.y - ledY), 0.005) * (1.0 - led) * (1.0 - fill(dBezel)) * fill(rect(b, t, 0.012));
            float slit = fill(abs(fract((b.x - t.x) / 0.0065) - 0.5) * 0.0065 - 0.0013) * step(t.x + 0.014, b.x) * step(b.x, t.z - 0.014) * step(t.w - 0.017, b.y) * step(b.y, t.w - 0.007);
            top = mix(top, shell * DEEP * 0.55, slit);
            top = mix(top, HILITE, 0.22 * glint(b, t, -0.62, 0.012) * (1.0 - fill(dBezel)));
            color = block(color, b, io, 0.012, heights.w, top, wall(shell, b, io, heights.w), 0.6);
        }
    }

    color = heatsink(color, b, vrmL, heights.z);
    for (int i = 0; i < 6; i++)
        color = choke(color, b, chokeRect(i, true));
    for (int i = 0; i < 5; i++)
        color = polymer(color, b, capAt(i, true), 0.0092);

    if (rect(b, atx, 0.004) < 0.5) {
        vec4 t = lifted(atx, ATX_Z);
        float rowH = (t.w - t.y) / 12.0;
        if (b.x > t.z - 0.004 && b.y > t.y && b.y < t.w) {
            vec3 w = wires(b, fract((b.y - t.y) / rowH), rowH, b.x);
            vec4 comb = vec4(t.z + 0.065, t.y - 0.003, t.z + 0.075, t.w + 0.003);
            color = inked(w, celRect(PLASTIC * 1.4, b, comb, 0.002, 0.002), rect(b, comb, 0.002), 0.0, 1.0);
        }
        if (rect(b, hull(atx, ATX_Z), 0.004) < lw) {
            vec3 top = celRect(PLASTIC, b, t, 0.004, 0.003);
            vec2 f = (fract((b - t.xy) / (t.zw - t.xy) * vec2(2.0, 12.0)) - 0.5) * vec2((t.z - t.x) / 2.0, rowH);
            top = mix(top, PLASTIC * 0.4, fill(box(f, vec2(0.0), vec2(0.3 * rowH), 0.0008)));
            color = block(color, b, atx, 0.004, ATX_Z, top, wall(PLASTIC, b, atx, ATX_Z), 0.0);
        }
        vec4 usb = vec4(atx.x, atx.w + 0.03, atx.z, atx.w + 0.1);
        if (rect(b, hull(usb, 0.024), 0.003) < lw) {
            vec4 ut = lifted(usb, 0.024);
            vec3 top = celRect(PLASTIC * 1.1, b, ut, 0.003, 0.003);
            top = mix(top, PLASTIC * 0.45, fill(rect(b, inset(ut, 0.008), 0.002)));
            color = block(color, b, usb, 0.003, 0.024, top, wall(PLASTIC * 1.1, b, usb, 0.024), 0.0);
        }
    }

    for (int i = 0; i < 4; i++) {
        float sx = dimm.x + float(i) * slotPitch;
        vec4 module = vec4(sx + 0.007, dimm.y + 0.012, sx + 0.033, dimm.w - 0.012);
        float z = heights.y;
        if (rect(b, hull(module, z), 0.002) > lw)
            continue;
        vec4 t = lifted(module, z);
        vec3 spreader = vec3(0.1, 0.11, 0.145);
        vec3 top = celRect(spreader, b, t, 0.002, 0.004);
        vec4 bar = vec4(t.x + 0.0075, t.y + 0.012, t.z - 0.0075, t.w - 0.012);
        vec4 channel = inset(bar, -0.0017);
        float rail = max(fill(rect(b, vec4(t.x, t.y, channel.x - 0.0008, t.w), 0.002)), fill(rect(b, vec4(channel.z + 0.0008, t.y, t.z, t.w), 0.002)));
        vec3 alu = celRect(METAL * 1.12, b, t, 0.002, 0.003);
        alu = mix(alu, alu * SHADE, 0.45 * step(0.5, fract((b.y - t.y) / 0.008)));
        top = mix(top, alu, rail);
        top = mix(top, spreader * DEEP * 0.55, fill(rect(b, channel, 0.003)));
        top = mix(top, LINE, stroke(rect(b, channel, 0.003), 0.5 * lw));
        top = mix(top, GLASS, fill(rect(b, bar, 0.002)));
        top = mix(top, HILITE, 0.28 * glint(b, t, -0.7, 0.006) * (1.0 - fill(rect(b, channel, 0.003))));
        vec3 side = wall(spreader, b, module, z);
        vec4 label = vec4(module.x + 0.004, module.w - lift * z + 0.008, module.z - 0.004, module.w - 0.01);
        side = mix(side, SILK * 0.42, fill(rect(b, label, 0.001)) * 0.8);
        side = mix(side, LINE, 0.6 * fill(abs(b.y - 0.5 * (label.y + label.w)) - 0.0006) * fill(rect(b, inset(label, 0.003), 0.0)));
        color = block(color, b, module, 0.002, z, top, side, 0.5);
    }

    vec2 pc = 0.5 * (pump.xy + pump.zw);
    {
        float z = heights.x;
        vec4 t = lifted(pump, z);
        float d = rect(b, hull(pump, z), 0.05);
        if (d < lw) {
            vec3 top = celRect(SHELL, b, t, 0.05, 0.01);
            vec4 bz = inset(t, 0.009);
            float dBezel = rect(b, bz, 0.042);
            vec3 bezel = celRect(STEEL, b, bz, 0.042, 0.005);
            bezel = mix(bezel, HILITE, 0.5 * clamp(glint(b, bz, -0.62, 0.012) + glint(b, bz, -0.4, 0.003), 0.0, 1.0));
            top = mix(top, bezel, fill(dBezel));
            top = mix(top, LINE, fill(abs(dBezel) - 0.3 * lw));
            top = mix(top, GLASS, fill(rect(b, inset(t, 0.016), 0.035)));
            top = mix(top, vec3(0.0), fill(rect(b, inset(t, 0.022), 0.03)));
            vec3 side = wall(SHELL, b, pump, z);
            side = mix(side, GLASS, fill(abs(b.y - (pump.w - lift * z * 0.55)) - 0.0026));
            color = block(color, b, pump, 0.05, z, top, side, 0.7);
        }
    }

    {
        float r = 0.017;
        float y = pump.y - lift * heights.x + 0.03;
        float tsh = 1e9;
        for (int i = 0; i < 2; i++) {
            float x = pc.x + (i == 0 ? -0.05 : 0.03);
            tsh = min(tsh, rect(b - vec2(0.032, 0.0), vec4(x - r, -0.6, x + r, y - 0.01), r));
        }
        color = mix(color, color * SHADOW, fill(tsh) * step(b.y, y));
        for (int i = 0; i < 2; i++) {
            float x = pc.x + (i == 0 ? -0.05 : 0.03);
            float dTube = rect(b, vec4(x - r, -0.6, x + r, y - 0.02), 0.004);
            if (dTube < lw) {
                float k = (b.x - x) / r;
                vec3 c = cylinder(vec3(0.13, 0.145, 0.185), k, r);
                c = mix(c, mix(vec3(0.13, 0.145, 0.185), accent, 0.6), 0.6 * fill(abs(k - 0.8) * r - 0.0012));
                c *= 0.92 + 0.08 * step(0.5, fract((b.y + b.x) / 0.007));
                color = inked(color, c, dTube, 0.0, 1.0);
            }
            vec4 fit = vec4(x - r - 0.004, y - 0.028, x + r + 0.004, y + 0.004);
            float dFit = rect(b, fit, 0.004);
            if (dFit < lw) {
                vec3 c = celRect(STEEL, b, fit, 0.004, 0.003);
                c = mix(c, STEEL * DEEP, stroke(b.y - fit.y - 0.009, 0.0016));
                c = mix(c, HILITE, 0.5 * fill(abs(b.x - fit.x - 0.007) - 0.0016));
                color = inked(color, c, dFit, 0.3, rect(b + vec2(0.003, 0.0), fit, 0.004));
            }
        }
    }

    if (rect(b, hull(ssd, SSD_Z), 0.003) < lw) {
        vec4 t = lifted(ssd, SSD_Z);
        vec3 pcb = vec3(0.05, 0.06, 0.085);
        vec3 top = celRect(pcb, b, t, 0.003, 0.002);
        float hgt = t.w - t.y;
        float fingers = step(b.x, t.x + 0.012) * step(0.5, fract((b.y - t.y) / 0.004)) * step(t.y + 0.004, b.y) * step(b.y, t.w - 0.004);
        top = mix(top, GILT, fingers);
        vec4 ctrl = vec4(t.x + 0.028, t.y + 0.008, t.x + 0.028 + hgt * 0.7, t.w - 0.008);
        vec4 dram = vec4(ctrl.z + 0.012, t.y + 0.01, ctrl.z + 0.034, t.w - 0.01);
        float len = t.z - t.x;
        vec4 nandA = vec4(dram.z + 0.014, t.y + 0.005, dram.z + 0.014 + len * 0.22, t.w - 0.005);
        vec4 nandB = vec4(nandA.z + 0.01, t.y + 0.005, nandA.z + 0.01 + len * 0.22, t.w - 0.005);
        for (int i = 0; i < 4; i++) {
            vec4 r = i == 0 ? ctrl : i == 1 ? dram : i == 2 ? nandA : nandB;
            top = mix(top, top * SHADOW, fill(rect(b - vec2(0.0025, 0.0018), r, 0.0012)));
            top = inked(top, celRect(EPOXY, b, r, 0.0012, 0.0022), rect(b, r, 0.0012), 0.0, 1.0);
        }
        vec2 sc = vec2(t.z - 0.007, 0.5 * (t.y + t.w));
        vec3 screw = celDisc(STEEL, b, sc, 0.006, 0.002);
        screw = mix(screw, STEEL * DEEP, fill(box(b, sc, vec2(0.0035, 0.0007), 0.0)));
        top = inked(top, screw, length(b - sc) - 0.006, 0.0, 1.0);
        color = block(color, b, ssd, 0.003, SSD_Z, top, wall(pcb, b, ssd, SSD_Z), 0.0);
    }

    if (length(b - cmos.xy) < cmos.z + 0.06) {
        vec2 c = cmos.xy;
        float r = cmos.z;
        vec2 base = c - vec2(0.0, lift * 0.006);
        color = inked(color, celDisc(PLASTIC, b, base, r + 0.0045, 0.002), segment(b, c, base) - r - 0.0045, 0.0, 1.0);
        vec2 t = c - vec2(0.0, lift * COIN_Z);
        vec3 top = celDisc(STEEL * 1.05, b, t, r, 0.004);
        top = mix(top, STEEL * SHADE, stroke(length(b - t) - r * 0.8, 0.0012));
        top = mix(top, STEEL * DEEP, fill(min(box(b, t, vec2(0.0065, 0.0012), 0.0), box(b, t, vec2(0.0012, 0.0065), 0.0))));
        top = mix(top, HILITE, 0.6 * fill(length(b - t + vec2(0.36, 0.44) * r) - 0.16 * r));
        top = mix(top, HILITE, 0.35 * glint(b, vec4(t - r, t + r), -0.3, 0.003) * fill(length(b - t) - r));
        color = can(color, b, c, r, COIN_Z, top, STEEL * 0.9, 0.3);
        vec4 xt = vec4(c.x + r + 0.012, c.y - 0.004, c.x + r + 0.03, c.y + 0.004);
        color = mix(color, color * SHADOW, fill(rect(b - vec2(0.002, 0.0015), xt, 0.004)));
        vec3 xc = celRect(STEEL, b, xt, 0.004, 0.0015);
        xc = mix(xc, STEEL * DEEP, stroke(b.x - xt.z + 0.004, 0.0009));
        color = inked(color, xc, rect(b, xt, 0.004), 0.0, 1.0);
    }

    float dG = rect(b, gpu, 0.02);
    if (dG < 0.06) {
        color = mix(color, color * SHADOW * 0.85, fill(rect(b - vec2(0.03, 0.02), gpu, 0.02)) * (1.0 - fill(dG)));
        color += accent * 0.12 * glowOf(abs(b.y - gpu.y), 0.012) * step(gpu.x + 0.03, b.x) * (1.0 - fill(dG));
    }
    if (dG < lw) {
        vec3 face = vec3(0.14, 0.155, 0.195);
        vec3 c = celRect(face, b, gpu, 0.02, 0.008);
        vec4 plate = vec4(gpu.x + 0.03, gpu.y, gpu.z, gpu.y + band);
        vec3 plateC = celRect(METAL * 0.95, b, plate, 0.004, 0.004);
        plateC = mix(plateC, HILITE, 0.3 * glint(b, vec4(gpu.x, gpu.y, gpu.x + 0.4, gpu.y + band), -0.4, 0.006));
        c = mix(c, plateC, fill(rect(b, plate, 0.004)));
        c = mix(c, LINE, fill(abs(rect(b, plate, 0.004)) - 0.35 * lw) * step(gpu.y + 0.004, b.y));
        c = mix(c, GLASS, fill(abs(b.y - gpu.y - 0.0035) - 0.0018) * step(gpu.x + 0.03, b.x));

        float R = fans.w;
        float pitch = fans.z;
        float fanY = fans.y;
        float fi = floor((b.x - fans.x) / pitch);
        float fx = fans.x + (fi + 0.5) * pitch;
        float facet = (b.x - fans.x - (fi + 1.0) * pitch) + (b.y - fanY) * 0.45;
        c = mix(c, face * SHADE, fill(-facet) * step(gpu.y + band, b.y) * step(0.0, b.x - fx));
        c = mix(c, LINE, 0.7 * fill(abs(facet) - 0.4 * lw) * step(gpu.y + band, b.y));
        float vents = step(0.5, fract((b.x - b.y * 0.5) / 0.008)) * step(gpu.y + band + 0.01, b.y) * step(abs(b.x - fx), pitch * 0.5) * step(R * 1.18, length(b - vec2(fx, fanY))) * step(abs(b.y - fanY), R * 0.7) * step(0.0, b.x - fx);
        c = mix(c, face * DEEP * 0.7, vents * 0.5);

        vec2 fr = b - vec2(fx, fanY);
        float rr = length(fr);
        if (fi >= 0.0 && rr < R * 1.2) {
            float well = rr - R * 1.12;
            c = mix(c, vec3(0.03, 0.035, 0.05), fill(well));
            c = mix(c, LINE, fill(abs(well) - 0.5 * lw));
            c = mix(c, mix(face, HILITE, 0.35), fill(abs(well - 0.0035) - 0.0013) * step(0.0, -dot(fr, KEY)));
            float rim = rr - R * 1.04;
            c = mix(c, vec3(0.06, 0.07, 0.09), fill(rim));
            c = mix(c, LINE, fill(abs(rim) - 0.4 * lw));
            float diffuser = abs(rr - R * 1.08) - 0.0032;
            c = mix(c, mix(GLASS, cyan.rgb, 0.06), fill(diffuser));
            c = mix(c, LINE, fill(abs(diffuser) - 0.35 * lw));
            vec3 gap = vec3(0.02, 0.024, 0.036);
            c = mix(c, gap, fill(rr - R));
            for (int s = 0; s < 4; s++) {
                float a = float(s) * 1.5707963 + 0.785398;
                vec2 dir = vec2(cos(a), sin(a));
                float strut = abs(dot(fr, vec2(-dir.y, dir.x))) - 0.0022;
                c = mix(c, vec3(0.05, 0.058, 0.075), fill(strut) * step(0.0, dot(fr, dir)) * step(R * 0.3, rr) * fill(rr - R));
            }
            vec3 hub = celDisc(vec3(0.2, 0.22, 0.28), b, vec2(fx, fanY), R * 0.32, 0.006);
            hub = mix(hub, mix(cyan.rgb, accent, 0.4) * 0.7, stroke(rr - R * 0.21, 0.0016));
            hub = mix(hub, HILITE, 0.55 * fill(length(fr + vec2(0.34, 0.42) * R * 0.32) - 0.05 * R));
            c = mix(c, hub, fill(rr - R * 0.32));
            c = mix(c, LINE, fill(abs(rr - R * 0.32) - 0.4 * lw));
        }

        vec4 bracket = vec4(gpu.x, gpu.y - 0.03, gpu.x + 0.022, gpu.w);
        vec3 br = celRect(STEEL * 0.9, b, bracket, 0.003, 0.003);
        br = mix(br, STEEL * DEEP * 0.6, fill(box(vec2(b.x - bracket.x - 0.011, fract((b.y - gpu.y) / 0.02) * 0.02 - 0.01), vec2(0.0), vec2(0.0035, 0.0055), 0.002)) * step(gpu.y + 0.01, b.y));
        c = inked(c, br, rect(b, bracket, 0.003), 0.0, 1.0);
        color = inked(color, c, dG, 0.6, rect(b + vec2(0.0035, 0.0), gpu, 0.02));
    }
    {
        vec4 bracket = vec4(gpu.x, gpu.y - 0.03, gpu.x + 0.022, gpu.y + 0.004);
        float dBr = rect(b, bracket, 0.003);
        if (dBr < lw) {
            vec3 br = celRect(STEEL * 0.9, b, bracket, 0.003, 0.003);
            br = mix(br, STEEL * DEEP, fill(length(b - vec2(bracket.x + 0.011, bracket.y + 0.009)) - 0.0035));
            color = inked(color, br, dBr, 0.0, 1.0);
        }
    }

    float vignette = smoothstep(1.4, 0.4, length((p - vec2(0.55 * aspect, 0.45)) * vec2(0.75, 1.0)));
    color *= mix(0.72, 1.0, vignette);

    fragColor = vec4(color, 1.0) * qt_Opacity;
}
