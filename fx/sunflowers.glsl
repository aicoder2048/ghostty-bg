// sunflowers — a clump of realistic sunflowers at the bottom right sways in a breeze; heads nod out of step, leaves flutter now and then, and a honeybee drops by.
// zh: 向日葵
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.95;   // overall strength (0 = off)
const float SIZE      = 1.0;    // scale of the clump (1 = tallest head ~17% of the window height)
const float WIND      = 1.0;    // breeze strength (0 = still)
const float SEEDS     = 300.0;  // seeds in the tallest head's disc (smaller heads scale down)
const float BEE       = 1.0;    // 1 = a honeybee visits now and then, 0 = no bee
const float BEE_CYCLE = 15.0;   // seconds between bee visits
const float BEE_LEN   = 0.034;  // bee body length, in window heights

const float PI   = 3.14159265;
const float TAU  = 6.28318531;
const float PHI  = 1.61803399;
const float GOLD = 0.38196601;  // golden angle as a fraction of a turn (1 / phi^2)

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Smooth value noise, for gentle colour variation.
float vnoise(vec2 x) {
    vec2 i = floor(x), f = x - i;
    f = f * f * (3.0 - 2.0 * f);
    float a = hash1(dot(i, vec2(1.0, 57.0)));
    float b = hash1(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
    float c = hash1(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
    float d = hash1(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}
void overP(inout vec4 acc, vec4 c) { acc = c + acc * (1.0 - c.a); }

// Smooth breeze for one plant: two slow waves under a slow gust envelope.
float breeze(float t, float ph) {
    float gust = 0.65 + 0.35 * sin(t * 0.21 + ph * 0.6);
    return WIND * gust * (0.62 * sin(t * 0.83 + ph) + 0.38 * sin(t * 1.57 + ph * 2.3));
}

// ---------------------------------------------------------------- plants
// Plant i at time t: stem foot x, head height H, head radius R (petal tips),
// stem top offset, head centre, head tilt and foreshortening, phase.
void plantState(int i, float A, float t, out float x0, out float H, out float R,
                out float topDx, out vec2 c, out float ang, out float sq, out float ph) {
    float lean, face, sq0;
    if (i == 0)      { x0 = A - 0.38 * SIZE; H = 0.31 * SIZE; R = 0.070 * SIZE; lean = -0.015; face =  0.30; sq0 = 0.70; ph = 2.1; }
    else if (i == 1) { x0 = A - 0.16 * SIZE; H = 0.44 * SIZE; R = 0.086 * SIZE; lean = -0.030; face =  0.22; sq0 = 0.66; ph = 0.0; }
    else             { x0 = A - 0.58 * SIZE; H = 0.22 * SIZE; R = 0.058 * SIZE; lean =  0.020; face = -0.25; sq0 = 0.74; ph = 4.0; }
    float sway = breeze(t, ph);
    float nod = breeze(t - 0.7, ph + 0.4);          // the heavy head lags the stem
    topDx = lean * SIZE + 0.064 * sway * H;
    c = vec2(x0 + topDx, H);
    ang = face + 0.12 * nod;
    sq = sq0 + 0.04 * nod;
}

// x of the stem centre at height y (bends mostly near the top), and its slope.
float stemX(float y, float x0, float H, float topDx, out float slope) {
    float s = clamp(y / H, 0.0, 1.0);
    float bow = 0.012 * H * sin(x0 * 9.0);                  // a gentle natural curve, different per plant
    slope = (topDx * (0.3 + 1.4 * s) + bow * PI * cos(PI * s)) / H;
    return x0 + topDx * (0.3 * s + 0.7 * s * s) + bow * sin(PI * s);
}

// Thick, slightly hairy stem: shaded as a cylinder lit from the upper left.
void stem(inout vec4 acc, vec2 p, float x0, float H, float topDx, float R, float pw) {
    if (p.y > H || p.y < -0.02) return;
    float slope;
    float sx = stemX(p.y, x0, H, topDx, slope);
    float d = (p.x - sx) / sqrt(1.0 + slope * slope);
    float w = R * 0.115 * (1.0 - 0.4 * p.y / H);
    if (abs(d) > w + 0.004) return;

    // Fine pale hairs sticking out of the edges, slanted upward.
    float e = abs(d) - w;
    float hy = p.y - e * 0.9;
    float hid = floor(hy * 260.0);
    float hairs = step(fract(hy * 260.0), 0.18) * step(hash1(hid * 1.3 + x0), 0.6) * step(e, 0.0008 + 0.0012 * hash1(hid + x0 * 17.0))
                * step(0.0, e) * smoothstep(2.0, 4.0, 0.0038 / pw);
    over(acc, vec3(0.62, 0.68, 0.52), hairs * 0.35);

    float n = clamp(d / w, -1.0, 1.0);
    float lam = max(-0.6 * n + 0.8 * sqrt(1.0 - n * n), 0.0);
    vec3 col = vec3(0.21, 0.37, 0.12) * (0.38 + 0.80 * lam);
    col *= 1.0 + 0.06 * sin(n * 9.0);                       // faint ridges along the stem
    col = mix(col, vec3(0.62, 0.68, 0.48), 0.25 * smoothstep(0.55, 0.95, -n) * lam);  // hairy sheen on the lit edge
    over(acc, col, smoothstep(pw, -pw, abs(d) - w));
}

// A cordate (heart-shaped) sunflower leaf with a serrated margin. q: x along
// the midrib from the base, y across, in leaf lengths. Returns premultiplied colour.
vec4 leaf(vec2 q, float px, float seed) {
    float t = q.x;
    if (t < -0.16 || t > 1.03 || abs(q.y) > 0.45) return vec4(0.0);
    float s = clamp((t + 0.12) / 1.12, 0.0, 1.0);
    float w = 0.40 * sin(PI * pow(s, 0.62));
    w *= 1.0 - 0.55 * smoothstep(0.5, 1.0, s);              // long pointed tip
    // Teeth pointing toward the tip: a slow rise then a sharp drop.
    w += 0.016 * (fract(t * 17.0 + seed) - 0.5) * smoothstep(-0.05, 0.1, t) * (1.0 - smoothstep(0.88, 0.98, t));
    float notch = (t - (0.05 - 0.55 * abs(q.y))) * 0.87;    // heart-shaped sinus at the base
    float d = max(abs(q.y) - w, -notch);
    float cov = smoothstep(px, -px, d);
    if (cov <= 0.0) return vec4(0.0);

    float n = clamp(q.y / max(w, 1e-3), -1.0, 1.0);
    // Blade folded a little along the midrib: the upper half faces the light.
    float up = smoothstep(-px, px, q.y);
    vec3 col = vec3(0.17, 0.31, 0.10) * mix(0.74, 1.06, up) * (0.86 + 0.20 * (1.0 - abs(n)));
    col = mix(col, col * vec3(1.10, 1.05, 0.75), 0.35 * t);  // a little yellower toward the tip
    col *= 0.88 + 0.22 * vnoise(q * 9.0 + seed * 7.0);       // subtle mottling

    // Midrib and lateral veins that sweep out toward the tip.
    float mw = 0.009 * (1.0 - 0.8 * clamp(t, 0.0, 1.0));
    float mid = smoothstep(mw + px, mw - px, abs(q.y)) * step(0.0, t);
    float lv = (t - 0.55 * abs(q.y)) * 8.0;
    float ld = abs(fract(lv + 0.5) - 0.5) / 8.0 * 0.87;
    float lat = smoothstep(0.003 + px, 0.003 - px, ld) * smoothstep(0.0, 0.08, t)
              * (1.0 - smoothstep(0.65, 0.92, abs(n))) * smoothstep(0.012, 0.004, px);
    col = mix(col, vec3(0.44, 0.56, 0.22) * mix(0.75, 1.05, up), max(mid * 0.75, lat * 0.45));

    col *= 1.0 - 0.15 * smoothstep(-2.0 * px, 0.0, d);       // darker rim keeps the edge crisp
    return vec4(col * cov, cov);
}

// ---------------------------------------------------------------- heads
// Green pointed bracts on the back of the head, peeking out between petals.
vec4 bracts(vec2 q, float px, vec2 L) {
    float r = length(q);
    if (r > 0.95 || r < 0.3) return vec4(0.0);
    float N = 17.0;
    float a = atan(q.y, q.x);
    float k = mod(floor(a / TAU * N + 0.5), N);
    float th = (k + 0.2 * (hash1(k * 3.7 + 1.0) - 0.5)) * TAU / N;
    vec2 dir = vec2(cos(th), sin(th));
    float u = dot(q, dir), v = dot(q, vec2(-dir.y, dir.x));
    float len = 0.82 + 0.1 * hash1(k * 5.1);
    float t = (u - 0.3) / (len - 0.3);
    float w = 0.085 * smoothstep(0.0, 0.25, t) * pow(max(1.0 - t, 0.0), 0.9);
    float d = abs(v) - w;
    float cov = smoothstep(px, -px, d) * step(0.0, t);
    float n = clamp(v / max(w, 1e-4), -1.0, 1.0);
    vec3 col = mix(vec3(0.09, 0.18, 0.05), vec3(0.28, 0.43, 0.13), smoothstep(0.1, 0.8, t));
    col *= (1.0 - 0.35 * n * n) * (0.85 + 0.25 * dot(dir, L));
    return vec4(col * cov, cov);
}

// One ray petal (index k of a ring of N). q: head coords, petal tips near radius 1.
vec4 petal(vec2 q, float k, float N, float off, float seed, float rd, float px,
           vec2 L, float shade, float t0, out float depth) {
    float kk = mod(k, N);
    float h = seed + kk * 7.31;
    float h1 = hash1(h), h2 = hash1(h + 1.7), h3 = hash1(h + 3.1), h4 = hash1(h + 4.9), h5 = hash1(h + 6.3);
    depth = hash1(h + 8.2);
    float th = (k + off + 0.30 * (h1 - 0.5)) * TAU / N;
    vec2 dir = vec2(cos(th), sin(th));
    float u = dot(q, dir), v = dot(q, vec2(-dir.y, dir.x));
    float r0 = rd * 0.85;
    float len = (1.0 - r0) * (0.80 + 0.20 * h2);
    float t = (u - r0) / len;
    if (t < 0.0 || t > 1.0) return vec4(0.0);
    // Each petal bends a little to one side and stirs in the breeze.
    float bend = (h3 - 0.5) * 0.5 + 0.05 * WIND * sin(t0 * 1.7 + kk * 2.1);
    v -= bend * t * t * len;
    float curl = step(0.80, h5);                          // a few petals curl at the tip
    float W = 0.092 + 0.03 * h4;
    float w = W * sin(PI * pow(t, 0.8)) * (1.0 - 0.12 * t);
    w *= 1.0 - 0.45 * curl * smoothstep(0.45, 1.0, t);
    float d = abs(v) - w;
    float cov = smoothstep(px, -px, d);
    if (cov <= 0.0) return vec4(0.0);

    float n = clamp(v / max(w, 1e-5), -1.0, 1.0);
    // Deep orange at the base, golden yellow body, paler tip; each petal a bit different.
    vec3 col = mix(vec3(0.78, 0.33, 0.03), vec3(0.97, 0.71, 0.09), smoothstep(0.02, 0.40, t));
    col = mix(col, vec3(1.0, 0.84, 0.30), 0.40 * smoothstep(0.55, 1.0, t));
    col *= 0.86 + 0.22 * h2;
    col.g *= 0.95 + 0.08 * h4;
    // Form: a shallow channel (darker edges), shadowed where it tucks under the disc,
    // and lit or not depending on which way it points.
    col *= (1.0 - 0.24 * n * n) * (0.50 + 0.50 * smoothstep(0.0, 0.28, t));
    col *= 0.84 + 0.26 * dot(dir, L);
    col *= 1.0 + 0.10 * n * dot(vec2(-dir.y, dir.x), L);
    // Fine lengthwise veins, faded out when too small to resolve.
    float pv = px * 3.5 / max(w, 1e-4);
    float vd = abs(fract(n * 3.5 + 0.5) - 0.5);
    float vein = (1.0 - smoothstep(0.0, max(pv, 0.04), vd)) * smoothstep(0.5, 0.2, pv);
    col *= 1.0 - 0.14 * vein * smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(0.8, 1.0, t));
    col *= 1.0 - 0.18 * smoothstep(0.06, 0.0, abs(n)) * smoothstep(0.5, 0.25, pv); // central crease
    // Curled tip: the paler underside shows on one half.
    float under = curl * smoothstep(0.5, 0.95, t) * smoothstep(-0.1, 0.2, n);
    col = mix(col, vec3(0.80, 0.70, 0.30), 0.55 * under);
    col *= shade * (1.0 - 0.20 * smoothstep(-2.0 * px, 0.0, d));
    return vec4(col * cov, cov);
}

// One ring of petals: the three nearest, drawn in a fixed per-petal depth order
// so overlaps never flip from pixel to pixel.
void petalRing(inout vec4 acc, vec2 q, float a, float px, float N, float off, float seed,
               float shade, vec2 L, float rd, float t0) {
    float k0 = floor(a / TAU * N - off + 0.5);
    float dA, dB, dC;
    vec4 cA = petal(q, k0 - 1.0, N, off, seed, rd, px, L, shade, t0, dA);
    vec4 cB = petal(q, k0,       N, off, seed, rd, px, L, shade, t0, dB);
    vec4 cC = petal(q, k0 + 1.0, N, off, seed, rd, px, L, shade, t0, dC);
    vec4 tc; float td;
    if (dA > dB) { tc = cA; cA = cB; cB = tc; td = dA; dA = dB; dB = td; }
    if (dB > dC) { tc = cB; cB = cC; cC = tc; td = dB; dB = dC; dC = td; }
    if (dA > dB) { tc = cA; cA = cB; cB = tc; }
    overP(acc, cA); overP(acc, cB); overP(acc, cC);
}

// The seed disc. Seeds sit on a Vogel spiral: seed n at radius rd*sqrt(n/N),
// angle n * golden angle. In (index, angle) space the seeds form a lattice; near
// any radius two consecutive Fibonacci numbers give a short, nearly square basis
// for it, so the nearest seed is found by solving a 2x2 system and testing the
// 3x3 lattice points around the result (no loop over all seeds).
vec4 disc(vec2 q, float px, float rd, float N, vec2 L) {
    float r = length(q);
    float cov = smoothstep(px, -px, r - rd);
    if (cov <= 0.0) return vec4(0.0);
    float tr = r / rd;
    float s = tr * tr * N;
    float th = atan(q.y, q.x);
    if (th < 0.0) th += TAU;
    float k = max(floor(log(4.0 * PI * 2.2360680 * max(s, 1.0)) / (2.0 * log(PHI))), 2.0);
    float F0 = floor(pow(PHI, k) / 2.2360680 + 0.5);
    float F1 = floor(pow(PHI, k + 1.0) / 2.2360680 + 0.5);
    vec2 v0 = vec2(F0, TAU * (F0 * GOLD - floor(F0 * GOLD + 0.5)));
    vec2 v1 = vec2(F1, TAU * (F1 * GOLD - floor(F1 * GOLD + 0.5)));
    float det = v0.x * v1.y - v1.x * v0.y;
    float ca = floor((s * v1.y - th * v1.x) / det + 0.5);
    float cb = floor((v0.x * th - v0.y * s) / det + 0.5);

    float best = 1e9, bn = 0.0;
    vec2 bpos = vec2(0.0);
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            float n = (ca + float(i)) * F0 + (cb + float(j)) * F1;
            if (n < 0.0 || n > N) continue;
            float an = TAU * fract(n * GOLD);
            vec2 sp = rd * sqrt(n / N) * vec2(cos(an), sin(an));
            float dd = length(q - sp);
            if (dd < best) { best = dd; bn = n; bpos = sp; }
        }
    }

    float sp = rd * sqrt(PI / N);                     // seed spacing
    float m = best / (0.5 * sp);                      // 0 at a seed centre, ~1 at its edge
    float pm = px / (0.5 * sp);
    // Greenish unripe core, dark brown seeds, a ring of open florets at the rim.
    vec3 seedC = mix(vec3(0.34, 0.33, 0.11), vec3(0.21, 0.12, 0.05), smoothstep(0.10, 0.40, tr));
    seedC = mix(seedC, vec3(0.52, 0.31, 0.08), smoothstep(0.72, 0.92, tr));
    seedC *= 0.82 + 0.36 * hash1(bn * 1.37);
    vec2 sd = (q - bpos) / (0.5 * sp);
    seedC *= 0.70 + 0.55 * clamp(0.5 + 0.5 * dot(sd, L) * 0.8 + 0.3 * (1.0 - m * m), 0.0, 1.0);
    vec3 gap = mix(vec3(0.10, 0.09, 0.03), vec3(0.05, 0.03, 0.015), smoothstep(0.1, 0.4, tr));
    float seedK = smoothstep(0.90 + pm, 0.90 - pm, m);
    vec3 col = mix(gap, seedC, seedK);
    // Tiny yellow pollen dots on the open florets near the rim.
    col = mix(col, vec3(0.95, 0.74, 0.22), 0.8 * smoothstep(0.38 + pm, 0.38 - pm, m) * smoothstep(0.80, 0.94, tr));
    // When seeds are smaller than a few pixels, fall back to their average colour.
    vec3 avgC = mix(gap, seedC, 0.65) + vec3(0.12, 0.08, 0.0) * smoothstep(0.80, 0.94, tr);
    col = mix(avgC, col, smoothstep(1.4, 2.8, sp / px));
    // A gently domed disc lit from the upper left, with a dark seam at its edge.
    col *= 0.86 + 0.24 * dot(q / rd, L);
    col *= 1.0 - 0.45 * smoothstep(-2.5 * px, 0.0, r - rd);
    return vec4(col * cov, cov);
}

vec4 flowerHead(vec2 q, float px, vec2 L, float rd, float N, float seed, float t0) {
    vec4 acc = vec4(0.0);
    float r = length(q);
    if (r > 1.05) return acc;
    float a = atan(q.y, q.x);
    if (a < 0.0) a += TAU;
    overP(acc, bracts(q - vec2(0.0, 0.10), px, L));          // back of the head shows a little at the top
    petalRing(acc, q, a, px, 21.0, 0.5, seed + 11.0, 0.68, L, rd, t0);
    petalRing(acc, q, a, px, 21.0, 0.0, seed, 1.0, L, rd, t0);
    overP(acc, disc(q + vec2(0.0, 0.05), px, rd, N, L));
    return acc;
}

// ---------------------------------------------------------------- bee
// A honeybee in side view, facing +x, about 1 unit long. fly: 1 in flight, 0 landed.
vec4 bee(vec2 q, float px, float fly, vec2 L) {
    vec4 acc = vec4(0.0);
    if (dot(q, q) > 0.5) return acc;

    // Legs: planted when landed, trailing back in flight. The hind leg carries pollen.
    float dl = 1e3;
    vec2 pollen = vec2(0.0);
    for (int j = 0; j < 3; j++) {
        float fj = float(j);
        vec2 hip = vec2(0.17 - 0.07 * fj, -0.07);
        vec2 kneeL = hip + vec2(0.06 - 0.10 * fj, -0.08);
        vec2 footL = vec2(hip.x + 0.10 - 0.16 * fj, -0.23);
        vec2 kneeF = hip + vec2(-0.05 - 0.02 * fj, -0.08);
        vec2 footF = kneeF + vec2(-0.10 - 0.03 * fj, -0.05);
        vec2 knee = mix(kneeL, kneeF, fly), foot = mix(footL, footF, fly);
        dl = min(dl, min(segment(q, hip, knee), segment(q, knee, foot)));
        if (j == 2) pollen = mix(knee, foot, 0.4);
    }
    over(acc, vec3(0.16, 0.11, 0.07), smoothstep(px, -px, dl - max(0.012, 0.5 * px)));
    over(acc, vec3(0.93, 0.62, 0.14), smoothstep(px, -px, length((q - pollen) * vec2(1.0, 0.8)) - 0.035));

    // Abdomen: amber with dark bands toward the tip, rounded body lit from above.
    vec2 ab = rot(q - vec2(-0.20, -0.03), 0.18);
    float da = ellipse(ab, vec2(0.0), vec2(0.29, 0.155));
    if (da < px) {
        float x = 1.0 - (ab.x + 0.29) / 0.58;             // 0 at the front, 1 at the tip
        float band = smoothstep(0.50, 0.58, fract(x * 4.6 + 0.15 + 0.6 * ab.y * ab.y)) * smoothstep(0.12, 0.25, x);
        vec3 col = mix(vec3(0.80, 0.54, 0.18), vec3(0.20, 0.12, 0.06), max(band, smoothstep(0.85, 0.97, x)));
        float ny = ab.y / 0.155;
        col *= 0.55 + 0.55 * clamp(0.6 + 0.6 * ny, 0.0, 1.0);
        col = mix(col, vec3(1.0, 0.95, 0.85), 0.5 * smoothstep(px, -px, ellipse(ab, vec2(0.02, 0.09), vec2(0.10, 0.022))));
        over(acc, col, smoothstep(px, -px, da));
    }

    // Thorax: fuzzy ochre-brown, its outline broken by fine hairs.
    vec2 tq = q - vec2(0.10, 0.02);
    float ta = atan(tq.y, tq.x);
    float fuzz = 0.014 * hash1(floor(ta * 9.0) + 3.0) * smoothstep(0.04, 0.02, px);
    float dt = length(tq) - (0.13 + fuzz);
    vec3 tc = vec3(0.56, 0.40, 0.20) * (0.60 + 0.50 * clamp(0.5 + 0.7 * dot(normalize(tq + 1e-4), L), 0.0, 1.0));
    over(acc, tc, smoothstep(px, -px, dt));

    // Head with a large dark compound eye, and an elbowed antenna.
    float dan = min(segment(q, vec2(0.31, 0.06), vec2(0.35, 0.16)), segment(q, vec2(0.35, 0.16), vec2(0.44, 0.12)));
    over(acc, vec3(0.12, 0.08, 0.06), smoothstep(px, -px, dan - max(0.010, 0.5 * px)));
    float dh = ellipse(q, vec2(0.27, -0.01), vec2(0.075, 0.095));
    over(acc, vec3(0.16, 0.11, 0.07), smoothstep(px, -px, dh));
    float de = ellipse(q, vec2(0.265, 0.012), vec2(0.042, 0.068));
    vec3 ec = mix(vec3(0.05, 0.04, 0.04), vec3(0.75, 0.75, 0.78), smoothstep(px, -px, length(q - vec2(0.255, 0.04)) - 0.014));
    over(acc, ec, smoothstep(px, -px, de));

    // Wings: folded flat over the abdomen when landed; in flight a motion-blurred fan.
    vec2 wb = vec2(0.10, 0.10);
    if (fly < 0.5) {
        vec2 wq = rot(q - wb, 0.10);
        float dw = ellipse(wq, vec2(-0.20, 0.0), vec2(0.27, 0.065));
        float vein = min(segment(wq, vec2(0.0, 0.02), vec2(-0.38, 0.03)), segment(wq, vec2(-0.10, 0.03), vec2(-0.30, -0.035)));
        float wm = smoothstep(px, -px, dw);
        over(acc, vec3(0.86, 0.88, 0.92), wm * 0.32);
        over(acc, vec3(0.30, 0.24, 0.18), wm * smoothstep(px, -px, vein - 0.006) * 0.6);
        over(acc, vec3(0.92, 0.93, 0.95), smoothstep(px, -px, abs(dw) - 0.005) * 0.45);
    } else {
        vec2 wq = q - wb;
        float wa = atan(wq.y, wq.x);
        float wr = length(wq);
        float fan = smoothstep(0.05, -0.05, abs(wa - 1.2) - 0.75) * smoothstep(px, -px, wr - 0.40);
        over(acc, vec3(0.88, 0.90, 0.94), fan * 0.16);
        for (int j = 0; j < 2; j++) {
            float ang = j == 0 ? 0.55 : 1.95;
            vec2 e = rot(wq, -ang);
            float dw = ellipse(e, vec2(0.20, 0.0), vec2(0.20, 0.06));
            over(acc, vec3(0.90, 0.92, 0.95), smoothstep(px, -px, dw) * 0.22);
            over(acc, vec3(0.95, 0.96, 0.98), smoothstep(px, -px, abs(dw) - 0.004) * 0.25);
        }
    }
    return acc;
}

vec2 bez(vec2 a, vec2 c, vec2 b, float t) { float m = 1.0 - t; return m * m * a + 2.0 * m * t * c + t * t * b; }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;
    float pw = 1.0 / iResolution.y;                          // one pixel in scene units
    vec2 Lw = normalize(vec2(-0.55, 0.83));                  // sunlight from the upper left
    vec4 acc = vec4(0.0);

    // Everything lives in the lower right; other pixels skip straight to the end.
    if (p.x > aspect - 0.85 * SIZE && p.y < 0.56 * SIZE) {
        for (int o = 0; o < 3; o++) {
            int i = o == 0 ? 0 : (o == 1 ? 2 : 1);           // back to front
            float fi = float(i);
            float x0, H, R, topDx, ang, sq, ph;
            vec2 c;
            plantState(i, aspect, t, x0, H, R, topDx, c, ang, sq, ph);

            // Leaves: three per stem, alternating sides, drooping from a petiole.
            for (int j = 0; j < 3; j++) {
                float fj = float(j);
                float side = mod(fi + fj, 2.0) < 0.5 ? -1.0 : 1.0;
                float y = H * (0.20 + 0.25 * fj);
                float Ll = R * (1.8 - 0.25 * fj);
                float slope;
                vec2 A = vec2(stemX(y, x0, H, topDx, slope), y);
                // Now and then a gust makes a leaf flutter (eased in and out).
                float fx = mod(t + 3.7 * fj + 2.3 * fi + 1.0, 6.5);
                float burst = smoothstep(0.0, 0.5, fx) * (1.0 - smoothstep(1.4, 2.6, fx));
                float fl = 0.05 * breeze(t, ph + fj) + 0.14 * burst * sin(fx * 8.0);
                float alpha = 0.62 + 0.3 * fl;
                vec2 B = A + Ll * 0.28 * vec2(side * cos(alpha), sin(alpha));
                if (length(p - B) > 1.1 * Ll) continue;
                float pd = segment(p, A, B);
                float pwid = Ll * 0.022 * (1.0 - 0.3 * clamp(dot(p - A, B - A) / dot(B - A, B - A), 0.0, 1.0));
                over(acc, vec3(0.20, 0.36, 0.11), smoothstep(pw, -pw, pd - pwid));
                float twist = 1.0 - 0.30 * burst * (0.5 + 0.5 * sin(fx * 8.0 + 1.0));
                vec2 dd = p - B;
                dd.x *= side;
                vec2 lq = rot(dd, -(-0.32 + fl));
                lq.y += 0.55 * lq.x * lq.x / Ll;                 // the blade droops toward its tip
                lq.y /= twist;                                   // turning about the midrib
                overP(acc, leaf(lq / Ll + vec2(0.05, 0.0), pw / (Ll * twist), fi * 3.1 + fj));
            }

            stem(acc, p, x0, H, topDx, R, pw);

            if (length(p - c) < R * 1.08) {
                vec2 lq = rot(p - c, -ang);
                vec2 q = vec2(lq.x, lq.y / sq) / R;
                vec2 L = rot(Lw, -ang);
                L = normalize(vec2(L.x, L.y / sq));
                float N = SEEDS * (R / (0.086 * SIZE)) * (R / (0.086 * SIZE));
                overP(acc, flowerHead(q, pw / (R * sq), L, 0.40, N, fi * 5.3, t + fi * 2.0));
            }
        }
    }

    // A honeybee flies in from the right, lands on the tall head, walks a little,
    // then turns and flies off.
    if (BEE > 0.5) {
        float bu = mod(t + 1.5, BEE_CYCLE);
        if (bu < 13.5) {
            float x0, H, R, topDx, ang, sq, ph;
            vec2 c;
            plantState(1, aspect, t, x0, H, R, topDx, c, ang, sq, ph);
            float walk = -0.16 * smoothstep(4.5, 8.5, bu);
            vec2 land = c + rot(vec2(0.10 + walk, 0.20 * sq) * R, ang) + vec2(0.0, 0.22 * BEE_LEN);
            vec2 pos = land;
            float face = -1.0, fly = 0.0, pitch = 0.0;
            if (bu < 3.5) {
                float x = bu / 3.5;
                float e = 1.0 - (1.0 - x) * (1.0 - x);
                vec2 far = vec2(aspect + 0.08, 0.50);
                pos = bez(far, vec2(aspect - 0.02, 0.62), land, e);
                pos += vec2(0.006 * sin(bu * 5.0), 0.007 * sin(bu * 7.3)) * (1.0 - smoothstep(0.6, 1.0, x));
                fly = 1.0 - smoothstep(3.15, 3.5, bu);
                pitch = 0.15 * (1.0 - x);
            } else if (bu > 10.0) {
                float k = bu - 10.0;
                fly = smoothstep(0.0, 0.2, k);
                face = mix(-1.0, 1.0, smoothstep(0.35, 0.95, k));
                float x = clamp((k - 0.2) / 3.3, 0.0, 1.0);
                vec2 far = vec2(aspect + 0.10, 0.30);
                pos = bez(land, land + vec2(0.04, 0.12), far, x * x);
                pos += vec2(0.0, 0.006 * sin(k * 6.0)) * smoothstep(0.0, 0.3, k);
                pitch = 0.12 * x;
            }
            pos.y += 0.003 * sin(t * 9.0) * fly;                 // hovering bob
            if (length(p - pos) < BEE_LEN * 0.8) {
                vec2 bq = rot(p - pos, -pitch * face) / BEE_LEN;
                float fs = sign(face) * max(abs(face), 0.06);    // turning round: squeeze through edge-on
                bq.x /= fs;
                vec2 L = vec2(Lw.x * sign(face), Lw.y);
                overP(acc, bee(bq, pw / (BEE_LEN * abs(fs)), fly, L));
            }
        }
    }

    vec3 rgb = base.rgb * (1.0 - acc.a * INTENSITY) + acc.rgb * INTENSITY;
    fragColor = vec4(rgb, base.a);
}
