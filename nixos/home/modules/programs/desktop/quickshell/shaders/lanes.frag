#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float activity;
    float speed;
    float seed;
    float count;
    float pitch;
    float gauge;
    float unit;
    vec4 area;
    vec4 ab;
    vec4 cd;
    vec4 tone;
};

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
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

void pulse(float k, float along, float lateral, float extent, out float line, out float head, out float glow) {
    float way = hash(vec2(k, seed)) < 0.5 ? 1.0 : -1.0;
    float spacing = 0.09 + 0.08 * hash(vec2(seed, k * 1.7));
    float phase = along / spacing - way * speed * time / spacing + hash(vec2(k, seed * 3.1));
    float live = step(hash(vec2(floor(phase), k + seed * 7.0)), activity);
    float f = (fract(phase) - 0.5) * spacing;
    float dl = abs(lateral - (k * pitch - extent));
    float copper = clamp(0.5 - (dl - 0.5 * gauge) / unit, 0.0, 1.0);
    float tip = clamp(0.5 - (abs(f) - 0.0045) / unit, 0.0, 1.0);
    float behind = -way * f;
    float tail = smoothstep(0.0, 0.02, behind) * (1.0 - smoothstep(0.02, 0.05, behind)) * 0.4;
    line = live * copper * clamp(tip + tail, 0.0, 1.0);
    head = live * copper * tip;
    float r = length(vec2(f * 0.55, dl));
    glow = live * (0.3 * clamp((0.004 - r) / unit + 0.5, 0.0, 1.0) + 0.12 * clamp((0.0075 - r) / unit + 0.5, 0.0, 1.0));
}

void main() {
    vec2 b = mix(area.xy, area.zw, qt_TexCoord0);
    vec2 points[4] = vec2[4](ab.xy, ab.zw, cd.xy, cd.zw);
    float lateral;
    float along;
    float total;
    busFrame(b, points, lateral, along, total);
    float extent = 0.5 * (count - 1.0) * pitch;
    float ends = clamp(along / unit + 0.5, 0.0, 1.0) * clamp((total - along) / unit + 0.5, 0.0, 1.0);
    if (ends <= 0.0 || abs(lateral) > extent + pitch + 0.008) {
        fragColor = vec4(0.0);
        return;
    }
    float nearest = clamp(floor((lateral + extent) / pitch + 0.5), 0.0, count - 1.0);
    float line;
    float head;
    float glow;
    pulse(nearest, along, lateral, extent, line, head, glow);
    for (int i = -2; i <= 2; i++) {
        float k = nearest + float(i);
        if (i == 0 || k < 0.0 || k > count - 1.0)
            continue;
        float otherLine;
        float otherHead;
        float otherGlow;
        pulse(k, along, lateral, extent, otherLine, otherHead, otherGlow);
        glow = max(glow, otherGlow);
    }
    float a = line * ends;
    float g = glow * ends;
    vec3 c = mix(tone.rgb, vec3(0.86, 0.92, 1.0), 0.35 * head);
    fragColor = (vec4(c * a, a) + vec4(tone.rgb * g, g) * (1.0 - a)) * qt_Opacity;
}
