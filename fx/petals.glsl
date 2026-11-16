// petals — a flowering sakura branch sways in the top-right corner, shedding big pink petals that tumble on the breeze.
// zh: 花瓣
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY  = 0.90;   // overall strength (0 = off)
const float PETAL_SIZE = 1.00;   // size multiplier for all falling petals
const float WIND       = 0.07;   // steady breeze to the left, window-heights per second
const float FALL       = 0.075;  // falling speed of the nearest petals
const float GUST_EVERY = 5.0;    // seconds between two gusts
const float GUST_TIME  = 3.0;    // seconds one gust petal takes to cross the window
const int   GUST_COUNT = 12;     // petals swept along by one gust
const int   LAYERS     = 4;      // depth layers of falling petals (near ... far)
const float SWAY       = 1.0;    // how much the branch sways

const float TAU = 6.2831853;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float n) {
    return fract(sin(n * 91.345) * 43758.5453);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// One loose sakura petal in its own frame: the base at y = -len, the notched
// tip at y = +len. flip (0..1) squashes it sideways, which is how a petal
// turning over in 3D looks. Returns (coverage, lightness toward the middle).
vec2 petal(vec2 q, float len, float flip, float aa) {
    vec2 u = vec2(q.x / max(flip, 0.28), q.y) / len;
    // Narrow at the base, widest a bit past the middle, round at the tip.
    float t = u.y > 0.3 ? (u.y - 0.3) / 0.7 : (u.y - 0.3) / 1.3;
    float w = 0.60 * sqrt(max(1.0 - t * t, 0.0));
    float d = abs(u.x) - w;
    // The little V notch at the tip that makes it a cherry petal.
    d = max(d, u.y - (0.74 + 1.5 * abs(u.x)));
    d = max(d, -1.0 - u.y);                               // close off the base
    float cover = smoothstep(aa, -aa, d * len);
    float mid = 1.0 - clamp(length(vec2(u.x / 0.6, u.y + 0.15)), 0.0, 1.0);
    return vec2(cover, mid);
}

// A five-petal blossom of radius R. Returns its colour in rgb and coverage in a.
vec4 blossom(vec2 q, float R, float spin, float aa) {
    float r = length(q);
    if (r > R * 1.05) return vec4(0.0);
    float th = atan(q.y, q.x) + spin;
    float a = mod(th, TAU / 5.0) - TAU / 10.0;            // angle from the nearest petal axis
    float edge = R * (0.42 + 0.58 * max(cos(a * 2.3), 0.0));
    edge -= R * 0.20 * max(0.0, 1.0 - abs(a) / 0.15);     // notch in each petal tip
    float cover = smoothstep(aa, -aa, r - edge);

    // White-pink petals, deeper pink toward the heart, a thin darker rim so
    // overlapping flowers stay apart, and a ring of yellow stamens.
    vec3 col = mix(vec3(0.98, 0.55, 0.70), vec3(1.0, 0.90, 0.94), smoothstep(0.15 * R, 0.6 * R, r));
    col *= 0.80 + 0.20 * smoothstep(0.0, 0.10 * R, edge - r);
    col = mix(col, vec3(0.85, 0.25, 0.42), smoothstep(0.24 * R, 0.14 * R, r));
    float stamen = smoothstep(0.06 * R, 0.0, abs(r - 0.32 * R)) * smoothstep(0.75, 0.95, cos(th * 9.0));
    col = mix(col, vec3(1.0, 0.85, 0.35), stamen);
    return vec4(col, cover);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    float aspect = iResolution.x / iResolution.y;
    float px = 1.0 / iResolution.y;

    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;

    // Gusts: one every GUST_EVERY seconds, the first already under way at start.
    float gt = t + 0.3;
    float gk = floor(gt / GUST_EVERY);
    float age = gt - gk * GUST_EVERY;
    float pulse = smoothstep(0.0, 0.7, age) * smoothstep(3.8, 2.0, age);
    // Extra sideways push for all falling petals; it grows during each gust and
    // never jumps back, so nothing teleports.
    float push = 0.30 * (gk + smoothstep(0.2, 3.6, age));

    // Keep the busiest parts light over the top-left, where the shell text is.
    float textFade = 1.0 - 0.65 * (1.0 - smoothstep(0.30, 0.75, uv.x)) * smoothstep(0.35, 0.75, p.y);

    bool light = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114)) > 0.5;
    vec3 tint = light ? vec3(0.95, 0.60, 0.70) : vec3(1.0);   // deeper pink on light themes

    vec3 col = base.rgb;

    // ---- The branch, pivoting at the top-right corner ------------------------
    float sway = SWAY * (0.022 * sin(t * 0.8) + 0.010 * sin(t * 1.9 + 1.0) + 0.045 * pulse);
    vec2 b = rot(p - vec2(aspect + 0.02, 1.02), sway);
    if (b.x > -0.92 && b.y > -0.47 && b.x < 0.06) {
        vec2 A0 = vec2(0.05, 0.03), A1 = vec2(-0.22, -0.10), A2 = vec2(-0.48, -0.15), A3 = vec2(-0.80, -0.27);
        vec2 s;
        float d = 1e3;
        s = segment(b, A0, A1); d = min(d, s.x - mix(0.026, 0.018, s.y));
        s = segment(b, A1, A2); d = min(d, s.x - mix(0.018, 0.012, s.y));
        s = segment(b, A2, A3); d = min(d, s.x - mix(0.012, 0.005, s.y));
        s = segment(b, A1, vec2(-0.27, -0.32)); d = min(d, s.x - mix(0.010, 0.004, s.y));
        s = segment(b, A2, vec2(-0.63, -0.04)); d = min(d, s.x - mix(0.009, 0.004, s.y));
        s = segment(b, vec2(-0.40, -0.135), vec2(-0.51, -0.38)); d = min(d, s.x - mix(0.008, 0.003, s.y));
        // Dark bark with a faint warm rim so it still reads on a black background.
        float bark = smoothstep(1.5 * px, -1.5 * px, d);
        float rim = smoothstep(0.006, 0.0, abs(d)) * 0.35;
        col = mix(col, vec3(0.55, 0.32, 0.30), rim * INTENSITY);
        col = mix(col, vec3(0.20, 0.11, 0.10), bark * 0.92 * INTENSITY);

        // Clusters of blossoms along the twigs (x, y, radius).
        const vec3 FL[12] = vec3[12](
            vec3(-0.09, -0.05, 0.040), vec3(-0.17, -0.13, 0.046), vec3(-0.23, -0.21, 0.040),
            vec3(-0.27, -0.32, 0.050), vec3(-0.35, -0.09, 0.050), vec3(-0.46, -0.24, 0.042),
            vec3(-0.51, -0.37, 0.048), vec3(-0.56, -0.12, 0.040), vec3(-0.63, -0.05, 0.052),
            vec3(-0.70, -0.19, 0.044), vec3(-0.66, -0.32, 0.042), vec3(-0.80, -0.27, 0.056));
        for (int i = 0; i < 12; i++) {
            vec3 f = FL[i];
            float fi = float(i);
            // Each flower nods a little on its own as well.
            vec2 c = f.xy + 0.006 * vec2(sin(t * 1.3 + fi), cos(t * 1.1 + fi * 1.7));
            vec4 fl = blossom(b - c, f.z, fi * 1.3 + 0.15 * sin(t * 0.9 + fi), 1.5 * px);
            col = mix(col, fl.rgb * tint, fl.a * INTENSITY);
        }
    }

    // ---- Falling petals, far layers first so near ones cover them -----------
    for (int k = 0; k < LAYERS; k++) {
        float fi = float(LAYERS - 1 - k);                 // 3 = farthest, 0 = nearest
        float scale = 2.6 + fi * 1.7;                     // cells per window-height
        float depth = 1.0 / (1.0 + fi * 0.45);            // far petals drift slower

        vec2 g = p;
        g.x += (WIND * t + push) * depth + fi * 0.37;
        g.y += FALL * t * depth + fi * 0.23;
        g *= scale;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        float h = hash(id + fi * 17.0);
        if (h < (fi == 0.0 ? 0.80 : 0.60)) continue;     // few near petals, more far ones
        float h2 = hash(id + 3.1), h3 = hash(id + 7.7), h4 = hash(id + 4.4);

        // Place it in the cell, with a little flutter of its own.
        vec2 q = f - (vec2(hash(id + 2.2), hash(id + 5.8)) - 0.5) * 0.36
                   - 0.09 * vec2(sin(t * 1.3 + h2 * TAU), cos(t * 1.1 + h3 * TAU));
        q = rot(q, t * (0.4 + 1.2 * h3) * (h2 > 0.5 ? 1.0 : -1.0) + h4 * TAU);
        float flipc = cos(t * (1.2 + 1.6 * h2) + h3 * TAU);

        float len = 0.145 * mix(0.85, 1.15, h4) * PETAL_SIZE;   // in cell units
        float aa = fi == 0.0 ? 0.035 : 1.4 * px * scale;        // nearest layer is out of focus
        vec2 pt = petal(q, len, abs(flipc), aa);

        vec3 pc = mix(vec3(1.0, 0.58, 0.74), vec3(1.0, 0.93, 0.95), pt.y);
        pc *= flipc < 0.0 ? 0.82 : 1.0;                   // the back side catches less light
        pc = mix(pc, vec3(0.75, 0.55, 0.62), fi * 0.10);  // far ones fade into the air
        float alpha = pt.x * (fi == 0.0 ? 0.80 : 0.95 - fi * 0.10) * textFade;
        col = mix(col, pc * tint, alpha * INTENSITY);
    }

    // ---- Gust: a stream of petals torn off the branch, swept across in a curve
    float gh = hash1(gk + 0.5);
    for (int j = 0; j < GUST_COUNT; j++) {
        float fj = float(j);
        float s = (age - fj * 0.15) / GUST_TIME;
        if (s < 0.0 || s > 1.0) continue;
        float r1 = hash1(fj + gk * 13.0), r2 = hash1(fj * 1.7 + gk * 5.0 + 2.0);

        // Leave from among the blossoms, sweep down-left, loop once mid-way,
        // then lift a little as the gust dies away.
        vec2 start = vec2(aspect - 0.30 - 0.20 * r1, 0.88 - 0.10 * r2);
        vec2 pos = start + vec2(-s * (aspect + 0.10), -0.80 * s + (0.45 + 0.2 * gh) * s * s);
        float loopR = (0.10 + 0.05 * gh) * sin(s * 3.14159);
        float la = s * TAU * 1.3 + fj * 0.15;
        pos += loopR * vec2(cos(la), sin(la));
        pos.y += (r2 - 0.5) * 0.08 * s;                   // the stream spreads out as it goes

        vec2 q = p - pos;
        float len = mix(0.035, 0.055, r1) * PETAL_SIZE;
        if (dot(q, q) > len * len * 1.5) continue;
        q = rot(q, t * (2.0 + 2.0 * r2) + r1 * TAU);
        float flipc = cos(t * (3.0 + 2.0 * r1) + r2 * TAU);
        vec2 pt = petal(q, len, abs(flipc), 1.4 * px);

        vec3 pc = mix(vec3(1.0, 0.58, 0.74), vec3(1.0, 0.93, 0.95), pt.y);
        pc *= flipc < 0.0 ? 0.82 : 1.0;
        float fade = smoothstep(0.0, 0.05, s) * smoothstep(1.0, 0.85, s);
        col = mix(col, pc * tint, pt.x * fade * 0.95 * mix(0.6, 1.0, textFade) * INTENSITY);
    }

    fragColor = vec4(col, base.a);
}
