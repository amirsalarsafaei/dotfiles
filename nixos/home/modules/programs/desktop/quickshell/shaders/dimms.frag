#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float pitch;
    float fine;
    float time;
    float level;
    float pace;
    vec4 bar;
    vec4 area;
    vec4 hit;
    vec4 tone;
    vec4 deep;
    vec4 flash;
};

const float SEGMENTS = 12.0;

float box(vec2 p, vec2 extent, float radius) {
    vec2 d = abs(p) - extent + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

vec4 over(vec4 under, vec3 c, float a) {
    return vec4(c * a, a) + under * (1.0 - a);
}

float band(float d) {
    return clamp(0.5 - d / fine, 0.0, 1.0);
}

void main() {
    vec2 b = mix(area.xy, area.zw, qt_TexCoord0);
    vec2 half_ = 0.5 * (bar.zw - bar.xy);
    float stick = clamp(floor((b.x - 0.5 * (bar.x + bar.z)) / pitch + 0.5), 0.0, 3.0);
    vec2 q = b - vec2(0.5 * (bar.x + bar.z) + stick * pitch, 0.5 * (bar.y + bar.w));
    float len = bar.w - bar.y;
    float d = box(q, half_, min(half_.x, 0.002));
    float inside = band(d);
    float v = clamp(0.5 - q.y / len, 0.0, 0.9999);

    float cell = len / SEGMENTS;
    float gap = max(1.5 * fine, 0.14 * cell);
    float slot = floor(v * SEGMENTS);
    vec2 sq = vec2(q.x, q.y - (0.5 - (slot + 0.5) / SEGMENTS) * len);
    vec2 extent = vec2(half_.x, 0.5 * (cell - gap));
    float ds = box(sq, extent, min(half_.x, 0.0012));
    float seg = band(ds) * inside;
    float rim = seg * (1.0 - band(ds + 1.2 * fine));

    float n = level * SEGMENTS;
    float on = clamp(n - slot, 0.0, 1.0);
    float lit = clamp(6.0 * on, 0.0, 1.0);
    float top = max(ceil(n) - 1.0, 0.0);
    float shade = mix(0.68, 1.0, top > 0.0 ? slot / top : 1.0);
    float head = floor(fract(time * pace + stick * 0.29) * (top + 4.0));
    float chase = step(0.02, level) * (step(abs(slot - head), 0.5) + 0.35 * step(abs(slot - head + 1.0), 0.5));
    float cap = step(abs(slot - top), 0.5) * band(sq.y + extent.y - max(1.5 * fine, 0.16 * cell));

    float age = hit.z;
    float struck = hit.w * step(abs(stick - hit.x), 0.5);
    float dist = abs(slot - floor(hit.y * SEGMENTS));
    float spark = struck * step(dist, 0.5) * (1.0 - smoothstep(0.0, 0.3, age));
    float ripple = struck * step(0.5, dist) * step(abs(dist - floor(age * 9.0)), 0.5) * (1.0 - age);
    float surge = struck * 0.45 * (1.0 - age) * (1.0 - age);

    float across = sq.x / half_.x;
    float aa = fine / half_.x;
    float key = clamp(0.5 - (abs(across + 0.18) - 0.36) / aa, 0.0, 1.0);
    float foot = band(extent.y * 0.45 - sq.y);
    vec3 body = tone.rgb * 0.8 * shade * mix(0.4, 1.0, on) * (1.0 + surge);
    body = mix(body, body * 0.62, foot);
    body = mix(body, min(tone.rgb * 1.08 * shade * mix(0.4, 1.0, on) + flash.rgb * 0.14 * on, vec3(1.0)), key);
    body = mix(body, flash.rgb, 0.22 * chase + 0.45 * on * cap);

    float outside = max(d, 0.0);
    float near = clamp(n - floor(clamp(0.5 - q.y / len, 0.0, 0.9999) * SEGMENTS), 0.0, 1.0);
    float glow = 0.18 * band(outside - 0.0012) + 0.08 * band(outside - 0.0028);
    float halo = glow * (1.0 - inside) * (near * (1.0 + surge) + 1.5 * (spark + ripple));

    vec4 col = vec4(0.0);
    col = over(col, tone.rgb, halo);
    col = over(col, deep.rgb, 0.16 * inside);
    col = over(col, tone.rgb, 0.05 * seg + 0.12 * rim);
    col = over(col, min(body, vec3(1.0)), 0.94 * seg * lit);
    float strike = clamp(spark + ripple, 0.0, 1.0) * seg;
    col = over(col, mix(tone.rgb, flash.rgb, 0.7), strike);

    fragColor = col * qt_Opacity;
}
