// Cursor smear/trail: a glowing trail that follows the cursor as it moves.
// Adapted from the popular Ghostty "cursor smear" community shaders.
// Ghostty/Shadertoy fragment-shader format.

float sdBox(in vec2 p, in vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    // iCurrentCursor / iPreviousCursor: vec4(x, y, w, h) in pixels,
    // origin top-left. Provided by Ghostty.
    vec2 res = iResolution.xy;

    vec2 curPos = (iCurrentCursor.xy + iCurrentCursor.zw * 0.5);
    vec2 prevPos = (iPreviousCursor.xy + iPreviousCursor.zw * 0.5);

    // Animate from previous -> current cursor position.
    float t = clamp((iTime - iTimeCursorChange) / 0.18, 0.0, 1.0);
    float ease = 1.0 - pow(1.0 - t, 3.0);
    vec2 pos = mix(prevPos, curPos, ease);

    // Build a capsule between the two positions for the trailing smear.
    vec2 frag = fragCoord;
    vec2 a = prevPos;
    vec2 b = pos;
    vec2 pa = frag - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1.0), 0.0, 1.0);
    float d = length(pa - ba * h) - iCurrentCursor.w * 0.6;

    float glow = smoothstep(8.0, 0.0, d) * (1.0 - t * 0.6);
    vec3 trailColor = vec3(0.55, 0.78, 1.0);

    fragColor.rgb += trailColor * glow * 0.7;
}
