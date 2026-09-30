#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 upper;
    vec4 lower;
    float strength;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float coverage = texture(source, qt_TexCoord0).a;
    vec3 color = mix(upper.rgb, lower.rgb, smoothstep(0.2, 0.95, qt_TexCoord0.y) * strength);
    fragColor = vec4(color, 1.0) * coverage * qt_Opacity;
}
