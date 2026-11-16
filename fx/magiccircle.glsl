// magiccircle — a luminous summoning circle on the ground at the lower right that charges up, sends up a column of light, and calms.
// zh: 魔法阵
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.75;   // overall brightness (0 = off)
const float WIDTH     = 0.43;   // circle diameter, as a share of the window width
const float TILT      = 0.34;   // how flat the ground makes it look (1 = seen from above)
const float CYCLE     = 12.0;   // seconds per charge cycle
const float DIM       = 0.30;   // resting glow between charges (never fully gone)
const int   SPARKS    = 14;     // rising motes during the charge
const float PI        = 3.14159265;
const float TAU       = 6.28318531;

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Star polygon {n/k} on radius R: n chords from vertex i to vertex i+k.
float starPoly(vec2 g, int n, float k, float R) {
    float d = 1e5;
    float step_ = TAU / float(n);
    for (int i = 0; i < 8; i++) {
        if (i >= n) break;
        float a0 = step_ * float(i);
        float a1 = a0 + step_ * k;
        d = min(d, segDist(g, R * vec2(cos(a0), sin(a0)), R * vec2(cos(a1), sin(a1))));
    }
    return d;
}

// A thin luminous line: a sharp core about a pixel wide plus a soft bloom.
// d is already in screen units (window heights).
float glowLine(float d) {
    return exp(-d * d / 1.6e-6) + 0.30 * exp(-d / 0.0055);
}

// Lines "draw on" around the circle: a is this pixel's angle (0..1) along the
// stroke, pr is how far the pen has got. Returns (drawn, pen-tip glint).
vec2 reveal(float a, float pr) {
    float drawn = smoothstep(a, a + 0.015, pr * 1.02);
    float tip = exp(-pow((pr - a) * 30.0, 2.0)) * sin(PI * clamp(pr, 0.0, 1.0));
    return vec2(drawn, tip);
}

// Small rune-like mark in a cell, q roughly in [-1,1]^2: a stem plus two
// strokes picked from a short list by the cell's hash.
float rune(vec2 q, float id) {
    float d = segDist(q, vec2(0.0, -0.8), vec2(0.0, 0.8));
    float h = hash(id * 3.7 + 1.3);
    float h2 = hash(id * 5.1 + 7.9);
    int s1 = int(h * 6.0), s2 = int(h2 * 6.0);
    for (int j = 0; j < 2; j++) {
        int s = j == 0 ? s1 : s2;
        vec4 e = s == 0 ? vec4(-0.6, 0.8, 0.6, 0.8)
               : s == 1 ? vec4(-0.6, -0.8, 0.6, -0.8)
               : s == 2 ? vec4(0.0, 0.1, 0.6, 0.8)
               : s == 3 ? vec4(0.0, -0.1, -0.6, -0.8)
               : s == 4 ? vec4(-0.6, 0.0, 0.6, 0.0)
               :          vec4(0.6, 0.8, 0.6, -0.3);
        d = min(d, segDist(q, e.xy, e.zw));
    }
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float R = WIDTH * 0.5 * aspect;                    // radius in screen units
    vec2 C = vec2(aspect - R - 0.05 * aspect, 0.20);   // lower right, on the "floor"
    float t = iTime;

    // Quick bounding test: everything lives near the circle or in the column
    // above it. Far pixels (the top-left text area) cost almost nothing.
    vec2 dp = p - C;
    if (abs(dp.x) > R * 1.6 || dp.y > 0.85 || dp.y < -R * TILT * 2.2) {
        fragColor = base;
        return;
    }

    // ---- Charge cycle ------------------------------------------------------
    // 0-3 s pen draws the lines, brightness builds to a peak around 5-7 s with
    // the column of light, then it calms back to the resting glow by ~11.5 s.
    float ph = mod(t + 0.4, CYCLE);
    float charge = smoothstep(0.2, 4.5, ph) * (1.0 - smoothstep(7.0, 11.5, ph));
    float peak = smoothstep(3.5, 5.5, ph) * (1.0 - smoothstep(7.0, 10.0, ph));
    float breathe = 0.92 + 0.08 * sin(t * 1.7);

    // Ground coordinates: squash vertically so the circle lies flat, and narrow
    // the far side a little for perspective. In g the circle has radius 1.
    vec2 g = dp / vec2(R, R * TILT);
    g.x *= 1.0 + 0.14 * g.y;
    float r = length(g);
    // Screen-space size of one g unit across a ring here, so lines keep a
    // constant thin width whether they run along or across the tilt.
    vec2 n = r > 1e-4 ? g / r : vec2(1.0, 0.0);
    float k = R * length(vec2(n.x, n.y * TILT));
    float aG = fract(atan(g.y, g.x) / TAU + 0.75);     // fixed angle, 0 at the front

    vec3 gold  = vec3(1.00, 0.74, 0.38);
    vec3 amber = vec3(1.00, 0.52, 0.20);
    vec3 cyan  = vec3(0.45, 0.85, 1.00);
    vec3 col = vec3(0.0);

    if (r < 1.18) {
        // Each layer turns at its own speed, alternating direction.
        vec2 gA = rot( t * 0.045) * g;   // outer rim and ticks
        vec2 gB = rot(-t * 0.070) * g;   // rune band
        vec2 gC = rot( t * 0.100) * g;   // heptagram
        vec2 gD = rot(-t * 0.160) * g;   // hexagram and dotted ring
        vec2 gE = rot( t * 0.240) * g;   // inner pentagram
        float aA = atan(gA.y, gA.x), aB = atan(gB.y, gB.x), aD = atan(gD.y, gD.x);

        // Pen progress per layer: outer rings first, then inward.
        float pr1 = clamp((ph - 0.3) / 1.6, 0.0, 1.0);
        float pr2 = clamp((ph - 0.9) / 1.6, 0.0, 1.0);
        float pr3 = clamp((ph - 1.5) / 1.6, 0.0, 1.0);
        float pr4 = clamp((ph - 2.1) / 1.4, 0.0, 1.0);
        vec2 rv1 = reveal(aG, pr1);
        vec2 rv2 = reveal(1.0 - aG, pr2);   // drawn the other way round
        vec2 rv3 = reveal(aG, pr3);
        vec2 rv4 = reveal(1.0 - aG, pr4);

        // Layer 1: outer double rim, ticks between, and three floating arcs.
        float L1 = glowLine(abs(r - 1.0) * k) + 0.8 * glowLine(abs(r - 0.965) * k);
        float tick = abs(fract(aA / TAU * 120.0) - 0.5) * (TAU * r / 120.0);
        float longT = step(abs(fract(aA / TAU * 12.0 + 0.5) - 0.5), 0.004);
        float tEnd = mix(0.984, 0.998, longT);       // every tenth tick reaches the rim
        float tickBand = smoothstep(0.962, 0.968, r) * smoothstep(tEnd, tEnd - 0.004, r);
        L1 += 0.7 * exp(-pow(tick * k / 0.0012, 2.0)) * tickBand;
        float arcMask = smoothstep(0.30, 0.27, abs(fract(-aA / TAU * 3.0) - 0.5));
        L1 += 0.55 * glowLine(abs(r - 1.07) * k) * arcMask;

        // Layer 2: rune band between two rings.
        float L2 = 0.8 * glowLine(abs(r - 0.94) * k) + 0.8 * glowLine(abs(r - 0.84) * k);
        if (r > 0.845 && r < 0.935) {
            float N = 40.0;
            float cell = aB / TAU * N;
            float id = floor(cell);
            vec2 q = vec2((fract(cell) - 0.5) * TAU * 0.89 / N, r - 0.89) / 0.030;
            float d = mod(id, 5.0) < 0.5 ? abs(length(q) - 0.45) : rune(q, id);
            L2 += 0.75 * glowLine(d * 0.030 * k);
        }

        // Layer 3: heptagram {7/3} touching the rune band's inner ring.
        float L3 = 0.0;
        if (r < 0.86) L3 = 0.75 * glowLine(starPoly(gC, 7, 3.0, 0.84) * k);

        // Layer 4: inner ring, dotted ring and a hexagram, with a cyan tint.
        float L4 = glowLine(abs(r - 0.60) * k) + 0.6 * glowLine(abs(r - 0.52) * k);
        float dotA = (fract(aD / TAU * 48.0) - 0.5) * TAU * 0.56 / 48.0;
        L4 += 0.9 * exp(-length(vec2(dotA, r - 0.56)) * k / 0.0016) * step(abs(r - 0.56), 0.03);
        if (r < 0.54) L4 += 0.75 * glowLine(starPoly(gD, 6, 2.0, 0.52) * k);

        // Layer 5: pentagram and core rings at the centre.
        float L5 = 0.0;
        if (r < 0.36) {
            L5 += 0.8 * glowLine(abs(r - 0.33) * k) + 0.7 * glowLine(abs(r - 0.12) * k);
            L5 += 0.7 * glowLine(starPoly(gE, 5, 2.0, 0.33) * k);
        }

        // Brightness per layer: resting glow everywhere, plus the freshly drawn
        // part at full charge, plus a bright glint at the pen tip.
        float b1 = DIM + (1.0 - DIM) * charge * rv1.x + 1.6 * rv1.y;
        float b2 = DIM + (1.0 - DIM) * charge * rv2.x + 1.6 * rv2.y;
        float b3 = DIM + (1.0 - DIM) * charge * rv3.x + 1.6 * rv3.y;
        float b4 = DIM + (1.0 - DIM) * charge * rv4.x + 1.6 * rv4.y;
        float b5 = DIM + (1.0 - DIM) * charge * rv4.x;

        // A soft highlight slowly chasing round the rim adds life even at rest.
        float chase = 0.8 + 0.35 * pow(0.5 + 0.5 * cos(aG * TAU - t * 0.9), 6.0);

        col += gold  * L1 * b1 * chase;
        col += mix(gold, amber, 0.35) * L2 * b2;
        col += mix(gold, amber, 0.5) * L3 * b3;
        col += mix(gold, cyan, 0.45) * L4 * b4;
        col += mix(gold, cyan, 0.30) * L5 * b5 * (1.0 + 0.6 * peak);
        col *= breathe;
    }

    // ---- Light spilling onto the ground -----------------------------------
    float spill = exp(-max(r - 0.2, 0.0) * 2.4) * (0.08 + 0.30 * charge + 0.25 * peak);
    col += mix(amber, gold, smoothstep(1.2, 0.0, r)) * spill;
    // A faint cyan pool at the very centre when it peaks.
    col += cyan * exp(-r * r * 9.0) * 0.25 * peak;

    // ---- Column of light rising from the centre ---------------------------
    float h = dp.y;                                    // height above the centre
    if (abs(dp.x) < R * 1.1 && h > -0.06) {
        float w = R * (0.34 + 0.14 * smoothstep(0.0, 0.6, h));   // flares slightly upward
        float body = exp(-pow(dp.x / w, 2.0));
        float core = exp(-pow(dp.x / (w * 0.18), 2.0));
        float halo = exp(-pow(dp.x / (w * 2.2), 2.0));      // wide faint haze
        // Fine vertical shimmer drifting upward inside the beam.
        float shimmer = 0.75 + 0.25 * sin(dp.x * 140.0 + sin(h * 9.0 - t * 2.0) * 1.5)
                                     * sin(h * 7.0 - t * 2.6);
        float fade = smoothstep(-0.05, 0.03, h) * exp(-max(h, 0.0) * 2.4) * smoothstep(0.82, 0.45, h);
        float beam = (0.30 * body * shimmer + 0.50 * core + 0.10 * halo) * fade;
        vec3 beamCol = mix(cyan * 0.9, vec3(1.0, 0.92, 0.75), core);
        col += beamCol * beam * (0.06 * charge + 0.94 * peak);

        // Rising sparks: born inside the circle, drift up and fade.
        float amt = 0.15 + 0.5 * charge + 0.6 * peak;
        for (int i = 0; i < SPARKS; i++) {
            float fi = float(i);
            float life = 2.6 + 1.8 * hash(fi + 0.3);
            float lt = fract(t / life + hash(fi + 4.1));
            float ang = TAU * hash(fi + 8.7);
            float rad = 0.65 * sqrt(hash(fi + 2.9));
            vec2 start = vec2(cos(ang) * rad * R, sin(ang) * rad * R * TILT);
            vec2 sp = start + vec2(0.012 * sin(lt * 5.0 + fi), lt * (0.30 + 0.25 * hash(fi + 6.2)));
            vec2 dd = dp - sp;
            dd.y *= 0.45;                              // slight vertical streak
            float s = exp(-dot(dd, dd) / 1.0e-5) * sin(PI * lt);
            col += mix(gold, cyan, hash(fi + 1.7) * 0.6) * s * amt;
        }
    }

    // Soft roll-off keeps bright overlaps luminous rather than clipped, and
    // caps opacity so the text behind stays readable.
    col *= INTENSITY;
    col = 0.85 * (1.0 - exp(-col * 1.4));
    fragColor = vec4(base.rgb + col, base.a);
}
