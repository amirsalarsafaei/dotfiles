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
    float detail;
    float level;
    float artMix;
    float swell;
    vec2 earthRes;
    float twilight;
    vec4 ocean;
    vec4 shoal;
};

layout(binding = 1) uniform sampler2D earth;
layout(binding = 2) uniform sampler2D moonMap;
layout(binding = 3) uniform sampler2D milkyWay;
layout(binding = 4) uniform sampler2D art;

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

float noiseWrap(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float x0 = mod(i.x, period);
    float x1 = mod(i.x + 1.0, period);
    return mix(mix(hash(vec2(x0, i.y)), hash(vec2(x1, i.y)), u.x),
               mix(hash(vec2(x0, i.y + 1.0)), hash(vec2(x1, i.y + 1.0)), u.x), u.y);
}

vec2 gradientAt(vec2 cell) {
    float angle = hash(cell) * TAU;
    return vec2(cos(angle), sin(angle));
}

vec3 waveNoise(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    float x0 = mod(i.x, period);
    float x1 = mod(i.x + 1.0, period);
    vec2 ga = gradientAt(vec2(x0, i.y));
    vec2 gb = gradientAt(vec2(x1, i.y));
    vec2 gc = gradientAt(vec2(x0, i.y + 1.0));
    vec2 gd = gradientAt(vec2(x1, i.y + 1.0));
    float va = dot(ga, f);
    float vb = dot(gb, f - vec2(1.0, 0.0));
    float vc = dot(gc, f - vec2(0.0, 1.0));
    float vd = dot(gd, f - vec2(1.0, 1.0));
    float k = va - vb - vc + vd;
    vec2 slope = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd)
               + du * (u.yx * k + vec2(vb, vc) - va);
    return vec3(va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k, slope);
}

float glintLobe(vec3 n, vec3 l, float alpha, float core) {
    vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
    float nh = max(dot(n, h), 1e-3);
    float nh2 = nh * nh;
    float a2 = alpha * alpha;
    float lobe = exp((nh2 - 1.0) / (a2 * nh2)) / (PI * a2 * nh2 * nh2);
    if (core > 0.0) {
        float c2 = a2 * 0.3;
        lobe += core * exp((nh2 - 1.0) / (c2 * nh2)) / (PI * c2 * nh2 * nh2);
    }
    float fresnel = 0.02 + 0.98 * pow(1.0 - max(h.z, 0.0), 5.0);
    return lobe * fresnel * smoothstep(-0.05, 0.12, dot(n, l));
}

vec4 earthCubic(vec2 uv, vec2 size) {
    vec2 pos = uv * size;
    vec2 c = floor(pos - 0.5) + 0.5;
    vec2 f = pos - c;
    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);
    vec2 w12 = w1 + w2;
    vec2 t0 = (c - 1.0) / size;
    vec2 t3 = (c + 2.0) / size;
    vec2 t12 = (c + w2 / w12) / size;
    t0.x = fract(t0.x);
    t3.x = fract(t3.x);
    t12.x = fract(t12.x);
    t0.y = clamp(t0.y, 0.0, 1.0);
    t3.y = clamp(t3.y, 0.0, 1.0);
    vec4 sum = textureLod(earth, vec2(t12.x, t0.y), 0.0) * (w12.x * w0.y)
             + textureLod(earth, vec2(t0.x, t12.y), 0.0) * (w0.x * w12.y)
             + textureLod(earth, t12, 0.0) * (w12.x * w12.y)
             + textureLod(earth, vec2(t3.x, t12.y), 0.0) * (w3.x * w12.y)
             + textureLod(earth, vec2(t12.x, t3.y), 0.0) * (w12.x * w3.y);
    float weight = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
    return clamp(sum / weight, 0.0, 1.0);
}

vec4 earthSample(vec2 uv, vec2 gx, vec2 gy, vec2 size) {
    float lx = length(gx * size);
    float ly = length(gy * size);
    float major = max(lx, ly);
    if (major < 1.0) {
        return earthCubic(uv, size);
    }
    vec2 axis = lx > ly ? gx : gy;
    vec2 minor = lx > ly ? gy : gx;
    float taps = clamp(ceil(major / max(min(lx, ly), 1e-5)), 1.0, 4.0);
    vec2 stride = axis / taps;
    vec4 sum = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        if (float(i) >= taps) {
            break;
        }
        vec2 at = uv + axis * ((float(i) + 0.5) / taps - 0.5);
        sum += textureGrad(earth, vec2(fract(at.x), clamp(at.y, 0.0, 1.0)), stride, minor);
    }
    return sum / taps;
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
    vec2 c = vec2(aspect * 0.84 + pan * 0.45, 0.19);
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
    float earthshine = (1.0 - shade) * (1.0 - lit) * 0.07;
    vec3 lunar = vec3(0.80, 0.86, 0.93) * albedo * shade * 0.62 + vec3(0.55, 0.7, 0.95) * albedo * earthshine + vec3(0.018, 0.022, 0.03);
    return vec4(lunar + halo, cover);
}

float lightning(vec2 local, float cloud, float dark) {
    float period = 1.7;
    float slot = floor(time / period);
    float phase = fract(time / period);
    if (hash(vec2(slot, 1.9)) < 0.55 || dark < 0.05) {
        return 0.0;
    }
    float x = mix(-0.62, 0.42, hash(vec2(slot, 4.1)));
    vec2 spot = vec2(x, -sqrt(1.0 - x * x) + 0.03 + 0.1 * hash(vec2(slot, 6.3)));
    vec2 d = (local - spot) / vec2(0.022, 0.012);
    float flicker = 0.55 + 0.45 * step(0.45, fract(phase * 17.0 + hash(vec2(slot, 2.2))));
    float flash = exp(-phase * 7.0) * flicker;
    return exp(-dot(d, d)) * flash * smoothstep(0.2, 0.7, cloud) * dark;
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
    float swing = theta + sign(theta) * 0.75 * twilight;
    vec2 lightDir = vec2(sin(swing), cos(swing));
    float sunVis = clamp(max(twilight, daylight * 1.5), 0.0, 1.0);
    vec3 sun = normalize(vec3(lightDir * 0.5, mix(-0.86, -0.08, max(twilight, daylight * 0.85))));
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
    float lon = atan(globe.x, globe.z) + 0.89 - time * 0.0012 - pan * 0.25;
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
        if (detail > 0.001) {
            color += vec3(0.8, 0.92, 1.0) * meteor(p, aspect, scale) * 0.7 * night * skyFade * detail;
            color += vec3(0.85, 0.93, 1.0) * satellite(p, aspect) * 0.8 * mix(0.35, 1.0, night) * skyFade * detail;
        }

        if (artMix > 0.001) {
            float artSize = 0.56;
            vec2 artCenter = vec2(aspect * 0.6 + pan * 0.55, horizon - artSize * 0.28);
            vec2 au = (p - artCenter) / artSize + 0.5;

            vec2 bu = (p - artCenter) / (artSize * 2.4) + 0.5;
            vec3 wash = textureLod(art, clamp(bu, 0.0, 1.0), 6.0).rgb;
            float washMask = exp(-dot(bu - 0.5, bu - 0.5) * 9.0) * smoothstep(0.0, 0.3, bu.y);
            color += wash * wash * washMask * artMix * (0.32 + 0.12 * level);

            vec2 ad = abs(au - 0.5) * 2.0;
            float frame = length(max(ad - 0.46, 0.0)) / 0.54;
            float artMask = pow(clamp(1.0 - frame, 0.0, 1.0), 2.2) * smoothstep(0.0, 0.4, au.y);
            if (artMask > 0.0) {
                vec2 drift = (au - 0.5) * (1.0 - 0.015 * artMix) + 0.5;
                vec3 cover = textureLod(art, clamp(drift, 0.0, 1.0), 1.0).rgb;
                float luma = dot(cover, vec3(0.2126, 0.7152, 0.0722));
                cover = mix(vec3(luma), cover, 0.85);
                cover = cover / (1.0 + cover * 0.6) * mix(0.62, 0.72, daylight);
                float center = 1.0 - 0.35 * exp(-dot(au - vec2(0.5, 0.55), au - vec2(0.5, 0.55)) * 10.0);
                color = mix(color, cover * center + color * 0.25, artMask * artMix * 0.8);
            }
        }

        vec4 moon = moonLayer(p, aspect) * vec4(vec3(mix(0.55, 1.0, night)), 1.0);
        color = mix(color + moon.rgb, moon.rgb, moon.a);

        vec3 atmosphere = inner * exp(-h / 6.0) * 0.45
                        + mix(rim, rimA.rgb, smoothstep(0.0, 80.0, h)) * exp(-h / 38.0) * 0.4
                        + rimA.rgb * exp(-h / 210.0) * 0.14
                        + rimA.rgb * exp(-h / 700.0) * 0.05;
        color += atmosphere * limbLight * glow;
        color += rimB.rgb * exp(-pow((h - 24.0) / 7.0, 2.0)) * 0.07 * night * (0.4 + 0.6 * limbLight) * glow;

        if (detail > 0.001 && h < 600.0) {
            float angle = atan(offset.x, -offset.y);
            float fold = fbm(vec2(angle * 9.0 + time * 0.004, time * 0.003), 2) - 0.5;
            float a = angle + fold * 0.035 + h * 0.00012 * fold;
            float ribbon = fbm(vec2(a * 22.0 + time * 0.006, time * 0.005), 3);
            float floorH = 12.0 + 26.0 * fbm(vec2(a * 14.0, time * 0.006 + 3.1), 2);
            float lift = h - floorH;
            float reach = 80.0 * (1.0 + 0.4 * swell);
            float rayA = noise(vec2(a * 240.0 - time * 0.006, h * 0.002));
            float rayB = noise(vec2(a * 400.0 + time * 0.004, h * 0.0012 + 7.0));
            float rays = 0.4 + 0.6 * smoothstep(0.2, 0.85, rayA * 0.6 + rayB * 0.4);
            float body = exp(-max(lift, 0.0) / reach) * rays + exp(-max(lift, 0.0) / 7.0) * 0.5;
            float curtain = smoothstep(0.38, 0.7, ribbon) * smoothstep(-4.0, 3.0, lift) * body;
            color += mix(rimB.rgb, rimA.rgb, smoothstep(0.0, 120.0, lift)) * curtain * (1.0 - facing) * (0.5 + 0.5 * swell) * night * glow * detail;
        }

        if (sunVis > 0.001) {
            vec2 sunPos = center + vec2(sunDir.x, -sunDir.y) * (radius + 0.05 + 0.22 * daylight);
            float d = length(p - sunPos) * scale;
            vec3 warm = mix(vec3(1.0, 0.97, 0.92), vec3(1.0, 0.84, 0.68), twilight);
            float wash = exp(-d / 520.0) * 0.12 * twilight;
            color += mix(warm, rimB.rgb, 0.6) * wash * sunVis;
            color += mix(rimB.rgb, vec3(1.0, 0.8, 0.64), 0.5) * exp(-h / 60.0) * pow(facing, 6.0) * 0.25 * twilight;
        }
        skyColor = color;
    }

    if (coverage > 0.0) {
        vec3 color;
        vec2 earthSize = earthRes;
        float footprint = max(length(gradX * earthSize), length(gradY * earthSize));
        float magnify = clamp(1.0 - footprint, 0.0, 1.0);
        vec4 surfaceMap = earthSample(earthUv, gradX, gradY, earthSize);
        vec2 cloudUv = vec2(fract(earthUv.x + time * 0.00012), earthUv.y);
        float lightSpread = max(1.0, 1.75 / max(footprint, 1e-4));
        float lights = textureGrad(earth, earthUv, gradX * lightSpread, gradY * lightSpread).r;
        float terrain = surfaceMap.b;
        float cloudRaw = earthSample(cloudUv, gradX, gradY, earthSize).g;
        vec2 cloudCell = cloudUv * earthSize * 2.0;
        float cloudGrain = noiseWrap(cloudCell, earthSize.x * 2.0) * 0.6 + noiseWrap(cloudCell * 2.0 + 5.3, earthSize.x * 4.0) * 0.4;
        cloudRaw += (cloudGrain - 0.5) * 0.22 * magnify * smoothstep(0.02, 0.3, cloudRaw) * smoothstep(1.0, 0.6, cloudRaw);
        float cloud = smoothstep(0.12, 0.85, cloudRaw);
        float land = smoothstep(0.015, 0.07, terrain);
        vec2 texel = max(vec2(footprint), vec2(1.0)) / earthSize;
        float heightEast = textureGrad(earth, vec2(fract(earthUv.x + texel.x), earthUv.y), gradX, gradY).b - terrain;
        float heightNorth = textureGrad(earth, vec2(earthUv.x, clamp(earthUv.y - texel.y, 0.0, 1.0)), gradX, gradY).b - terrain;
        float grain = noiseWrap(earthUv * earthSize * 3.0, earthSize.x * 3.0);
        float relief = smoothstep(0.05, 0.9, terrain + (grain - 0.5) * 0.08 * magnify * land);

        float lambert = dot(n, sun);
        float globeLon = atan(globe.x, globe.z);
        float globeLat = asin(clamp(globe.y, -1.0, 1.0));
        vec3 eastG = vec3(cos(globeLon), 0.0, -sin(globeLon));
        vec3 northG = vec3(-sin(globeLat) * sin(globeLon), cos(globeLat), -sin(globeLat) * cos(globeLon));
        vec3 east = vec3(eastG.x, cos(tilt) * eastG.y + sin(tilt) * eastG.z, -sin(tilt) * eastG.y + cos(tilt) * eastG.z);
        vec3 north = vec3(northG.x, cos(tilt) * northG.y + sin(tilt) * northG.z, -sin(tilt) * northG.y + cos(tilt) * northG.z);
        float bump = clamp(-2.2 * (heightEast * dot(sun, east) + heightNorth * dot(sun, north)), -0.45, 0.45);
        float day = smoothstep(-0.02, 0.3, lambert) * sunVis;
        float fresnel = pow(1.0 - n.z, 4.0);

        vec2 shadowUv = vec2(fract(cloudUv.x - sun.x * 0.006), clamp(cloudUv.y + sun.y * 0.006, 0.0, 1.0));
        float shadow = smoothstep(0.2, 0.85, textureGrad(earth, shadowUv, gradX, gradY).g) * (1.0 - cloud) * day;

        vec4 coarse = textureGrad(earth, earthUv, gradX * 6.0, gradY * 6.0);
        float sea = 1.0 - land;
        float shelf = smoothstep(0.004, 0.07, coarse.b) * sea;
        float sunlit = smoothstep(-0.12, 0.08, lambert) * (0.22 + 0.78 * clamp(lambert, 0.0, 1.0));
        vec3 sunLight = mix(vec3(1.0, 0.72, 0.5), vec3(1.0, 0.97, 0.94), smoothstep(-0.02, 0.3, lambert)) * sunlit * sunVis * glow + vec3(0.55, 0.65, 0.8) * 0.07;
        vec3 deep = mix(ocean.rgb, shoal.rgb, 0.1 + 0.6 * shelf);
        vec3 waterColor = surface.rgb * 0.6 + deep * (0.12 + 0.1 * shelf) * sunLight;
        float skyFresnel = 0.02 + 0.98 * pow(1.0 - n.z, 5.0);
        waterColor += mix(rim, inner, 0.4) * skyFresnel * 0.3 * (0.15 + 0.85 * day) * glow;

        vec3 soil = mix(vec3(0.08, 0.09, 0.1), vec3(0.42, 0.41, 0.4), relief);
        vec3 ground = surface.rgb * 1.7 + soil * sunLight;
        color = mix(waterColor, ground, land);
        color *= 1.0 + bump * land * day;
        color *= 1.0 - 0.4 * shadow;

        float water = sea * (1.0 - cloud);
        vec2 toMoon = normalize(vec2(aspect * 0.84 + pan * 0.45, 0.19) - center);
        vec3 moonLight = normalize(vec3(toMoon.x * 0.5, -toMoon.y * 0.5, -0.8));
        float sunward = day > 0.001 ? dot(n, normalize(sun + vec3(0.0, 0.0, 1.0))) : 0.0;
        float moonward = night > 0.001 && day < 0.999 ? dot(n, normalize(moonLight + vec3(0.0, 0.0, 1.0))) : 0.0;
        if (water > 0.001 && max(sunward, moonward) > 0.85) {
            vec3 waveNormal = n;
            float roughness = 0.14 * (1.0 - 0.25 * shelf);
            if (detail > 0.001) {
                vec2 wind = earthUv * vec2(128.0, 22.75);
                vec3 gust = waveNoise(wind + vec2(0.004, 0.0015) * time, 128.0);
                vec3 chop = waveNoise(wind * 4.0 + vec2(-0.01, 0.006) * time + 17.0, 512.0);
                float resolve = smoothstep(4.0, 1.0, footprint * 512.0 / earthSize.x) * detail;
                roughness *= 1.0 + (gust.x * 0.4 + chop.x * 0.12) * detail;
                vec2 slope = chop.yz * 0.004 * resolve;
                waveNormal = normalize(n + east * slope.x - north * slope.y);
            }
            float view = max(n.z, 0.1);
            float haze = exp(-0.07 / view);
            vec3 sunTint = mix(vec3(0.9, 0.95, 1.0), vec3(1.0, 0.82, 0.64), twilight);
            if (sunward > 0.85) {
                float sunGlint = glintLobe(waveNormal, sun, roughness, 0.42) * 0.3 / (4.0 * view);
                color += sunTint * sunGlint * haze * water * day * (0.3 + 0.7 * sunVis) * (1.0 - 0.7 * shadow) * glow;
            }
            if (moonward > 0.85) {
                float moonLit = 0.5 - 0.5 * cos(TAU * moonPhase);
                float moonGlint = glintLobe(waveNormal, moonLight, roughness * 1.2, 0.0) / (4.0 * view);
                color += vec3(0.7, 0.8, 0.95) * moonGlint * haze * water * moonLit * 0.13 * night * (1.0 - day);
            }
        }
        float coast = land * (1.0 - land) * 4.0;
        color += rim * coast * 0.04 * (0.3 + 0.7 * day) * glow;
        color = mix(color, surface.rgb * 2.8 + rim * 0.025 + vec3(0.8, 0.84, 0.88) * sunLight, cloud * 0.8);
        float haze = 1.0 - exp(-0.06 / max(n.z, 0.05));
        color = mix(color, mix(rimA.rgb, inner, 0.35) * 0.42 * smoothstep(-0.25, 0.35, lambert) * glow, haze);
        color += rim * smoothstep(-0.15, 0.0, lambert) * (1.0 - day) * 0.03 * glow;
        float dusk = exp(-pow((lambert - 0.02) / 0.07, 2.0));
        color += mix(rimA.rgb, rimB.rgb, fresnel) * dusk * (0.035 + 0.12 * fresnel) * glow;
        color += vec3(1.0, 0.78, 0.6) * dusk * 0.06 * twilight;

        float bloom = coarse.r;
        float core = smoothstep(0.0, 0.7, lights) * (0.35 + 0.65 * lights);
        float spill = smoothstep(0.05, 0.5, bloom);
        float veil = (1.0 - 0.8 * cloud) * (1.0 - day) * (0.3 + 0.9 * night);
        color += (vec3(0.86, 0.94, 1.0) * core * 0.65 + rimB.rgb * spill * 0.16) * veil;
        if (detail > 0.001) {
            color += vec3(0.78, 0.9, 1.0) * lightning(local, cloud, (1.0 - day) * night) * 0.9 * detail;
        }

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
    color += vec3(0.86, 0.95, 1.0) * (glint + streak) * (0.25 + 0.75 * daylight) * (1.0 - 0.75 * sunVis) * glow;

    if (sunVis > 0.001) {
        vec2 sunPos = center + vec2(sunDir.x, -sunDir.y) * (radius + 0.05 + 0.22 * daylight);
        vec2 s = (p - sunPos) * scale;
        float d = length(s);
        vec3 warm = mix(vec3(1.0, 0.97, 0.93), vec3(1.0, 0.82, 0.64), twilight);
        float tail = 0.14 / (1.0 + d * d / 5000.0) + exp(-d / 150.0) * 0.08;
        color += (warm * tail + mix(warm, rimB.rgb, 0.45) * exp(-d / 380.0) * 0.05) * sunVis;
        if (d < 650.0) {
            float size = 11.0;
            float mu = sqrt(max(0.0, 1.0 - d * d / (size * size)));
            float disc = smoothstep(size + 1.0, size - 1.0, d) * (0.75 + 0.25 * mu);
            float beyond = max(d - size, 0.0);
            float halo = exp(-beyond / 4.5) * 1.3 + exp(-beyond / 14.0) * 0.5 + exp(-d / 42.0) * 0.16;
            float reach = 48.0 + 30.0 * daylight;
            float spikes = 0.0;
            for (int i = 0; i < 6; i++) {
                float angle = 0.27 + float(i) * PI / 6.0;
                vec2 axis = vec2(cos(angle), sin(angle));
                float along = abs(dot(s, axis));
                float across = dot(s, vec2(-axis.y, axis.x));
                float width = 0.5 + along * 0.012;
                float major = 1.0 - float(i % 2) * 0.72;
                spikes += major * exp(-across * across / (width * width)) * exp(-along / (reach * (0.45 + 0.55 * major)));
            }
            spikes *= 0.36 * smoothstep(650.0, 320.0, d);
            color += warm * (disc * 2.4 + halo + spikes * (1.0 - 0.85 * coverage)) * sunVis;
        }
    }

    vec3 over = max(color - 0.72, 0.0);
    color = min(color, vec3(0.72)) + 0.28 * (1.0 - exp(-over / 0.28));

    vec2 v = uv - vec2(0.5, 0.45);
    color *= clamp(1.0 - 0.8 * dot(v, v), 0.5, 1.0);
    color += (hash(pixel) - 0.5) * 0.01;
    fragColor = vec4(max(color, vec3(0.0)), 1.0) * qt_Opacity;
}
