#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float fade;
};

layout(binding = 1) uniform sampler2D back;
layout(binding = 2) uniform sampler2D front;

void main() {
    fragColor = mix(texture(back, qt_TexCoord0), texture(front, qt_TexCoord0), fade) * qt_Opacity;
}
