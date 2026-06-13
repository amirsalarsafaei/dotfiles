/*
 * Pac-Man Neon Maze — Ghostty animated background (revised)
 * Layered neon bloom, emissive sprites, AA shapes, vignette grade.
 */

#define PIXEL 4.0
#define PI 3.14159265
#define SCL 0.070
#define TOTAL (28.0 * SCL)
#define CH 0.030
#define WT 0.009

vec2 gmap(float x, float y){
    float asp = iResolution.x / iResolution.y;
    vec2 ctr  = vec2(asp * 0.5, 0.5);
    return ctr + (vec2(x, y) - vec2(5.0, 3.0)) * SCL;
}

#define FILLWP vec2 wp[10]; \
    wp[0]=gmap(1.,1.); wp[1]=gmap(9.,1.); wp[2]=gmap(9.,5.); wp[3]=gmap(7.,5.); \
    wp[4]=gmap(7.,3.); wp[5]=gmap(5.,3.); wp[6]=gmap(5.,5.); wp[7]=gmap(3.,5.); \
    wp[8]=gmap(3.,3.); wp[9]=gmap(1.,3.);

// soft emissive halo
float halo(float d, float k){ return exp(-d * k); }

vec2 pathDA(vec2 p){
    FILLWP
    float bestD = 1e9, bestS = 0.0, acc = 0.0;
    for (int i = 0; i < 10; i++){
        int j = i + 1; if (j > 9) j = 0;
        vec2 a = wp[i], b = wp[j], e = b - a;
        float L = length(e);
        float tt = clamp(dot(p - a, e) / dot(e, e), 0.0, 1.0);
        float d = length(p - (a + e * tt));
        if (d < bestD){ bestD = d; bestS = acc + tt * L; }
        acc += L;
    }
    return vec2(bestD, bestS);
}

vec4 pathPos(float s){
    FILLWP
    s = mod(s, TOTAL);
    for (int i = 0; i < 10; i++){
        int j = i + 1; if (j > 9) j = 0;
        vec2 a = wp[i], b = wp[j], e = b - a;
        float L = length(e);
        if (s <= L){ vec2 d = e / L; return vec4(a + d * s, d); }
        s -= L;
    }
    return vec4(wp[0], 1.0, 0.0);
}

// ghost: rgb + coverage in .a, with rounded top shading
vec4 ghost(vec2 d, vec2 dir, vec3 color, float wob){
    float w = 0.017, h = 0.019, a = 0.0;
    if (abs(d.x) < w){
        if (d.y >= 0.0){ if (length(d) < w) a = 1.0; }
        else { float bumps = 0.004 * abs(sin((d.x/w)*PI*2.5 + wob));
               if (d.y > -h + bumps) a = 1.0; }
    }
    // top-lit body shading for a rounded, gummy look
    vec3 cc = color * (1.05 + 0.35 * clamp(d.y / h, -1.0, 1.0));
    vec2 eL = vec2(-0.007, 0.005), eR = vec2(0.007, 0.005);
    if (length(d-eL) < 0.0055 || length(d-eR) < 0.0055) cc = vec3(1.0);
    vec2 pu = dir * 0.0025;
    if (length(d-eL-pu) < 0.0028 || length(d-eR-pu) < 0.0028) cc = vec3(0.10,0.12,0.5);
    return vec4(cc, a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 res = iResolution.xy;
    vec2 pcoord = floor(fragCoord / PIXEL) * PIXEL;
    vec2 uv = pcoord / res; uv.y = 1.0 - uv.y;
    float aspect = res.x / res.y;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float t = iTime;

    // ---------- BACKGROUND ----------
    vec3 col = mix(vec3(0.015,0.016,0.045), vec3(0.050,0.038,0.100), uv.y);
    col += vec3(0.03,0.02,0.06) * halo(length(uv-0.5), 2.0); // soft center bloom

    // ---------- PATH FIELD ----------
    vec2  da = pathDA(p);
    float d  = da.x, s = da.y;

    // faint corridor floor for readability/depth
    if (d < CH) col += vec3(0.02,0.05,0.12) * (1.0 - d/CH) * 0.6;

    // ---------- WALLS (layered neon bloom) ----------
    float pulse = 0.85 + 0.15 * sin(t * 1.5);
    float edge  = abs(d - CH);
    col += vec3(0.10,0.22,0.70) * halo(edge, 120.0) * 0.8 * pulse; // outer haze
    col += vec3(0.20,0.45,1.00) * halo(edge, 340.0) * pulse;       // inner glow
    col += vec3(0.55,0.75,1.00) * smoothstep(WT, 0.0, edge);       // hot core

    // ---------- MOTION ----------
    float spd  = 0.17;
    float pacS = t * spd;
    float pf   = mod(pacS, TOTAL);

    // ---------- PELLETS (AA + glow) ----------
    if (d < CH){
        float idx = floor(s / SCL + 0.5);
        float pa  = idx * SCL;
        if (pa > 0.0 && pa < TOTAL - 0.001 && pa >= pf){
            bool  power = mod(idx, 7.0) < 0.5;
            float pr = power ? 0.011 : 0.006;
            float bl = power ? (0.6 + 0.4*sin(t*6.0)) : 1.0;
            float pd = length(vec2(d, s - pa));
            vec3  pc = power ? vec3(1.0,0.78,0.45) : vec3(1.0,0.88,0.60);
            col += pc * halo(pd, power ? 140.0 : 220.0) * bl * 0.6;     // glow
            col = mix(col, pc, smoothstep(pr, pr*0.55, pd) * bl);       // body
        }
    }

    // ---------- GHOSTS ----------
    vec3 gcol[4];
    gcol[0]=vec3(0.96,0.18,0.20); gcol[1]=vec3(0.99,0.60,0.82);
    gcol[2]=vec3(0.38,0.86,0.98); gcol[3]=vec3(0.99,0.64,0.22);
    for (int i = 0; i < 4; i++){
        vec4 gi = pathPos(pacS - 0.16 * float(i+1));
        vec2 gd = p - gi.xy;
        col += gcol[i] * halo(length(gd), 90.0) * 0.30;        // emissive halo
        vec4 g  = ghost(gd, gi.zw, gcol[i], t*6.0 + float(i));
        col = mix(col, g.rgb, g.a);
    }

    // ---------- PAC-MAN ----------
    vec4 pp = pathPos(pacS);
    vec2 dp = p - pp.xy;
    float pl = length(dp);
    float rad = 0.021;
    vec3 pacCol = vec3(1.0,0.85,0.12);
    col += pacCol * halo(pl, 95.0) * 0.35;                     // glow
    {
        float da2 = atan(pp.w, pp.z);
        float ca = cos(-da2), sa = sin(-da2);
        vec2 ld = vec2(ca*dp.x - sa*dp.y, sa*dp.x + ca*dp.y);
        float ang   = atan(ld.y, ld.x);
        float mouth = (0.5 + 0.5*sin(t*9.0)) * 0.9;
        float body  = smoothstep(rad, rad-0.003, pl);          // AA disc
        float open  = smoothstep(mouth-0.06, mouth, abs(ang)); // soft mouth
        col = mix(col, pacCol, body * open);
        float eye = smoothstep(0.0040, 0.0028, length(ld - vec2(0.005, 0.009)));
        col = mix(col, vec3(0.0), body * open * eye);
    }

    // ---------- GRADE: vignette + lift ----------
    vec2 q = uv - 0.5;
    col *= 1.0 - dot(q, q) * 0.55;                 // vignette
    col = pow(col, vec3(0.92));                     // gentle gamma lift
    col = mix(vec3(dot(col, vec3(0.299,0.587,0.114))), col, 1.12); // saturation

    // ---------- TERMINAL TEXT ON TOP ----------
    vec4 term = texture(iChannel0, fragCoord / res);
    col = mix(col, term.rgb, term.a);

    fragColor = vec4(col, 1.0);
}
