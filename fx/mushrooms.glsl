// mushrooms — time-lapse of bioluminescent Mycena in the lower right: glowing buttons push up through the moss, open into bells, pulse and puff out clouds of spores, then wither and sink as new ones sprout.
// zh: 发光蘑菇
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float SCALE     = 1.00;   // size of the cluster (1 = tallest mushroom ~30% of window height)
const float CYCLE     = 13.0;   // seconds per life cycle: sprout, grow, glow, spore, wither
const float START     = 2.0;    // seconds into the cycle at switch-on, so it is visible at once
const float GLOW      = 1.00;   // brightness of the bioluminescence
const float HALO      = 0.22;   // strength of the tight halo around each cap (keep small)
const float SPORES    = 1.00;   // brightness / density of the spore clouds
const float WIND      = -0.016; // sideways drift of the spores (window heights per second, - = left)
const float GROUND_A  = 0.88;   // opacity of the moss / leaf-litter strip

const float PI = 3.14159265;
const vec3  EMIT  = vec3(0.42, 1.00, 0.74);  // cool green-cyan bioluminescence
const vec3  FLESH = vec3(0.13, 0.17, 0.15);  // translucent cap flesh where it is not glowing
const vec3  DEAD  = vec3(0.17, 0.14, 0.10);  // withered, browned flesh

const int NM = 6;   // mushrooms in the cluster
// Full-grown height of each mushroom (window heights) and its lane in the first cycle.
const float HT[NM]   = float[](0.300, 0.215, 0.140, 0.255, 0.170, 0.115);
const float ORDER[NM] = float[](1.0, 3.0, 0.0, 4.0, 2.0, 5.0);
// Lanes: distance of the stem from the right edge.
const float LANE[NM] = float[](0.075, 0.165, 0.255, 0.345, 0.440, 0.535);
// Life-cycle times (seconds into the cycle).
const float PUFF0 = 6.3;        // first spore puff (then one per PUFFGAP)
const float PUFFGAP = 1.05;
const float PUFFLIFE = 4.0;     // how long one spore cloud lasts

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float vnoise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Top of the moss strip: low lumps plus fine tufts.
float groundY(float x) {
    return 0.042 * SCALE
         + 0.006 * sin(x * 23.0 + 1.3) + 0.004 * sin(x * 61.0 + 0.4)
         + 0.0025 * pow(abs(sin(x * 210.0)), 3.0);
}

// Cap profile, in units of the cap half-width (rim chord at y = 0).
float domeTop(float x, float hc) {
    float a = 1.0 - min(abs(x), 1.0);
    return hc * (0.72 * sqrt(max(1.0 - x * x, 0.0)) + 0.28 * a * a);
}

// Per-mushroom state for this frame.
struct Shroom {
    vec2 B, T;          // stem base, cap centre
    float h, w;         // stem length, cap half-width
    float lean, bend, capLean;
    float open;         // 0 closed button .. 1 open bell
    float br;           // glow strength
    float alpha;        // overall presence (fades as it sinks)
    float wither;       // 0 fresh .. 1 shrivelled
    float lt;           // seconds into its own cycle
    float seed;
};

Shroom lifeOf(int i, float aspect) {
    Shroom m;
    float fi = float(i);
    // Staggered starts, so the cluster grows one after another.
    float d = fi * 0.72 + 0.25 * hash1(fi * 3.1 + 0.7);
    float u = (iTime + START - d) / CYCLE;
    float cyc = floor(u);
    float lt = (u - cyc) * CYCLE;
    float sd = fi * 17.3 + cyc * 7.9;
    m.lt = lt; m.seed = sd;

    // Every cycle the mushrooms come up in different spots.
    float lane = mod(ORDER[i] + 2.0 * cyc, float(NM));
    float bx = aspect - (LANE[int(lane)] + (hash1(sd + 5.0) - 0.5) * 0.045) * SCALE;
    float H = HT[i] * (0.92 + 0.14 * hash1(sd)) * SCALE;
    float W = H * (0.155 + 0.035 * hash1(sd + 1.0));
    float lean0 = (hash1(sd + 2.0) - 0.62) * 0.36;      // most lean away from the edge
    float side = lean0 < 0.0 ? -1.0 : 1.0;

    // Stages of the time-lapse.
    float emerge = smoothstep(0.0, 1.3, lt);             // primordium pushes through the moss
    float grow   = smoothstep(0.6, 5.2, lt);             // stem elongates
    float wide   = smoothstep(0.3, 4.8, lt);             // cap swells
    m.open       = smoothstep(2.4, 5.6, lt);             // button opens into a bell
    m.wither     = smoothstep(9.4, 11.6, lt);            // droops and dims
    float sink   = smoothstep(10.8, 12.6, lt);           // collapses into the moss

    float hcFull = 1.1;
    m.w = W * (0.30 + 0.70 * wide) * (1.0 - 0.18 * m.wither);
    m.h = max(H - hcFull * W, 0.02) * (0.05 + 0.95 * grow) * (1.0 - 0.25 * m.wither);
    m.lean = lean0 * (0.4 + 0.6 * grow) + side * 0.50 * m.wither;
    m.bend = (hash1(sd + 3.0) - 0.5) * 0.4 - 0.25 * lean0 + side * 0.35 * m.wither;
    float gy = groundY(bx) - 0.004;
    float hidden = m.h + 2.4 * m.w;
    m.B = vec2(bx, gy - (1.0 - emerge) * hidden - sink * 0.6 * m.h);
    m.T = m.B + rot(vec2(0.0, m.h), -m.lean);
    m.capLean = m.lean + atan(-m.bend) * 0.8 + side * 0.9 * m.wither;

    // Glow: faint as a button, brighter as it opens, flaring with each spore puff.
    float br = 0.30 + 0.50 * smoothstep(0.5, 5.5, lt) + 0.25 * smoothstep(5.0, 6.2, lt);
    for (int k = 0; k < 3; k++) {
        float dt = lt - (PUFF0 + PUFFGAP * float(k));
        br += 0.55 * exp(-dt * dt / 0.045);
    }
    br *= 1.0 - 0.88 * m.wither;
    m.br = br * GLOW;
    m.alpha = (1.0 - sink) * smoothstep(0.0, 0.25, lt);
    m.alpha *= step(0.0, u);   // no leftover "previous cycle" at switch-on
    return m;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    float aspect = iResolution.x / iResolution.y;
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Everything lives in the lower right: pixels elsewhere cost nothing.
    float x0 = aspect - 0.72 * SCALE;
    if (p.x < x0 - 0.03 || p.y > 0.80 * SCALE) { fragColor = base; return; }

    float px = 1.0 / iResolution.y;
    vec3 rgb = base.rgb;

    Shroom S[NM];
    for (int i = 0; i < NM; i++) S[i] = lifeOf(i, aspect);

    // ---------------------------------------------------------- mushrooms
    for (int i = 0; i < NM; i++) {
        Shroom m = S[i];
        if (m.alpha <= 0.0) continue;
        float w = m.w, h = m.h;
        vec2 mid = (m.B + m.T) * 0.5 + vec2(0.0, w * 0.5);
        if (abs(p.x - mid.x) > 0.5 * abs(m.T.x - m.B.x) + 1.6 * w + 0.01 ||
            abs(p.y - mid.y) > 0.5 * abs(m.T.y - m.B.y) + 2.2 * w + 0.01) continue;

        float br = m.br;
        float o = m.open;
        float hc = mix(1.45, 1.05 + 0.25 * hash1(m.seed + 8.0), o);   // tall egg -> bell
        float eo = 0.12 + 0.07 * hash1(m.seed + 9.0);                  // underside seen when open
        float e  = mix(0.62, eo, o);                                   // closed: rounded bottom
        float gillW = smoothstep(0.35, 0.9, o);
        float detail = clamp(w * iResolution.y / 30.0 - 0.3, 0.0, 1.0);
        float pw = px / w;
        vec3 flesh0 = mix(FLESH, DEAD, m.wither);
        float A = m.alpha * INTENSITY;

        // ---- cap (drawn first; the stem passes in front of the gills)
        vec2 c = rot(p - m.T, m.capLean) / w;
        float top = domeTop(c.x, hc);
        float ell = sqrt(max(1.0 - c.x * c.x, 0.0));
        float yk = e * ell;
        float sl = abs(domeTop(c.x + 0.01, hc) - domeTop(c.x - 0.01, hc)) * 50.0;
        float dTop = (c.y - top) / sqrt(1.0 + sl * sl);
        float rr = length(vec2(c.x, c.y / e));
        float dEll = (rr - 1.0) * rr / max(length(vec2(c.x, c.y / (e * e))), 1e-3);
        float inDome = smoothstep(pw, -pw, max(dTop, abs(c.x) - 1.0)) * step(0.0, c.y);
        float inEll  = smoothstep(pw, -pw, dEll);
        float capCov = max(inDome, inEll);

        float dOut = max(length(vec2(max(abs(c.x) - 1.0, 0.0), c.y)) - e * ell, 0.0) * w;
        rgb += EMIT * HALO * br * exp(-dOut / (0.0035 * SCALE)) * (1.0 - capCov) * A;

        if (capCov > 0.0) {
            // Outer surface: glows most near the rim, dimmer and browner at the apex.
            float v = clamp((c.y - yk) / max(top - yk, 1e-3), 0.0, 1.0);
            float sa = atan(c.x, hc * 1.05 - c.y);
            float stri = smoothstep(0.55, 0.95, cos(sa * 18.0)) * detail * (0.3 + 0.7 * o);
            float em = mix(1.0, 0.18, pow(v, 0.6)) * (0.80 + 0.45 * stri * (1.0 - v));
            em *= 0.85 + 0.25 * abs(c.x);
            vec3 flesh = mix(flesh0, vec3(0.20, 0.17, 0.12), smoothstep(0.6, 1.0, v));
            vec3 outer = flesh + EMIT * em * br * 0.95;
            float aOut = 0.62 + 0.25 * (1.0 - v);
            vec3 col = outer; float a = aOut;
            if (!(c.y > yk || rr > 1.0)) {
                // Underside: closed it is just more cap; open it shows luminous radial gills.
                float phi = atan(c.y / e, c.x);
                float g = smoothstep(0.2, 0.9, cos(phi * 22.0)) * detail;
                float emg = (0.70 + 0.45 * g) * (0.55 + 0.6 * rr) + smoothstep(0.85, 1.0, rr) * 0.5;
                vec3 gills = mix(vec3(0.10, 0.14, 0.12), DEAD * 0.8, m.wither) + EMIT * emg * br;
                vec3 closed = flesh0 + EMIT * br * (0.75 - 0.3 * (c.y / max(-e, -1.0)));
                col = mix(closed, gills, gillW);
                a = mix(aOut, 0.80, gillW);
            }
            rgb = mix(rgb, col, capCov * a * A);
        }

        // ---- stem: slender, slightly curved, translucent, brighter toward the cap
        vec2 q = rot(p - m.B, m.lean);
        float s = q.y / max(h, 1e-4);
        if (s > -0.02 && s < 1.0) {
            float cx = m.bend * h * s * (1.0 - s);
            float r = w * mix(0.15, 0.10, s) * (1.0 + 0.5 * exp(-s * 14.0)) * mix(1.6, 1.0, o);
            float d = abs(q.x - cx) - r;
            float cov = smoothstep(px, -px, d) * smoothstep(-0.02, 0.01, s);
            cov *= 1.0 - inDome * step(0.0, c.y) * (1.0 - inEll);
            if (cov > 0.0) {
                float across = (q.x - cx) / r;
                float fib = 0.92 + 0.08 * sin(across * 9.0 + s * 3.0);
                float em = (0.12 + 0.55 * s * s) * (0.75 + 0.35 * across * across) * fib;
                vec3 col = mix(vec3(0.14, 0.17, 0.15), DEAD, m.wither) * (0.8 + 0.2 * s) + EMIT * em * br;
                rgb = mix(rgb, col, cov * 0.78 * A);
            }
        }
    }

    // ---------------------------------------------------------- spore clouds
    // Each puff is a field of crisp specks: a grid in "cloud space" that expands,
    // rises, stretches into a column and swirls sideways, so we only test one cell.
    for (int i = 0; i < NM; i++) {
        Shroom m = S[i];
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float tau = m.lt - (PUFF0 + PUFFGAP * fk);
            if (tau < 0.0 || tau > PUFFLIFE) continue;
            vec2 src = m.T + rot(vec2(0.0, -0.15 * m.w), -m.capLean);
            float Rx = m.w * (0.8 + 2.0 * (1.0 - exp(-1.5 * tau)));
            float rise = (0.018 * tau + 0.008 * tau * tau) * SCALE;
            float Ry = Rx * 0.75 + 0.35 * rise;
            float cy = (p.y - src.y - rise) / Ry;
            if (abs(cy) > 2.0) continue;
            float cx = (p.x - src.x - WIND * SCALE * tau
                        - 0.3 * Rx * sin(cy * 2.2 + tau * 1.1 + fk * 2.0)) / Rx;
            vec2 cc = vec2(cx, cy);
            float r2 = dot(cc, cc);
            if (r2 > 4.0) continue;

            const float CELL = 0.17;
            vec2 cid = floor(cc / CELL);
            vec2 f = fract(cc / CELL);
            vec2 key = cid + vec2(m.seed * 1.37 + fk * 7.1, fk * 3.3);
            float hh = hash2(key);
            if (hh > exp(-r2 * 1.4) * 0.42 * SPORES) continue;  // denser in the middle
            vec2 dp = 0.25 + 0.5 * vec2(hash2(key + 1.7), hash2(key + 3.3));
            // Map the speck's own cloud position back to the screen (exact, so specks stay round).
            vec2 cd = (cid + dp) * CELL;
            vec2 wpos = vec2(src.x + WIND * SCALE * tau + Rx * cd.x
                             + 0.3 * Rx * sin(cd.y * 2.2 + tau * 1.1 + fk * 2.0),
                             src.y + rise + Ry * cd.y);
            float d = length(p - wpos);
            float h2 = hash2(key + 5.9);
            float rad = (0.7 + 0.9 * h2) * px;
            float end = 1.8 + 2.6 * hash2(key + 8.1);         // each speck winks out on its own
            float fade = smoothstep(0.0, 0.3, tau) * (1.0 - smoothstep(end - 0.5, end, tau));
            float core = smoothstep(rad + 0.75 * px, rad - 0.25 * px, d);
            float gl = exp(-d / (1.8 * px)) * 0.28;
            rgb += EMIT * (core * 0.9 + gl) * fade * (0.55 + 0.45 * h2)
                 * m.alpha * INTENSITY;
        }
    }

    // ---------------------------------------------------------- moss strip (in front of stem bases)
    float gy = groundY(p.x);
    float fadeL = smoothstep(x0, x0 + 0.20 * SCALE, p.x);
    if (p.y < gy + 0.01 && fadeL > 0.0) {
        float light = 0.0;
        for (int i = 0; i < NM; i++) {
            Shroom m = S[i];
            vec2 dd = (p - vec2(m.T.x * 0.6 + m.B.x * 0.4, groundY(m.B.x)))
                    / vec2(5.0 * m.w + 0.03, 2.0 * m.w + 0.02);
            light += m.br * m.alpha * (m.w / 0.035) * exp(-dot(dd, dd));
        }
        light = min(light, 1.6);
        float cov = smoothstep(px, -px, p.y - gy) * fadeL;
        float n = 0.6 * vnoise(p * 260.0) + 0.4 * vnoise(p * 900.0);
        float depth = clamp((gy - p.y) / 0.04, 0.0, 1.0);
        vec3 moss = mix(vec3(0.030, 0.045, 0.028), vec3(0.055, 0.075, 0.035), n);
        moss *= 1.0 - 0.55 * depth;
        moss += EMIT * vec3(0.55, 0.80, 0.55) * light * (0.06 + 0.14 * n) * (1.0 - 0.7 * depth);
        // Stems below the moss line stay hidden, so the moss is fully opaque at its top
        // where they emerge and fades to GROUND_A further down.
        rgb = mix(rgb, moss, cov * mix(1.0, GROUND_A, depth) * INTENSITY);

        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float tx = aspect - (0.12 + 0.20 * fk + 0.05 * hash1(fk + 7.0)) * SCALE;
            vec2 a = vec2(tx - 0.07 * SCALE, groundY(tx - 0.07 * SCALE) - 0.006);
            vec2 b = vec2(tx + 0.06 * SCALE, groundY(tx + 0.06 * SCALE) - 0.012 + 0.006 * fk);
            float r = (0.0022 + 0.0008 * fk) * SCALE;
            float d = segment(p, a, b) - r;
            float c = smoothstep(px, -px, d) * fadeL;
            float top = smoothstep(-r, 0.0, d) * step(0.0, dot(p - a, vec2(-(b - a).y, (b - a).x)));
            vec3 tw = vec3(0.07, 0.055, 0.045) + EMIT * light * (0.12 + 0.25 * top);
            rgb = mix(rgb, tw, c * 0.92 * INTENSITY);
        }

        for (int k = 0; k < 6; k++) {
            float fk = float(k);
            float h1 = hash1(fk * 4.3 + 11.0), h2 = hash1(fk * 2.9 + 3.0);
            float lx = aspect - (0.04 + 0.125 * fk + 0.04 * h1) * SCALE;
            vec2 c0 = vec2(lx, groundY(lx) - 0.004);
            float L = (0.020 + 0.016 * h2) * SCALE;
            float ang = (h1 - 0.5) * 0.7;
            vec2 q = rot(p - c0, ang) / L;
            q.y /= 0.35 + 0.35 * h2;
            if (abs(q.x) > 1.05 || abs(q.y) > 0.6) continue;
            float s = (q.x + 1.0) * 0.5;
            float hw = 0.42 * pow(max(sin(PI * s), 0.0), 0.8) * (1.0 - 0.25 * s);
            float d = (abs(q.y) - hw) * L * (0.35 + 0.35 * h2);
            float cov2 = smoothstep(px, -px, d) * fadeL;
            float rib = smoothstep(1.2 * px, 0.0, abs(q.y) * L * (0.35 + 0.35 * h2)) * step(abs(q.x), 0.9);
            vec3 lc = mix(vec3(0.10, 0.060, 0.035), vec3(0.15, 0.090, 0.045), h1);
            lc *= 0.85 + 0.3 * q.y;
            lc += vec3(0.04, 0.03, 0.02) * rib;
            lc += EMIT * light * 0.09;
            rgb = mix(rgb, lc, cov2 * 0.95 * INTENSITY);
        }
    }

    fragColor = vec4(rgb, base.a);
}
