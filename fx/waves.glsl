// waves — realistic surf along the bottom; every few seconds a long, wide swell peels from one end to the other, throwing spray and a broad band of lacy white water.
// zh: 海浪
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float PERIOD    = 8.0;    // seconds between two big breaking waves
const float BIG       = 0.130;  // height of the big wave above sea level, in window heights
const float SPAN      = 0.78;   // width of the big wave, as a fraction of the window width
const float PEEL      = 1.8;    // seconds for the break to run from one end of the crest to the other
const float SEA       = 0.10;   // mean sea level, in window heights from the bottom
const float FOAM_CELL = 0.0080; // size of the foam bubbles/lace cells (window heights)
const int   DROPS     = 28;     // spray droplets thrown up along the peeling lip
const float OPACITY   = 0.62;   // opacity of the water body (text shows through)

const float BREAK = 3.0;        // seconds into a cycle when the first end starts to break

const vec3 DEEP    = vec3(0.012, 0.085, 0.140);   // shadowed water in the troughs
const vec3 MIDC    = vec3(0.030, 0.220, 0.290);   // ordinary blue-green
const vec3 TURQ    = vec3(0.180, 0.660, 0.620);   // thin crest with light passing through
const vec3 LIPC    = vec3(0.330, 0.780, 0.720);   // the thin pitching lip, lit from behind
const vec3 SKY     = vec3(0.640, 0.800, 0.870);   // sky reflected at a grazing angle
const vec3 FAR     = vec3(0.090, 0.250, 0.330);   // the sea further out
const vec3 FOAM    = vec3(0.950, 0.970, 0.975);
const vec3 FOAM_SH = vec3(0.600, 0.740, 0.800);   // foam in its own shadow
const vec3 GLINT   = vec3(1.000, 0.960, 0.860);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash22(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Gentle, wide undulation of the sea surface (we look at the swells face-on).
float swells(float x) {
    float t = iTime;
    return 0.006 * sin(3.1 * x + 0.45 * t) + 0.004 * sin(7.3 * x - 0.60 * t + 1.0)
         + 0.0015 * sin(19.0 * x + 1.3 * t);
}

// Cycle-wide state, set once per pixel in mainImage.
float gXc, gHalf, gH, gS, gSeed, gV, gXr;

// Height profile along the crest: broad and flat-topped, tapering at both ends.
float envelope(float x) {
    float u = (x - gXc) / gHalf;
    return exp(-2.3 * u * u * u * u) * (0.92 + 0.08 * sin(x * 6.0 + gSeed));   // flat top, soft ends
}

// Seconds since the break reached x (negative: not broken there yet).
// The break starts at the right end and peels toward the left.
float localAge(float x) { return gS - BREAK - (gXr - x) / gV; }

// How much of the wave is still standing after it has broken there.
float standing(float a) { return 1.0 - 0.88 * smoothstep(0.2, 1.6, a); }

float crestY(float x) {
    return SEA + swells(x) + gH * envelope(x) * standing(localAge(x));
}

// Lacy foam: veins between bubble cells (Voronoi F2-F1), thresholded crisply.
// W = 0 nothing, small W thin broken veins, W = 1 nearly solid white water.
float foamMask(vec2 p, float W, float px) {
    if (W < 0.01) return 0.0;
    vec2 g = p / FOAM_CELL;
    g += 0.6 * vec2(vnoise(p * 70.0), vnoise(p * 70.0 + 9.1));   // irregular, not a grid
    vec2 n = floor(g), f = fract(g);
    float F1 = 8.0, F2 = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 c = vec2(float(i), float(j));
        vec2 o = hash22(n + c);
        o = 0.5 + 0.42 * sin(iTime * 0.6 + 6.2831 * o);         // bubbles shift slowly
        vec2 r = c + o - f;
        float d = dot(r, r);
        if (d < F1) { F2 = F1; F1 = d; } else if (d < F2) { F2 = d; }
    }
    float e = sqrt(F2) - sqrt(F1);                                // 0 on the cell borders
    float blot = vnoise(p * 45.0) * 0.6 + vnoise(p * 110.0) * 0.4;
    float th = 1.15 * W - 0.12 + 0.55 * (blot - 0.5);
    float aa = 1.2 * px / FOAM_CELL;
    return smoothstep(th + aa, th - aa, e);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    if (p.y > 0.34) {                        // nothing up here: the text area is free
        fragColor = base;
        return;
    }

    vec3 rgb = base.rgb;
    float px = 1.0 / iResolution.y;          // one pixel in scene units
    float k = INTENSITY;

    // ---- this cycle's wave ----------------------------------------------------------
    float tc = iTime + 1.0;                  // start partway in: a swell is already rising
    float cyc = floor(tc / PERIOD);
    gS = tc - cyc * PERIOD;
    gSeed = cyc * 7.31 + 3.0;
    gHalf = 0.5 * SPAN * aspect;
    gXc = aspect * (0.55 + 0.06 * (hash1(gSeed) - 0.5));
    gXr = gXc + 0.9 * gHalf;
    gV = 1.8 * gHalf / PEEL;
    gH = BIG * (0.90 + 0.20 * hash1(gSeed + 1.0)) * smoothstep(0.0, 2.8, gS)
            * (1.0 - smoothstep(6.6, 8.0, gS));

    float x = p.x;
    float env = envelope(x);
    float a = localAge(x);

    // ---- the sea further out: two calm, paler rows of swell behind --------------
    {
        float t = iTime;
        float h1 = SEA + 0.052 + 0.004 * sin(4.0 * x + 0.3 * t) + 0.002 * sin(11.0 * x - 0.5 * t);
        float h2 = SEA + 0.028 + 0.005 * sin(5.3 * x - 0.4 * t + 2.0) + 0.002 * sin(13.0 * x + 0.7 * t);
        float c1 = smoothstep(0.7 * px, -0.7 * px, p.y - h1);
        float c2 = smoothstep(0.7 * px, -0.7 * px, p.y - h2);
        float st = vnoise(vec2(x * 22.0 + 0.1 * t, p.y * 260.0));
        rgb = mix(rgb, FAR * (0.90 + 0.20 * st), c1 * 0.30 * k);
        rgb = mix(rgb, mix(FAR, MIDC, 0.5) * (0.90 + 0.20 * st), c2 * 0.30 * k);
        rgb = mix(rgb, SKY, smoothstep(-1.6 * px, 0.0, p.y - h1) * c1 * 0.08 * k);
        rgb = mix(rgb, SKY, smoothstep(-1.6 * px, 0.0, p.y - h2) * c2 * 0.08 * k);
    }

    // ---- the near water and the face of the big wave ----------------------------
    float yc = crestY(x);
    float slope = (crestY(x + 0.002) - yc) / 0.002;
    float d = (p.y - yc) / sqrt(1.0 + slope * slope);
    float cov = smoothstep(0.8 * px, -0.8 * px, d);
    float depth = max(-d, 0.0);                        // how far below the crest line
    float faceH = max(yc - SEA - swells(x), 0.0);       // how tall the wave is here

    // The lip pitching out over the face while the break passes.
    float lipLen = 0.0;
    if (a > 0.0 && a < 1.4) {
        lipLen = 0.55 * gH * env * smoothstep(0.0, 0.45, a) * (1.0 - smoothstep(0.6, 1.2, a));
    }

    if (cov > 0.0) {
        // Dark below, blue-green in the body, translucent turquoise near the
        // thin top of the wave where the light comes through.
        vec3 col = mix(MIDC, DEEP, smoothstep(0.6 * faceH, faceH + 0.09, depth));
        float thin = smoothstep(0.012, 0.06, faceH) * (1.0 - smoothstep(0.0, 0.65 * faceH + 0.01, depth));
        col = mix(col, TURQ, thin * 0.9);
        // Horizontal streaks give the face its texture.
        float st = vnoise(vec2(x * 26.0 + 0.2 * iTime, depth * 300.0));
        col *= 0.90 + 0.20 * st;
        if (lipLen > 0.0) {
            // The curling lip: a bright, thin sheet hanging from the crest, with a
            // shadowed hollow (the tube) under it.
            float wob = 0.15 * lipLen * (vnoise(vec2(x * 30.0, a * 2.0)) - 0.5);
            float lb = lipLen + wob;
            float inLip  = smoothstep(lb + px, lb - px, depth);
            float inTube = smoothstep(lb - px, lb + px, depth) * smoothstep(1.5 * lb + px, 1.5 * lb - px, depth);
            col = mix(col, DEEP * 0.8, inTube * 0.75);
            col = mix(col, LIPC * (0.85 + 0.25 * (1.0 - depth / max(lb, 1e-3))), inLip * 0.9);
        }
        float aw = OPACITY * mix(0.85, 1.0, smoothstep(0.0, 0.05, depth));
        rgb = mix(rgb, col, cov * aw * k);
        // Sky reflection right on the crest line (one or two pixels).
        rgb = mix(rgb, SKY, smoothstep(-1.8 * px, -0.2 * px, -depth) * cov * 0.16 * k);

        // Sun glitter: tiny crisp sparkles just under the surface.
        if (depth < 0.024) {
            vec2 gg = vec2(x / 0.016, depth / 0.008);
            vec2 id = floor(gg);
            float h = hash2(id + 17.0);
            float tw = sin(iTime * (2.5 + 4.0 * h) + 6.2831 * hash2(id + 3.1));
            if (h > 0.86 && tw > 0.6) {
                vec2 o = vec2(0.25 + 0.5 * hash2(id + 5.0), 0.3 + 0.4 * h);
                vec2 q = (fract(gg) - o) * vec2(0.016, 0.008);
                float r = length(q * vec2(0.55, 1.6));         // glints are wider than tall
                float g = smoothstep(0.9 * px, 0.2 * px, r) * smoothstep(0.6, 1.0, tw);
                rgb = mix(rgb, GLINT, g * cov * 0.85 * k);
            }
        }
    }

    // ---- foam density -------------------------------------------------------------
    float W = 0.0;
    float edge = smoothstep(0.05, 0.3, env);           // thin out toward the ends of the wave
    // A crisp foam line feathers along the crest just ahead of the break.
    if (a > -0.9 && a < 0.4 && gH > 0.02) {
        float th = 0.002 + 0.008 * smoothstep(-0.9, 0.0, a);
        W = max(W, cov * (1.0 - smoothstep(0.0, th, depth)) * smoothstep(-0.9, -0.5, a) * edge);
    }
    // The lip's leading edge frays into foam as it falls.
    if (lipLen > 0.0) {
        float fr = abs(depth - lipLen) - 0.006 * smoothstep(0.1, 0.6, a);
        W = max(W, cov * (1.0 - smoothstep(0.0, 0.004, fr)) * 0.85 * edge);
    }
    // White water: the lip lands, explodes upward, then a broad band of foam
    // rushes toward us (down the window), thins into lace and fades.
    float ww = a - 0.35 + 0.18 * (vnoise(vec2(x * 28.0, gSeed)) - 0.5);   // ragged, not a straight seam
    if (ww > 0.0) {
        float boom = 0.030 * (gH / BIG) * env * smoothstep(0.0, 0.4, ww) * (1.0 - smoothstep(0.5, 2.2, ww));
        float yImp = yc - 0.5 * gH * env;                       // where the lip lands
        float yT = yc + boom * (0.6 + 0.8 * vnoise(vec2(x * 40.0, ww * 1.5)));
        yT = mix(yImp, yT, smoothstep(0.0, 0.35, ww));          // the splash climbs up the face
        float run = 1.0 - exp(-ww * 0.9);                       // fast at first, then slowing
        float yB = mix(yImp, SEA - 0.07, run)
                 - 0.010 * vnoise(vec2(x * 30.0, ww)) * run;
        if (p.y < yT && p.y > yB - 0.002) {
            float rel = clamp((p.y - yB) / max(yT - yB, 1e-3), 0.0, 1.0);   // 0 at the front
            // Densest in a narrow band at the rushing front, lace behind it.
            float lead = 1.0 - smoothstep(0.006, 0.030, p.y - yB);
            float dens = mix(0.95, mix(0.95, 0.38, smoothstep(0.3, 1.4, ww)), 1.0 - lead);
            dens *= 1.0 - 0.55 * smoothstep(1.2, 3.2, ww);                    // thins into lace
            dens *= 1.0 - smoothstep(3.0, 4.6, ww);                           // and fades away
            float front = smoothstep(yB - 0.002, yB + 0.002, p.y);
            W = max(W, dens * front * edge);
        }
    }
    float foam = foamMask(p, W, px);
    if (foam > 0.0) {
        float under = smoothstep(0.0, 0.05, yc - p.y);
        vec3 fc = mix(FOAM, FOAM_SH, under * 0.6);
        fc *= 0.88 + 0.12 * vnoise(p * 90.0);                    // lumpy, not a flat fill
        rgb = mix(rgb, fc, foam * (0.62 + 0.30 * min(W * 1.4, 1.0)) * k);
    }

    // ---- spray: crisp droplets thrown up where the lip lands ------------------
    float sp0 = gS - BREAK;
    if (sp0 > 0.2 && sp0 < PEEL + 1.8 && p.y > SEA - 0.01) {
        float sp = 0.0;
        for (int j = 0; j < DROPS; j++) {
            float fj = float(j);
            float hj = hash1(fj * 3.1 + gSeed);
            float tj = BREAK + 0.35 + PEEL * hj;                 // when the peel passes its spot
            float tau = gS - tj;
            if (tau < 0.0 || tau > 1.3) continue;
            float xj = gXr - gV * (tj - BREAK - 0.35) + 0.04 * (hash1(fj + gSeed * 2.0) - 0.5);
            float ej = envelope(xj);
            if (ej < 0.3) continue;
            vec2 o = vec2(xj, SEA + 0.75 * gH * ej);
            vec2 v = vec2(0.10 * (hash1(fj * 5.3 + gSeed) - 0.5), 0.10 + 0.24 * hash1(fj * 7.7 + gSeed));
            vec2 pos = o + v * tau + vec2(0.0, -0.50) * tau * tau;
            if (pos.y < SEA) continue;                           // fell back into the sea
            float rad = max((0.0012 + 0.0032 * hash1(fj * 9.1 + gSeed)) * (1.0 - 0.4 * tau), 0.7 * px);
            float dd = length(p - pos) - rad;
            sp = max(sp, smoothstep(0.8 * px, -0.8 * px, dd) * (1.0 - smoothstep(0.9, 1.3, tau)));
        }
        rgb = mix(rgb, FOAM, sp * 0.88 * k);
    }

    fragColor = vec4(rgb, base.a);
}
