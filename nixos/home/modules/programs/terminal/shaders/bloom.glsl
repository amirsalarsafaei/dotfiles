// Bloom / glow: soft phosphor-like glow around bright text.
// Ghostty/Shadertoy fragment-shader format.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    // Accumulate a blurred, brightness-thresholded copy for the glow.
    vec3 bloom = vec3(0.0);
    vec2 texel = 1.0 / iResolution.xy;
    const int R = 3;
    float total = 0.0;

    for (int x = -R; x <= R; x++) {
        for (int y = -R; y <= R; y++) {
            vec2 off = vec2(float(x), float(y)) * texel * 1.5;
            vec3 s = texture(iChannel0, uv + off).rgb;
            // Only bright pixels contribute to the bloom.
            float lum = dot(s, vec3(0.299, 0.587, 0.114));
            float w = 1.0 / (1.0 + float(x * x + y * y));
            bloom += s * step(0.35, lum) * w;
            total += w;
        }
    }
    bloom /= total;

    // Additive blend.
    color.rgb += bloom * 0.55;

    fragColor = color;
}
