// icicles — clear icicles hang under a snowy eave on the right; in the thaw, drops swell at the tips, fall and splash.
// zh: 冰柱
// group: weather
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float START     = 0.56;   // where the eave begins, as a fraction of the window width
const float CELL      = 0.052;  // spacing between icicles, in window heights
const float MAXLEN    = 0.33;   // longest icicle, in window heights
const float DROP_R    = 0.0088; // radius of a full water drop, in window heights
const float GRAV      = 2.2;    // fall acceleration, window heights per second^2
const float GROUND    = 0.014;  // where drops land (just above the bottom edge)
const float SNOW      = 0.92;   // opacity of the snow on the eave

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 v) { return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453); }

// Thickness of the snow ridge at x. Starts thin at the left end so it eases in.
float snowDepth(float x, float aspect) {
    float x0 = START * aspect;
    float f = smoothstep(x0, x0 + 0.10, x);
    // Slow swells plus rounded clumps (|sin|^0.5 gives soft lobes with creases between).
    float t = 0.026 + 0.006 * sin(x * 21.0 + 1.3) + 0.003 * sin(x * 53.0 + 0.4)
            + 0.008 * sqrt(abs(sin(x * 34.0 + 1.5 * sin(x * 9.0))));
    return t * f;
}

// One icicle per cell: position, length, root half-width, sideways bend.
// Returns false when the cell holds no icicle (outside the eave).
bool icicle(float c, float aspect, out float x0, out float len, out float w0,
            out float bend, out float seed) {
    seed = c * 13.17 + 3.1;
    x0 = (c + 0.5 + 0.6 * (hash1(seed + 1.1) - 0.5)) * CELL;
    float xs = START * aspect + 0.04;
    if (x0 < xs || x0 > aspect - 0.012) return false;
    float h = hash1(seed);
    // Mostly short and medium ones, a few long ones; shorter near the left end.
    len = (0.035 + (MAXLEN - 0.035) * pow(h, 1.0)) * smoothstep(xs - 0.02, xs + 0.14, x0);
    w0 = 0.005 + 0.062 * len;
    bend = (hash1(seed + 2.3) - 0.5) * 0.016;
    return len > 0.012;
}

// A water drop: dark-rimmed lens, a bright crescent opposite the light and a
// sharp specular dot. rad = radii in window heights.
vec3 drop(vec3 rgb, vec2 p, vec2 c, vec2 rad, float px, float alpha) {
    vec2 q = (p - c) / rad;
    float l = length(q);
    float dist = (l - 1.0) * min(rad.x, rad.y);
    float cov = clamp(0.5 - dist / px, 0.0, 1.0) * alpha;
    if (cov <= 0.0) return rgb;
    vec3 col = rgb * 0.62 + vec3(0.07, 0.09, 0.11);                 // lens darkens and inverts
    col *= 1.0 - 0.35 * smoothstep(0.72, 1.0, l);                    // dark rim
    float cres = smoothstep(0.45, 0.85, l) * smoothstep(1.0, 0.85, l)
               * smoothstep(0.1, 0.7, -q.y + 0.4 * q.x);
    col += vec3(0.70, 0.82, 0.92) * cres * 0.75;                     // light focused through the drop
    float sp = length(q - vec2(-0.36, 0.40)) * min(rad.x, rad.y);
    float spec = clamp(0.5 - (sp - 0.24 * min(rad.x, rad.y)) / px, 0.0, 1.0);
    col = mix(col, vec3(1.0), spec);
    return mix(rgb, col, cov);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;                                  // one pixel, in scene units

    vec3 rgb = base.rgb;
    // Nothing is drawn on the left part of the window: skip it entirely.
    if (p.x < START * aspect - 0.06 || INTENSITY <= 0.0) { fragColor = base; return; }

    float cc = floor(p.x / CELL);
    for (int k = -1; k <= 1; k++) {
        float c = cc + float(k);
        float x0, len, w0, bend, seed;
        if (!icicle(c, aspect, x0, len, w0, bend, seed)) continue;
        float yr = 1.0 - snowDepth(x0, aspect) * 0.6;               // root, hidden in the snow
        float d = yr - p.y;                                          // depth below the root
        vec2 tip = vec2(x0 + bend, yr - len);

        // ------------------------------------------------ the icicle itself
        if (d > -0.004 && d < len + 0.002 && abs(p.x - x0) < w0 * 1.8 + 0.02) {
            float s = clamp(d / len, 0.0, 1.0);
            float cx = x0 + bend * s * s;
            float rip = 1.0 + 0.075 * sin(d * 150.0 + seed) + 0.04 * sin(d * 410.0 + seed * 2.0);
            float w = w0 * pow(1.0 - s, 0.9) * rip * (1.0 + 0.55 * exp(-d / 0.010));
            float dist = abs(p.x - cx) - w;
            float cov = clamp(0.5 - dist / px, 0.0, 1.0);
            if (cov > 0.0) {
                float u = (p.x - cx) / max(w, 1e-4);                 // -1 left edge, +1 right edge
                float au = abs(u);
                // Clear ice: the scene shows through, cooled and slightly darkened,
                // with a darker refracted band on the shadow side.
                float band = smoothstep(0.05, 0.30, u) * smoothstep(0.80, 0.50, u);
                float band2 = smoothstep(-0.05, -0.20, u) * smoothstep(-0.48, -0.32, u);
                vec3 col = rgb * vec3(0.78, 0.86, 0.92) * (1.0 - 0.45 * band - 0.25 * band2);
                // Edges reflect the bright sky (Fresnel).
                col = mix(col, vec3(0.78, 0.88, 0.98), 0.10 + 0.55 * pow(au, 4.0));
                // A milky core of trapped air, uneven along the length.
                float core = exp(-pow((u + 0.12) / 0.16, 2.0)) * (0.5 + 0.5 * sin(d * 70.0 + seed * 3.0));
                col = mix(col, vec3(0.86, 0.92, 0.98), 0.22 * core * smoothstep(0.0, 0.25, 1.0 - s));
                // Crisp speculars: a main streak on the lit (left) side that breaks up
                // on the ripples, and a thin rim on the right.
                float sw = max(0.09, 1.1 * px / max(w, 1e-4));
                float spec = smoothstep(sw, 0.0, abs(u + 0.56))
                           * (0.45 + 0.55 * smoothstep(-0.3, 0.8, sin(d * 150.0 + seed + 1.1)));
                float spec2 = smoothstep(sw * 0.8, 0.0, abs(u - 0.84)) * 0.40;
                // Now and then a glint slides down the icicle like running melt.
                float Q = 6.0 + 7.0 * hash1(seed + 4.4);
                float tg = mod(iTime + Q * hash1(seed + 5.5) - 1.0, Q);
                float glint = 0.0;
                if (tg < 1.8) {
                    float dg = len * 0.92 * pow(tg / 1.8, 1.5);
                    float fade = smoothstep(0.0, 0.25, tg) * smoothstep(1.8, 1.4, tg);
                    glint = exp(-pow((d - dg) / 0.009, 2.0)) * smoothstep(0.40, 0.0, abs(u + 0.50)) * fade;
                }
                col += vec3(1.0, 0.99, 0.96) * (spec * 0.80 + spec2 + glint * 1.2);
                // Frosty white root where the ice meets the snow.
                float n = hash2(floor(fragCoord * 0.5));
                float frost = smoothstep(0.045, 0.004, d + 0.014 * (n - 0.5) - 0.008 * hash1(seed + 7.0));
                col = mix(col, vec3(0.90, 0.94, 1.0) * (0.86 + 0.14 * n), frost * 0.92);
                rgb = mix(rgb, col, cov * INTENSITY);
            }
        }

        // ------------------------------------------------ thaw: drops
        if (len < 0.075) continue;
        float P = 10.0 + 10.0 * hash1(seed + 8.1);                   // seconds per drop
        float t = mod(iTime + P * hash1(seed + 9.3) + 2.0, P);
        float G = P - 2.2;                                           // slow swell, then the fall
        if (abs(p.x - tip.x) > 0.06) continue;
        if (t < G) {
            // The drop gathers at the tip, swelling and sagging as it gets heavy.
            float e = t / G;
            float r = DROP_R * mix(0.35, 1.0, pow(e, 0.7));
            vec2 rad = vec2(r, r * (1.0 + 0.30 * e * e));
            vec2 c2 = tip - vec2(0.0, rad.y * 0.80);
            if (length(p - c2) < rad.y + 3.0 * px)
                rgb = drop(rgb, p, c2, rad, px, INTENSITY);
        } else {
            float tf = t - G;
            // A small bead stays behind and starts the next drop.
            vec2 cb = tip - vec2(0.0, DROP_R * 0.30);
            if (length(p - cb) < DROP_R)
                rgb = drop(rgb, p, cb, vec2(DROP_R * 0.35), px, INTENSITY);
            // The falling drop stretches a little with speed.
            float y0 = tip.y - DROP_R * 1.0;
            float y = y0 - 0.5 * GRAV * tf * tf;
            float v = GRAV * tf;
            if (y > GROUND) {
                vec2 rad = vec2(DROP_R * 0.80, DROP_R * 0.80 * (1.0 + min(v * 0.22, 0.55)));
                vec2 c3 = vec2(tip.x, y);
                if (abs(p.y - y) < rad.y + 3.0 * px)
                    rgb = drop(rgb, p, c3, rad, px, INTENSITY);
            }
            // Landing: a thin ring spreads out, seen at a low angle, plus a few
            // tiny droplets thrown up.
            float ts = tf - sqrt(2.0 * (y0 - GROUND) / GRAV);
            if (ts > 0.0 && ts < 0.7 && p.y < GROUND + 0.04) {
                float life = 1.0 - ts / 0.7;
                float R = 0.003 + 0.042 * (1.0 - exp(-ts * 6.0));
                vec2 q = (p - vec2(tip.x, GROUND)) / vec2(1.0, 0.26);
                float ring = abs(length(q) - R) * 0.26;              // rough distance in y units
                float rc = clamp(1.0 - ring / (0.9 * px), 0.0, 1.0);
                rgb = mix(rgb, vec3(0.80, 0.90, 1.0), rc * 0.75 * life * life * INTENSITY);
                for (int j = 0; j < 3; j++) {
                    float fj = float(j);
                    float vx = (fj - 1.0) * 0.07 + (hash1(seed + fj + floor(iTime / P)) - 0.5) * 0.03;
                    float vy = 0.32 + 0.12 * hash1(seed + fj * 2.7);
                    vec2 dp = vec2(tip.x + vx * ts, GROUND + vy * ts - 0.5 * GRAV * ts * ts);
                    if (dp.y < GROUND) continue;
                    float dd = length(p - dp) - 0.0016;
                    rgb = mix(rgb, vec3(0.88, 0.95, 1.0), clamp(0.5 - dd / px, 0.0, 1.0) * 0.85 * INTENSITY);
                }
            }
        }
    }

    // ------------------------------------------------ the snowy eave
    float T = snowDepth(p.x, aspect);
    float yb = 1.0 - T;
    float sc = clamp(0.5 + (p.y - yb) / px, 0.0, 1.0);
    if (sc > 0.0 && T > 0.0) {
        float v = clamp((p.y - yb) / max(T, 1e-4), 0.0, 1.0);        // 0 = lower edge, 1 = top
        // Lumpy clumps, lit from above with a bluish shaded underside.
        float lump = 0.5 + 0.5 * sin(p.x * 160.0 + sin(p.x * 47.0) * 2.0) * sin(p.y * 120.0 + p.x * 30.0);
        float e = (p.y - yb) / 0.014;                                // depth into the snow from its lower edge
        vec3 col = mix(vec3(0.56, 0.64, 0.76), vec3(0.95, 0.97, 1.0), smoothstep(0.0, 1.0, e) * 0.7 + 0.3 * v);
        col *= 0.93 + 0.07 * lump;
        // Fine sparkle of ice crystals in the snow.
        float n = hash2(floor(fragCoord * 0.5));
        float tw = 0.5 + 0.5 * sin(iTime * 1.7 + n * 60.0);
        col += vec3(1.0) * step(0.982, n) * tw * 0.45 * smoothstep(0.2, 0.6, v);
        rgb = mix(rgb, col, sc * SNOW * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
