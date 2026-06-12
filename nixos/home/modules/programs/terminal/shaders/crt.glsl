// CRT effect: screen curvature, scanlines, and a subtle vignette.
// Ghostty/Shadertoy fragment-shader format.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Barrel distortion (screen curvature).
    vec2 cc = uv - 0.5;
    float dist = dot(cc, cc) * 0.18;
    vec2 cuv = uv + cc * (1.0 + dist) * dist;

    // Sample the terminal contents through the curved coords.
    vec4 color = texture(iChannel0, cuv);

    // Mask anything that curved off-screen.
    if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
        color = vec4(0.0, 0.0, 0.0, 1.0);
    }

    // Scanlines.
    float scanline = sin(cuv.y * iResolution.y * 3.14159) * 0.04;
    color.rgb -= scanline;

    // Subtle RGB shift for that phosphor look.
    float shift = 0.0008;
    color.r = texture(iChannel0, cuv + vec2(shift, 0.0)).r;
    color.b = texture(iChannel0, cuv - vec2(shift, 0.0)).b;

    // Vignette.
    float vig = 1.0 - dot(cc, cc) * 0.8;
    color.rgb *= clamp(vig, 0.0, 1.0);

    fragColor = color;
}
