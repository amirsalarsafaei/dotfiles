// Animated background: a subtle drifting gradient behind transparent areas.
// Looks best with a slightly transparent background-opacity.
// Ghostty/Shadertoy fragment-shader format.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    // Slow drifting color field.
    float t = iTime * 0.08;
    vec3 a = vec3(0.06, 0.05, 0.12);
    vec3 b = vec3(0.10, 0.06, 0.16);
    float wave = 0.5 + 0.5 * sin(uv.x * 3.0 + t) * cos(uv.y * 2.0 - t * 1.3);
    vec3 bg = mix(a, b, wave);

    // Composite the terminal over the gradient using its own alpha,
    // so the animation only shows through transparent cells.
    fragColor.rgb = mix(bg, term.rgb, term.a);
    fragColor.a = 1.0;
}
