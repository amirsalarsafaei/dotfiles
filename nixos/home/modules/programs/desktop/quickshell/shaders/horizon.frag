#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float pan;
    float horizon;
    float glow;
    float stars;
    float daylight;
    float sunPath;
    float moonPhase;
    vec2 resolution;
    vec4 sky;
    vec4 surface;
    vec4 rimA;
    vec4 rimB;
};

layout(binding = 1) uniform sampler2D earth;
layout(binding = 2) uniform sampler2D moonMap;
layout(binding = 3) uniform sampler2D milkyWay;

const float TAU = 6.2831853;
const float PI = 3.14159265;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    mat2 turn = mat2(0.8, -0.6, 0.6, 0.8);
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p);
        p = turn * p * 2.03 + 17.1;
        amplitude *= 0.5;
    }
    return value;
}

vec3 starLayer(vec2 pixel, float cell, float chance, float size, float seed, float unit, bool spikes) {
    vec2 grid = pixel / (cell * unit);
    vec2 id = floor(grid);
    float roll = hash(id + seed);
    if (roll > chance) {
        return vec3(0.0);
    }
    vec2 spot = 0.2 + 0.6 * vec2(hash(id + seed + 3.1), hash(id + seed + 7.7));
    vec2 d = (fract(grid) - spot) * cell;
    float magnitude = pow(hash(id + seed + 11.3), 4.0);
    float twinkle = 0.7 + 0.3 * sin(time * (0.8 + 2.5 * hash(id + seed + 5.9)) + TAU * roll);
    float radius = size * (0.55 + 1.3 * magnitude);
    float light = exp(-dot(d, d) / (radius * radius));
    if (spikes) {
        float reach = 4.0 + 20.0 * magnitude;
        float spike = exp(-abs(d.x) / 0.45) * exp(-abs(d.y) / reach)
                    + exp(-abs(d.y) / 0.45) * exp(-abs(d.x) / reach);
        light += spike * 0.4 * magnitude;
    }
    vec3 tint = mix(vec3(0.64, 0.77, 1.0), vec3(0.95, 0.97, 1.0), hash(id + seed + 13.7));
    return tint * light * (0.25 + 0.75 * magnitude) * twinkle;
}

float meteor(vec2 p, float aspect, float scale) {
    float slot = floor(time / 11.0);
    float t = (time - slot * 11.0) / 1.1;
    if (t > 1.0 || hash(vec2(slot, 3.7)) < 0.62) {
        return 0.0;
    }
    vec2 start = vec2((0.15 + 0.7 * hash(vec2(slot, 1.3))) * aspect, 0.04 + 0.22 * hash(vec2(slot, 8.1)));
    float heading = hash(vec2(slot, 5.9)) < 0.5 ? -1.0 : 1.0;
    vec2 dir = normalize(vec2(heading, 0.42));
    vec2 rel = p - (start + dir * t * 0.32);
    float behind = dot(rel, -dir);
    float across = dot(rel, vec2(-dir.y, dir.x)) * scale;
    float trail = step(0.0, behind) * exp(-behind / 0.045) + exp(-dot(rel, rel) * scale * scale / 6.0);
    return trail * exp(-across * across / 0.7) * sin(3.14159 * t);
}

vec4 moonLayer(vec2 p, float aspect) {
    vec2 c = vec2(aspect * 0.84 - pan * 0.45, 0.19);
    float r = 0.028;
    vec2 m = (p - c) / r;
    float d = length(m);
    float edgePx = (d - 1.0) * r * resolution.y;
    float cover = smoothstep(1.0, -1.0, edgePx);
    float lit = 0.5 - 0.5 * cos(TAU * moonPhase);
    float outside = max(edgePx, 0.0);
    vec3 halo = vec3(0.62, 0.76, 0.96) * (exp(-outside / 26.0) * 0.07 + exp(-outside / 90.0) * 0.025) * lit;
    if (cover <= 0.0) {
        return vec4(halo, 0.0);
    }
    vec3 n = vec3(m.x, -m.y, sqrt(max(0.0, 1.0 - d * d)));
    vec3 light = normalize(vec3(sin(TAU * moonPhase), 0.12, -cos(TAU * moonPhase)));
    float shade = smoothstep(-0.04, 0.18, dot(n, light));
    vec2 moonUv = vec2(atan(n.x, n.z) / TAU + 0.5, 0.5 - asin(clamp(n.y, -1.0, 1.0)) / PI);
    float moonLod = max(0.0, log2(512.0 / (2.0 * r * resolution.y)));
    float albedo = textureLod(moonMap, moonUv, moonLod).r * 1.1 * (0.8 + 0.2 * n.z);
    vec3 lunar = vec3(0.80, 0.86, 0.93) * albedo * shade * 0.62 + vec3(0.018, 0.022, 0.03);
    return vec4(lunar + halo, cover);
}

float satellite(vec2 p, float aspect) {
    float slot = floor(time / 150.0);
    float t = (time - slot * 150.0) / 45.0;
    if (t > 1.0) {
        return 0.0;
    }
    float lane = hash(vec2(slot, 9.2)) < 0.5 ? 0.0 : 1.0;
    vec2 a = vec2(mix(-0.05, 1.05, lane) * aspect, 0.08 + 0.2 * hash(vec2(slot, 2.3)));
    vec2 b = vec2(mix(1.05, -0.05, lane) * aspect, 0.18 + 0.25 * hash(vec2(slot, 6.1)));
    vec2 d = (p - mix(a, b, t)) * resolution.y;
    float blink = 0.35 + 0.65 * step(0.9, fract(time * 0.8));
    return exp(-dot(d, d) / 1.6) * blink * smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 pixel = uv * resolution;
    float unit = resolution.y / 1440.0;
    float scale = resolution.y / unit;
    float aspect = resolution.x / resolution.y;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float night = clamp(stars, 0.0, 1.0);

    float radius = 1.4;
    vec2 center = vec2(aspect * 0.6 + pan, horizon + radius);
    vec2 offset = p - center;
    float dist = length(offset);
    float edge = (dist - radius) * scale;

    float theta = mix(-0.5, 0.35, sunPath);
    vec2 sunDir = vec2(sin(theta), cos(theta));
    vec3 sun = normalize(vec3(sunDir * 0.5, -0.86));
    vec2 limbDir = offset / max(dist, 1e-4) * vec2(1.0, -1.0);
    float facing = dot(limbDir, sunDir) * 0.5 + 0.5;
    float limbLight = 0.18 + 0.82 * pow(facing, 3.0);
    vec3 rim = mix(rimA.rgb, rimB.rgb, smoothstep(0.1, 0.9, uv.x));
    vec3 inner = mix(rim, vec3(0.84, 0.95, 1.0), 0.3);

    vec3 base = mix(sky.rgb * 1.2, sky.rgb * 0.4, uv.y);
    float coverage = smoothstep(1.2, -1.2, (dist - radius) * resolution.y / max(fwidth((dist - radius) * resolution.y), 1.0));
    vec3 skyColor = base;
    vec3 planetColor = base;

    vec2 local = offset / radius;
    vec3 n = vec3(local.x, -local.y, sqrt(max(0.0, 1.0 - dot(local, local))));
    float tilt = 0.3;
    vec3 globe = vec3(n.x, cos(tilt) * n.y - sin(tilt) * n.z, sin(tilt) * n.y + cos(tilt) * n.z);
    float lon = atan(globe.x, globe.z) + 0.89 - time * 0.0012 + pan * 0.8;
    float lat = asin(clamp(globe.y, -1.0, 1.0));
    float band = (0.5 - lat / PI - 182.0 / 4096.0) * 4096.0 / 1456.0;
    vec2 earthUv = vec2(fract(lon / TAU + 0.5), clamp(band, 0.0, 1.0));
    vec2 earthUvShifted = vec2(fract(lon / TAU), earthUv.y);
    vec2 gradX = dFdx(earthUv);
    vec2 gradY = dFdy(earthUv);
    vec2 gradXShifted = dFdx(earthUvShifted);
    vec2 gradYShifted = dFdy(earthUvShifted);
    gradX = abs(gradX.x) < abs(gradXShifted.x) ? gradX : gradXShifted;
    gradY = abs(gradY.x) < abs(gradYShifted.x) ? gradY : gradYShifted;
    gradX.y *= 4096.0 / 1456.0;
    gradY.y *= 4096.0 / 1456.0;
    gradX = clamp(gradX, vec2(-0.01), vec2(0.01));
    gradY = clamp(gradY, vec2(-0.01), vec2(0.01));

    if (coverage < 1.0) {
        float h = max(edge, 0.0);
        vec3 color = base;
        float skyFade = smoothstep(0.0, 220.0, h);
        vec2 q = p - vec2(pan * 0.3, 0.0);
        vec2 axis = normalize(vec2(1.0, 0.38));
        float along = dot(q, axis);
        float side = dot(q - vec2(aspect * 0.35, 0.2), vec2(-axis.y, axis.x));
        vec2 galaxyUv = vec2(0.5 + (along - 0.59) * 0.22, 0.5 + side * 1.35);
        float galaxy = textureLod(milkyWay, galaxyUv, 0.0).r * smoothstep(0.0, 0.08, galaxyUv.y) * smoothstep(1.0, 0.92, galaxyUv.y);
        float haze = pow(galaxy, 1.35);
        color += mix(rimA.rgb, rimB.rgb, smoothstep(0.15, 0.7, galaxy)) * haze * (0.12 + 0.2 * night) * skyFade;

        vec2 far = pixel - vec2(pan * resolution.y * 0.15, 0.0);
        vec2 near = pixel - vec2(pan * resolution.y * 0.32, 0.0);
        vec3 starfield = starLayer(far, 14.0, 0.07 + 0.4 * galaxy, 0.45, 1.0, unit, false) * 0.7
                       + starLayer(far + 71.0, 36.0, 0.2, 0.6, 2.0, unit, false) * 0.9
                       + starLayer(near, 120.0, 0.22, 0.8, 3.0, unit, false)
                       + starLayer(near + 13.0, 300.0, 0.3, 0.9, 4.0, unit, true) * 1.3;
        color += starfield * mix(0.16, 1.0, night) * skyFade;
        color += vec3(0.8, 0.92, 1.0) * meteor(p, aspect, scale) * 0.7 * night * skyFade;
        color += vec3(0.85, 0.93, 1.0) * satellite(p, aspect) * 0.8 * mix(0.35, 1.0, night) * skyFade;

        vec4 moon = moonLayer(p, aspect) * vec4(vec3(mix(0.55, 1.0, night)), 1.0);
        color = mix(color + moon.rgb, moon.rgb, moon.a);

        vec3 atmosphere = inner * exp(-h / 6.0) * 0.45
                        + mix(rim, rimA.rgb, smoothstep(0.0, 80.0, h)) * exp(-h / 38.0) * 0.4
                        + rimA.rgb * exp(-h / 210.0) * 0.14
                        + rimA.rgb * exp(-h / 700.0) * 0.05;
        color += atmosphere * limbLight * glow;
        color += rimB.rgb * exp(-pow((h - 24.0) / 7.0, 2.0)) * 0.07 * night * (0.4 + 0.6 * limbLight) * glow;

        float angle = atan(offset.x, -offset.y);
        float ribbon = fbm(vec2(angle * 22.0 + time * 0.02, time * 0.015), 3);
        float rays = 0.55 + 0.45 * noise(vec2(angle * 260.0, h * 0.004 - time * 0.12));
        float curtain = smoothstep(0.42, 0.7, ribbon) * smoothstep(6.0, 30.0, h) * exp(-h / 90.0) * rays;
        color += mix(rimB.rgb, rimA.rgb, smoothstep(0.0, 140.0, h)) * curtain * (1.0 - facing) * 0.45 * night * glow;
        skyColor = color;
    }

    if (coverage > 0.0) {
        vec3 color;
        vec4 surfaceMap = textureGrad(earth, earthUv, gradX, gradY);
        float lights = surfaceMap.r;
        float cloud = smoothstep(0.12, 0.85, surfaceMap.g);
        float land = smoothstep(0.015, 0.05, lights);
        float relief = smoothstep(0.02, 0.12, lights);

        float lambert = dot(n, sun);
        float day = smoothstep(-0.02, 0.3, lambert);
        float fresnel = pow(1.0 - n.z, 4.0);

        color = mix(surface.rgb * 0.8, surface.rgb * (2.0 + 0.8 * relief) + rimA.rgb * 0.01, land);
        color = mix(color, surface.rgb * 2.8 + rim * 0.025, cloud * 0.55);
        color += mix(rim * 0.3, vec3(0.75, 0.86, 1.0) * 0.55, cloud) * day * 0.5 * glow;
        color += rim * smoothstep(-0.15, 0.0, lambert) * (1.0 - day) * 0.03 * glow;

        float bloom = textureGrad(earth, earthUv, gradX * 6.0, gradY * 6.0).r;
        float core = pow(smoothstep(0.07, 0.9, lights), 1.3);
        float spill = smoothstep(0.05, 0.5, bloom);
        float veil = (1.0 - 0.8 * cloud) * (1.0 - day) * (0.3 + 0.9 * night);
        color += (vec3(0.86, 0.94, 1.0) * core * 0.5 + rimB.rgb * spill * 0.16) * veil;

        color += inner * fresnel * 0.22 * limbLight * glow;
        planetColor = color;
    }

    vec3 color = mix(skyColor, planetColor, coverage);
    float px = (dist - radius) * resolution.y;
    float aa = max(fwidth(px), 1.0);
    float core = exp(-px * px / (3.2 * aa * aa));
    float halo = exp(-px * px / (28.0 * aa * aa));
    color += inner * (core * 0.5 + halo * 0.22) * limbLight * glow;

    vec2 glintPos = center + radius * vec2(sunDir.x, -sunDir.y);
    vec2 g = (p - glintPos) * scale;
    float glint = exp(-dot(g, g) / 90.0) * 0.6 + exp(-length(g) / 70.0) * 0.12;
    float streak = exp(-abs(g.y) / 1.2) * exp(-abs(g.x) / 520.0) * 0.14;
    color += vec3(0.86, 0.95, 1.0) * (glint + streak) * (0.25 + 0.75 * daylight) * glow;

    vec2 v = uv - vec2(0.5, 0.45);
    color *= clamp(1.0 - 0.8 * dot(v, v), 0.5, 1.0);
    color += (hash(pixel) - 0.5) * 0.01;
    fragColor = vec4(max(color, vec3(0.0)), 1.0) * qt_Opacity;
}
