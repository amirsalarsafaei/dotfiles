#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    vec2 resolution;
    vec4 base;
    vec4 accentA;
    vec4 accentB;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        amplitude *= 0.5;
    }
    return value;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * vec2(resolution.x / max(resolution.y, 1.0), 1.0) * 1.4;
    float t = time * 0.04;
    vec2 q = vec2(fbm(p + vec2(t, 0.0)), fbm(p + vec2(5.2, 1.3) - t));
    float f = fbm(p + 2.2 * q + vec2(t * 1.6, -t));
    float band = smoothstep(0.38, 0.95, f) * (1.1 - uv.y * 0.7);
    vec3 color = base.rgb;
    color = mix(color, accentA.rgb, band * 0.6 * intensity);
    color = mix(color, accentB.rgb, smoothstep(0.5, 1.0, q.y) * band * 0.5 * intensity);
    float vignette = smoothstep(1.25, 0.15, length(uv - vec2(0.35, 0.25)));
    color *= mix(0.5, 1.0, vignette);
    color += (hash(uv * resolution + fract(time)) - 0.5) * 0.012;
    fragColor = vec4(color, 1.0) * qt_Opacity;
}
