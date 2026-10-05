#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float unit;
    float fine;
    float smear;
    float spin;
    float streak;
    float glow;
    float last;
    float speed;
    vec4 area;
    vec4 fan;
    vec4 turns;
    vec4 ink;
    vec4 lit;
    vec4 mid;
    vec4 deep;
    vec4 disc;
    vec4 hub;
    vec4 arc;
    vec4 ring;
};

const float TAU = 6.2831853;
const float PITCH = TAU / 11.0;
const float WIDTH = 0.36;
const float INNER = 0.36;
const float OUTER = 0.97;
const vec2 LIGHT = vec2(-0.6, -0.8);

float total(float x, float len) {
    float n = floor(x / PITCH);
    return n * len + min(x - n * PITCH, len);
}

float cover(float x, float a, float len, float s) {
    return (total(x + s - a, len) - total(x - a, len)) / s;
}

vec4 over(vec4 under, vec3 c, float a) {
    return vec4(c * a, a) + under * (1.0 - a);
}

float band(float r, float radius, float halfWidth) {
    return clamp(halfWidth / fine - abs(r - radius) / fine + 0.5, 0.0, 1.0);
}

float arcAt(float r, float theta, float radius, float start, float sweep, float thick) {
    float rel = mod(theta - spin - start, TAU);
    float d;
    if (rel <= sweep) {
        d = abs(r - radius);
    } else {
        float toEnd = rel - sweep;
        float toStart = TAU - rel;
        float a = toEnd < toStart ? start + sweep : start;
        vec2 tip = radius * vec2(cos(a + spin), sin(a + spin));
        d = length(vec2(r * cos(theta), r * sin(theta)) - tip);
    }
    return clamp(thick - d / fine + 0.5, 0.0, 1.0);
}

void main() {
    vec2 b = mix(area.xy, area.zw, qt_TexCoord0);
    float fi = clamp(floor((b.x - fan.x) / fan.z), 0.0, 4.0);
    vec2 d = b - vec2(fan.x + (fi + 0.5) * fan.z, fan.y);
    float R = fan.w;
    float r = length(d);
    float k = r / R;
    if (k > 1.13) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 dir = d / max(r, 1e-5);
    float facing = dot(dir, normalize(LIGHT));
    float theta = atan(d.y, d.x);
    float edge = R / fine;
    vec4 col = vec4(0.0);

    float lead = mod(spin * 1.6 + fi * 1.37, TAU);
    float behind = mod(lead - theta, TAU);
    float comet = speed * exp(-behind * 2.2);
    float light = band(r, 1.08 * R, 0.0024);
    float aura = exp(-abs(r - 1.08 * R) / (0.006 * R / 0.12)) * step(1.045, k) * step(k, 1.115);
    float shine = glow * (0.32 + 0.18 * max(facing, 0.0)) + 0.85 * comet;
    col = over(col, ring.rgb, ring.a * clamp(0.35 * aura * shine, 0.0, 1.0));
    col = over(col, mix(ring.rgb, vec3(1.0), 0.35 * comet), ring.a * clamp(light * shine, 0.0, 1.0));
    if (k > 1.02) {
        fragColor = col * qt_Opacity;
        return;
    }

    float turn = fi < 0.5 ? turns.x : fi < 1.5 ? turns.y : fi < 2.5 ? turns.z : fi < 3.5 ? turns.w : last;
    float psi = mod(theta - turn + 1.1 * k, TAU);
    float pix = fine / max(r, fine);
    float s = max(smear * (1.0 + 0.06 * fi), pix);

    col = over(col, disc.rgb, disc.a * streak * clamp((1.0 - k) * edge + 0.5, 0.0, 1.0));

    float inside = clamp((k - INNER) * edge + 0.5, 0.0, 1.0) * clamp((OUTER - k) * edge + 0.5, 0.0, 1.0);
    float reach = clamp((k - INNER) * edge + 1.0, 0.0, 1.0) * clamp((OUTER - k) * edge + 1.0, 0.0, 1.0);
    float h = 0.5 * unit / max(r, fine);
    float cl = cover(psi, 0.0, 0.16 * WIDTH, s) * inside;
    float cm = cover(psi, 0.16 * WIDTH, 0.39 * WIDTH, s) * inside;
    float cd = cover(psi, 0.55 * WIDTH, 0.45 * WIDTH, s) * inside;
    float body = cover(psi, -h, WIDTH + 2.0 * h, s);
    float sides = (cover(psi, -h, 2.0 * h, s) + cover(psi, WIDTH - h, 2.0 * h, s)) * reach;
    float caps = max(clamp(0.5 * unit / fine - abs(k - INNER) * edge + 0.5, 0.0, 1.0), clamp(0.5 * unit / fine - abs(k - OUTER) * edge + 0.5, 0.0, 1.0)) * body;
    float ci = clamp(sides + caps, 0.0, 1.0);
    float fa = clamp(cl + cm + cd, 0.0, 1.0);
    float radial = mix(0.72, 1.12, smoothstep(INNER, OUTER, k));
    float tilt = 0.82 + 0.3 * facing;
    vec3 fc = (lit.rgb * cl + mid.rgb * cm + deep.rgb * cd) / max(fa, 1e-4);
    fc *= radial * tilt;
    float sheen = pow(max(facing, 0.0), 10.0) * (1.0 - 0.7 * streak);
    fc = mix(fc, vec3(0.86, 0.92, 1.0), 0.35 * sheen * cl / max(fa, 1e-4));
    col = over(col, fc, fa);
    col = over(col, ink.rgb, ci * (1.0 - 0.5 * streak));

    float tip = clamp(0.018 * edge - abs(k - 0.955) * edge + 0.5, 0.0, 1.0);
    vec3 tipColor = mix(mid.rgb, lit.rgb, 0.45 + 0.4 * facing);
    tipColor = mix(tipColor, vec3(0.86, 0.92, 1.0), 0.3 * pow(max(facing, 0.0), 6.0));
    col = over(col, tipColor, tip);
    float tipEdge = max(band(k * R, 0.937 * R, 0.5 * unit), band(k * R, 0.973 * R, 0.5 * unit));
    col = over(col, ink.rgb, tipEdge);

    float thick = 0.75 * unit / fine;
    float arcs = max(arcAt(r, theta, 0.55 * R, 0.0, 1.2217, thick), max(arcAt(r, theta, 0.74 * R, 2.4435, 1.3963, thick), arcAt(r, theta, 0.9 * R, 4.3633, 1.0472, thick)));
    col = over(col, arc.rgb, arc.a * streak * arcs);

    float bw = max(1.5 * unit, 0.014 * R);
    float hubRing = clamp(0.5 * bw / fine - abs(r - (0.33 * R - 0.5 * bw)) / fine + 0.5, 0.0, 1.0);
    col = over(col, hub.rgb, hub.a * glow * hubRing);

    fragColor = col * qt_Opacity;
}
