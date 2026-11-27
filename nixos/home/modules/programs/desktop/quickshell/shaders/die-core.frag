#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float load;
    vec4 tone;
};

float roundedBox(vec2 p, vec2 halfSize, float radius) {
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    float d = roundedBox(p, max(vec2(0.0), size * 0.5 - 0.5), min(2.0, min(size.x, size.y) * 0.25));
    float aa = max(fwidth(d), 0.001);
    float edge = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, d);
    float inner = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, d + 1.0);
    float fill = (1.0 - qt_TexCoord0.y) * size.y;
    float level = load > 0.0 ? 1.0 - smoothstep(load * size.y - aa, load * size.y + aa, fill) : 0.0;
    float alpha = mix(0.32 + 0.68 * load, 0.04 + 0.14 * load + level * (0.2 + 0.3 * load), inner);
    alpha *= edge * tone.a * qt_Opacity;
    fragColor = vec4(tone.rgb * alpha, alpha);
}
