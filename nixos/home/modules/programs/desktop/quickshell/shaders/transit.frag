#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 box;
    vec2 resolution;
    float pan;
    float horizon;
    vec4 path;
    float progress;
    float kind;
    float gain;
};

float streak(vec2 p, vec2 start, vec2 dir, float t, float scale) {
    vec2 rel = p - (start + dir * t * 0.32);
    float behind = dot(rel, -dir);
    float across = dot(rel, vec2(-dir.y, dir.x)) * scale;
    float trail = step(0.0, behind) * exp(-behind / 0.045) + exp(-dot(rel, rel) * scale * scale / 6.0);
    return trail * exp(-across * across / 0.7) * sin(3.14159 * t);
}

float satellite(vec2 p, vec2 a, vec2 b, float t) {
    vec2 route = normalize(b - a);
    vec2 d = (p - mix(a, b, t)) * resolution.y;
    float behind = dot(d, -route);
    float across = dot(d, vec2(-route.y, route.x));
    float point = exp(-dot(d, d) / 1.6) * 0.55;
    float trace = smoothstep(0.0, 5.0, behind) * exp(-behind / 80.0) * exp(-across * across / 0.7) * 0.12;
    return (point + trace) * smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t);
}

void main() {
    vec2 uv = (box.xy + qt_TexCoord0 * box.zw) / resolution;
    float aspect = resolution.x / resolution.y;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float scale = 1440.0;

    vec3 color = kind < 0.5
        ? vec3(0.8, 0.92, 1.0) * streak(p, path.xy, path.zw, progress, scale) * 0.7
        : vec3(0.85, 0.93, 1.0) * satellite(p, path.xy, path.zw, progress) * 0.8;

    float h = max((length(p - vec2(aspect * 0.6 + pan, horizon + 1.4)) - 1.4) * scale, 0.0);
    float moon = (length(p - vec2(aspect * 0.84 + pan * 0.45, 0.19)) - 0.028) * resolution.y;
    color *= gain * smoothstep(0.0, 220.0, h) * smoothstep(-1.0, 1.0, moon);

    vec3 over = max(color - 0.72, 0.0);
    color = min(color, vec3(0.72)) + 0.28 * (1.0 - exp(-over / 0.28));
    vec2 v = uv - vec2(0.5, 0.45);
    color *= clamp(1.0 - 0.8 * dot(v, v), 0.5, 1.0);
    fragColor = vec4(color, 0.0) * qt_Opacity;
}
