// sparkles — an invisible wand traces a glowing ribbon of light that leaves twinkling star glitter behind.
// zh: 魔法火花
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.80;   // overall strength (0 = off)
const float PERIOD    = 8.0;    // seconds between the starts of two spells
const float DRAW_TIME = 4.8;    // seconds the wand takes to trace one ribbon
const float TRAIL     = 0.26;   // comet trail length, as a share of the whole curve
const float LIFE      = 8.5;    // seconds glitter keeps shining after it is dropped
const float FALL      = 0.018;  // how fast glitter sinks (screen heights per second)
const float CELL      = 0.024;  // glitter grid size: smaller = finer, denser glitter
const float AMBIENT   = 0.22;   // faint ever-present glitter in the lower right
const int   TRAIL_SEG = 12;     // segments for the bright trail
const int   DUST_SEG  = 8;      // segments for the whole curve (glitter band is soft)
const float PI        = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Gold -> rose -> violet -> cyan along the curve.
vec3 palette(float t) {
    t = clamp(t, 0.0, 1.0) * 3.0;
    vec3 gold   = vec3(1.00, 0.80, 0.46);
    vec3 rose   = vec3(1.00, 0.56, 0.66);
    vec3 violet = vec3(0.74, 0.58, 1.00);
    vec3 cyan   = vec3(0.50, 0.88, 1.00);
    if (t < 1.0) return mix(gold, rose, smoothstep(0.0, 1.0, t));
    if (t < 2.0) return mix(rose, violet, smoothstep(1.0, 2.0, t));
    return mix(violet, cyan, smoothstep(2.0, 3.0, t));
}

// The per-spell curve: a gentle arc from A to B with one cursive loop in the
// middle. All shape numbers come from the spell index k, so each spell differs.
struct Spell { vec2 a; vec2 b; float r; float bulge; float lc; };

Spell makeSpell(float k, float aspect) {
    Spell s;
    float h1 = hash1(k * 1.37 + 0.11), h2 = hash1(k * 2.71 + 0.53);
    float h3 = hash1(k * 3.33 + 0.97), h4 = hash1(k * 4.19 + 1.31);
    float h5 = hash1(k * 5.07 + 1.77), h6 = hash1(k * 6.61 + 2.03);
    s.a = vec2(aspect * (0.40 + 0.12 * h1), 0.08 + 0.10 * h2);
    s.b = vec2(aspect * (0.80 + 0.12 * h3), 0.14 + 0.14 * h4);
    s.b.x = min(s.b.x, aspect - 0.06);
    if (mod(k, 2.0) > 0.5) { vec2 t = s.a; s.a = s.b; s.b = t; }   // alternate direction
    s.r     = 0.090 + 0.030 * h5;
    s.bulge = 0.02 + 0.05 * h6;
    s.lc    = 0.40 + 0.20 * hash1(k * 7.9 + 2.6);                    // where the loop sits
    return s;
}

vec2 curve(Spell s, float u) {
    vec2 c = mix(s.a, s.b, u);
    c.y += s.bulge * sin(PI * u);
    // One full turn packed into the middle of the curve = a cursive loop.
    float th = 2.0 * PI * smoothstep(s.lc - 0.27, s.lc + 0.27, u);
    float dir = sign(s.b.x - s.a.x);
    c += s.r * vec2(-dir * sin(th), 1.0 - cos(th));
    return c;
}

// Head position along the curve (0..1+TRAIL). Ease-out: the wand sweeps in
// and slows into the end while the trail gathers behind it.
float headAt(float t) {
    float x = clamp(t / DRAW_TIME, 0.0, 1.0);
    return sin(0.5 * PI * x) * (1.0 + TRAIL);
}

// Distance from p to segment ab; h returns the 0..1 position on it.
float segDist(vec2 p, vec2 a, vec2 b, out float h) {
    vec2 pa = p - a, ba = b - a;
    h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return length(pa - ba * h);
}

// The glitter left by one spell has sunk and spread since it was dropped.
// Each curve point is moved down by its own age, so the band falls with the
// glitter grid (which also sinks at FALL). Returns mask, writes curve position.
float dustBand(vec2 p, Spell s, float t, float tEnd, out float uOut) {
    float tc = min(t, tEnd);
    uOut = 0.0;
    if (tc <= 0.0) return 0.0;
    float best = 1e5, bestAge = 0.0, bestU = 0.0;
    vec2 prev; float prevAge = 0.0, prevU = 0.0;
    for (int j = 0; j <= DUST_SEG; j++) {
        float tj = tc * float(j) / float(DUST_SEG);
        float u = min(headAt(tj), 1.0);
        float age = t - tj;
        vec2 c = curve(s, u) - vec2(0.0, FALL * age);
        if (j > 0) {
            float h;
            float d = segDist(p, prev, c, h);
            if (d < best) { best = d; bestAge = mix(prevAge, age, h); bestU = mix(prevU, u, h); }
        }
        prev = c; prevAge = age; prevU = u;
    }
    uOut = bestU;
    float bw = 0.014 + 0.007 * bestAge;                     // spreads as it settles
    float env = smoothstep(0.0, 0.35, bestAge) * (1.0 - smoothstep(LIFE * 0.35, LIFE, bestAge));
    return env * exp(-(best * best) / (bw * bw));
}

// A four-point glint: soft core, thin diffraction spikes, faint halo.
float glint(vec2 d, float len, float thick) {
    vec2 a = abs(d);
    float r2 = dot(d, d);
    float core  = exp(-r2 / (thick * thick * 6.0));
    float spx   = exp(-a.y / thick) * pow(max(1.0 - a.x / len, 0.0), 2.0);
    float spy   = exp(-a.x / thick) * pow(max(1.0 - a.y / len, 0.0), 2.0);
    float halo  = 0.22 * exp(-sqrt(r2) / (len * 0.22));
    return core + 0.8 * (spx + spy) + halo;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;
    float thick = max(0.0010, px * 0.9);

    // Time inside the current spell (small offset so a ribbon shows at once).
    float T = iTime + 0.25;
    float k = floor(T / PERIOD);
    float t = T - k * PERIOD;
    // When the head reaches the end of the curve (burst moment).
    float tEnd = DRAW_TIME * asin(1.0 / (1.0 + TRAIL)) * 2.0 / PI;

    Spell cur = makeSpell(k, aspect);
    Spell old = makeSpell(k - 1.0, aspect);

    // Rough box around the spell area: pixels outside skip the curve work.
    bool nearSpells = p.x > aspect * 0.30 && p.y < 0.82;

    vec3 light = vec3(0.0);

    // ---------- ribbon: bright head + tapering comet trail ----------
    float sh = headAt(t);
    float u1 = min(sh, 1.0), u0 = clamp(sh - TRAIL, 0.0, 1.0);
    if (nearSpells && u1 - u0 > 0.002 && t < DRAW_TIME + 0.1) {
        float best = 1e5, bestU = 0.0;
        vec2 prev;
        for (int j = 0; j <= TRAIL_SEG; j++) {
            float u = mix(u0, u1, float(j) / float(TRAIL_SEG));
            vec2 c = curve(cur, u);
            if (j > 0) {
                float h;
                float d = segDist(p, prev, c, h);
                if (d < best) { best = d; bestU = u - (1.0 - h) * (u1 - u0) / float(TRAIL_SEG); }
            }
            prev = c;
        }
        float w = (bestU - (sh - TRAIL)) / TRAIL;          // 0 at tail, 1 at head
        w = clamp(w, 0.0, 1.0);
        float taper = pow(w, 1.6);
        float width = mix(0.0018, 0.0065, w);
        float core = exp(-(best * best) / (width * width));
        float glow = exp(-best / (width * 6.0)) * 0.55 + exp(-best / 0.03) * 0.12 * w;
        vec3 col = mix(palette(bestU), vec3(1.0, 0.97, 0.92), 0.45 * core * w);
        light += col * (core * 0.9 + glow) * taper;
    }
    // The wand tip itself: a soft bloom with a small star flare.
    if (sh > 0.0 && sh < 1.0) {
        vec2 hp = curve(cur, sh);
        vec2 d = p - hp;
        float fade = smoothstep(0.0, 0.06, sh) * (1.0 - smoothstep(0.94, 1.0, sh));
        float tw = 0.85 + 0.15 * sin(iTime * 9.0);
        float g = glint(d, 0.045 * tw, thick * 1.4) + 0.5 * exp(-length(d) / 0.025);
        light += mix(palette(sh), vec3(1.0), 0.6) * g * fade;
    }

    // ---------- burst where the trail ends ----------
    float tb = t - tEnd;
    if (tb > 0.0 && tb < 2.2) {
        vec2 e = curve(cur, 1.0);
        vec2 dd = p - e;
        if (dot(dd, dd) < 0.04) {
            float flash = exp(-tb * 5.0);
            light += palette(1.0) * 0.6 * flash * exp(-length(dd) / 0.03);
            float spread = 1.0 - exp(-tb * 2.6);
            for (int i = 0; i < 6; i++) {
                float fi = float(i);
                float ang = 2.0 * PI * (fi + 0.6 * hash1(fi + k * 3.1)) / 6.0;
                float rad = 0.06 + 0.07 * hash1(fi * 2.3 + k);
                vec2 q = e + vec2(cos(ang), sin(ang)) * rad * spread - vec2(0.0, 0.015 * tb * tb);
                float life = 1.0 - smoothstep(0.6, 2.2, tb);
                float tw = 0.6 + 0.4 * sin(iTime * 14.0 + fi * 2.0);
                float len = 0.016 + 0.012 * hash1(fi * 5.7 + k);
                light += mix(palette(hash1(fi + k)), vec3(1.0), 0.4)
                       * glint(p - q, len, thick) * life * tw;
            }
        }
    }

    // ---------- glitter: left by this spell and the previous one ----------
    float uC = 0.0, uO = 0.0;
    float mC = 0.0, mO = 0.0;
    if (nearSpells) {
        mC = dustBand(p, cur, t, tEnd, uC);
        mO = dustBand(p, old, t + PERIOD, tEnd, uO);
    }
    // Faint glitter that always lingers toward the lower right.
    float amb = AMBIENT * smoothstep(0.35, 0.85, uv.x) * smoothstep(0.30, 0.95, uv.y);
    float mask = max(max(mC, mO), amb);
    float dustU = mC >= mO ? uC : uO;

    if (mask > 0.01) {
        // The grid sinks at FALL, so each glint drifts down slowly.
        // The grid is tilted so the glints never line up in visible rows.
        const mat2 TILT = mat2(0.866, 0.5, -0.5, 0.866);
        vec2 fp = p + vec2(0.0, FALL * iTime);
        vec2 q = TILT * fp / CELL;
        vec2 corner = floor(q + 0.5);                       // nearest grid corner
        for (int i = 0; i < 4; i++) {
            vec2 id = corner - 1.0 + vec2(float(i & 1), float(i >> 1));
            float h0 = hash2(id), h1 = hash2(id + 17.3), h2 = hash2(id + 41.9);
            // Smooth threshold: glints fade in and out as the band passes, never pop.
            float on = smoothstep(h0 - 0.12, h0 + 0.12, mask * 1.15);
            if (on <= 0.0) continue;
            vec2 pos = (id + 0.2 + 0.6 * vec2(h1, h2)) * CELL;
            vec2 d = TILT * fp - pos;
            float sz = hash2(id + 7.7);
            float len = CELL * mix(0.25, 0.62, sz * sz);
            // Sharp, irregular twinkle: mostly dim, brief bright glints.
            float ph = iTime * (1.5 + 2.5 * h1) + h2 * 6.28;
            float tw = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(ph), 4.0);
            vec3 col = mix(palette(fract(dustU + (h1 - 0.5) * 0.25)), vec3(1.0), 0.35);
            light += col * glint(d, len, thick) * on * tw * 0.75;
        }
    }

    // Keep the top-left (shell text) calmer.
    float calm = 1.0 - 0.75 * (1.0 - smoothstep(0.0, 0.55, length(vec2(uv.x * 1.2, uv.y) - vec2(0.0, 0.0)) - 0.15));
    light *= calm * INTENSITY;

    // Screen blend: bright light, but text underneath still shows through.
    light = min(light, vec3(1.0));
    vec3 outc = 1.0 - (1.0 - base.rgb) * (1.0 - light * 0.85);
    fragColor = vec4(outc, base.a);
}
