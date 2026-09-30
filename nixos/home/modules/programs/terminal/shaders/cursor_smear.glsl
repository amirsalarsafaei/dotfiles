// Cursor smear/trail: a glowing trail that follows the cursor as it moves.
// Adapted from the popular Ghostty "cursor smear" community shaders.
// Ghostty/Shadertoy fragment-shader format.

const float DURATION = 0.18;
const float TAIL_TAPER = 0.6;
const float BODY_ALPHA = 0.35;

float sdBox(in vec2 p, in vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float easeOutCubic(float t) {
    float u = 1.0 - t;
    return 1.0 - u * u * u;
}

vec2 cursorCenter(vec4 cursor) {
    return cursor.xy + vec2(cursor.z, -cursor.w) * 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (t >= 1.0 || iFocus == 0 || iCursorVisible == 0 || iPreviousCursor.z <= 0.0) {
        return;
    }

    vec2 head = cursorCenter(iCurrentCursor);
    vec2 headSize = iCurrentCursor.zw * 0.5;
    vec2 tailSize = iPreviousCursor.zw * 0.5 * TAIL_TAPER;
    vec2 tail = mix(cursorCenter(iPreviousCursor), head, easeOutCubic(t));

    vec2 path = head - tail;
    float pathLength2 = dot(path, path);
    if (pathLength2 < 1.0) {
        return;
    }

    float along = clamp(dot(fragCoord - tail, path) / pathLength2, 0.0, 1.0);
    float d = sdBox(fragCoord - (tail + path * along), mix(tailSize, headSize, along));
    float fade = (1.0 - t) * (1.0 - t);

    float body = 1.0 - smoothstep(-0.5, 0.5, d);
    body *= smoothstep(-0.5, 0.5, sdBox(fragCoord - head, headSize));
    fragColor.rgb = mix(fragColor.rgb, iCurrentCursorColor.rgb, body * BODY_ALPHA * fade);
}
