// lotus — a summer lotus pond in the lower right: round lotus leaves, pink-tipped flowers and a bud swaying in the breeze, beading water drops, ripples and a red dragonfly.
// zh: 荷花
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY    = 0.92;   // overall strength (0 = off)
const float LEAF_ALPHA   = 0.84;   // opacity of the lotus leaves
const float FLOWER_ALPHA = 0.94;   // opacity of petals, stems and seed pods
const float WATER_ALPHA  = 0.30;   // how much the pond darkens what is behind it
const float BREEZE       = 1.0;    // strength of the swaying (0 = still)
const float RIPPLE       = 6.0;    // seconds between ripples from one source (2 sources)
const float ROLL         = 9.0;    // seconds between drops rolling into the big leaf's centre
const float FLY          = 18.0;   // seconds per dragonfly visit (arrive, perch, leave, gone)
const float DRAGON       = 0.068;  // dragonfly body length, in window heights

const float PI = 3.14159265;
const float SE = 0.30;             // sin / cos of the view elevation: we look slightly
const float CE = 0.954;            // down onto the pond, so circles on it become ellipses

// Petal directions around a flower, as (cos, sin) of the azimuth; sin > 0 is the far
// side. Each ring is listed far to near, so drawing in order layers them correctly.
const vec2 OUTER[6] = vec2[6](vec2(0.0, 1.0), vec2(0.866, 0.5), vec2(-0.866, 0.5),
                              vec2(-0.866, -0.5), vec2(0.866, -0.5), vec2(0.0, -1.0));
const vec2 INNER[6] = vec2[6](vec2(0.5, 0.866), vec2(-0.5, 0.866), vec2(1.0, 0.0),
                              vec2(-1.0, 0.0), vec2(-0.5, -0.866), vec2(0.5, -0.866));

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// The breeze: a slow gust that travels across the pond from left to right.
float wind(float x) {
    return BREEZE * (0.6 * sin(0.55 * iTime - 1.3 * x) + 0.4 * sin(1.07 * iTime + 1.7 - 2.2 * x));
}

// Thin lines radiating from the centre of a leaf. n: leaf space (unit circle = rim),
// sc: scene size of one leaf unit in x and y, so the lines stay ~1 px wide.
float veins(vec2 n, vec2 sc, float count, float seed, float px) {
    float rho = length(n);
    float a = atan(n.y, n.x);
    float f = fract(a / (2.0 * PI) * count + seed) - 0.5;
    float d = abs(f) * 2.0 * PI / count * rho * length(vec2(sin(a) * sc.x, cos(a) * sc.y));
    float w = px * mix(1.0, 0.3, clamp(rho, 0.0, 1.0));
    return smoothstep(w + px, w, d) * smoothstep(0.04, 0.14, rho);
}

// ---------------------------------------------------------------- water

void ripples(inout vec4 acc, vec2 p, float R, float px) {
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float tt = iTime / RIPPLE + fi * 0.5 + 0.92;
        float cyc = floor(tt), ph = fract(tt);
        vec2 c = vec2(R - 1.25 + 1.15 * hash1(cyc * 7.1 + fi * 3.3),
                      0.03 + 0.17 * hash1(cyc * 3.9 + fi * 5.7));
        float sc = mix(1.25, 0.7, c.y / 0.2);                    // nearer = bigger
        vec2 q = (p - c) / sc;
        if (abs(q.x) > 0.16 || abs(q.y) > 0.06) continue;
        vec2 n = q * vec2(1.0, 1.0 / SE);                         // undo the perspective
        float rho = length(n);
        float g = length(n * vec2(1.0, 1.0 / SE)) / max(rho, 1e-4);
        float m = 0.0;
        for (int k = 0; k < 3; k++) {
            float r = (0.15 - 0.045 * float(k)) * sqrt(ph);
            m += (1.0 - 0.25 * float(k)) * smoothstep(px, 0.0, abs(rho - r) / g * sc - 0.4 * px);
        }
        over(acc, vec3(0.78, 0.86, 0.90), min(m, 1.0) * 0.55 * (1.0 - ph) * (1.0 - ph));
    }
}

// ---------------------------------------------------------------- leaves

// A water drop beading on a leaf: dark refracting body, bright caustic at the
// bottom, a crisp highlight towards the light (top left) and a small cast shadow.
void droplet(inout vec4 acc, vec2 p, vec2 c, float s, float px) {
    vec2 d = p - c;
    if (dot(d, d) > 4.0 * s * s) return;
    float dsh = length((d - vec2(0.35 * s, -0.32 * s)) / vec2(1.0, 0.72)) - s;
    over(acc, vec3(0.04, 0.08, 0.06), smoothstep(px, -px, dsh) * 0.45);
    float db = length(d / vec2(1.0, 0.78)) - s;
    vec2 n = d / vec2(s, 0.78 * s);
    vec3 col = mix(vec3(0.13, 0.24, 0.19), vec3(0.66, 0.80, 0.66),
                   smoothstep(-0.1, -0.8, n.y - 0.4 * n.x) * 0.9);
    col = mix(col, vec3(0.08, 0.14, 0.11), smoothstep(-1.5 * px, 0.0, db) * 0.6);
    over(acc, col, smoothstep(px, -px, db) * 0.92);
    float dh = length((d - vec2(-0.32 * s, 0.30 * s)) / vec2(1.0, 0.8)) - 0.27 * s;
    over(acc, vec3(1.0, 1.0, 0.97), smoothstep(px, -px, dh) * 0.95);
}

// A leaf lying flat on the water, seen at a low angle: wavy round rim, veins from
// the centre where the stalk attaches, a dark line of shadow on the water around it.
// How a floating leaf drifts and bobs on the water.
vec2 drift(float seed) {
    return vec2(0.004 * sin(iTime * 0.21 + seed), 0.0015 * sin(iTime * 0.8 + seed * 2.0));
}

void floatLeaf(inout vec4 acc, vec2 p, vec2 c, float r, float seed, float px) {
    const float K = 0.30;
    c += drift(seed);
    vec2 q = p - c;
    float rk = r * K;
    if (abs(q.x) > r * 1.1 || abs(q.y) > rk * 1.3) return;
    vec2 n = vec2(q.x / r, q.y / rk);
    float rho = length(n);
    float a = atan(n.y, n.x);
    float wav = 1.0 + 0.025 * sin(a * 7.0 + seed) + 0.015 * sin(a * 13.0 + 2.0 * seed);
    float g = length(vec2(n.x / r, n.y / rk)) / max(rho, 1e-4);
    float d = (rho - wav) / g;
    over(acc, vec3(0.02, 0.05, 0.05), smoothstep(-px, 0.0, d) * smoothstep(3.0 * px, px, d) * 0.5);
    float cov = smoothstep(px, -px, d);
    if (cov <= 0.0) return;
    vec3 col = vec3(0.26, 0.43, 0.33) * (0.93 + 0.07 * n.y);
    col *= 0.95 + 0.05 * sin(q.x * 70.0 + seed) * sin(q.y * 230.0 - seed);
    col = mix(col, vec3(0.47, 0.58, 0.43), veins(n, vec2(r, rk), 21.0, seed * 0.3, px) * 0.55);
    col = mix(col, vec3(0.56, 0.62, 0.42), smoothstep(0.10, 0.05, rho));
    col = mix(col, vec3(0.55, 0.66, 0.48), smoothstep(-2.0 * px, 0.0, d) * 0.7);   // lit edge
    over(acc, col, cov * LEAF_ALPHA);
}

// A leaf held above the water on its stalk, cupped like a shallow bowl with the
// rim curling up: we see its blue-green inside through the rim, and below the
// front rim a band of the paler underside. Returns the drawn leaf in acc.
void raisedLeaf(inout vec4 acc, vec2 p, vec2 c, float r, float tilt, float seed, float px) {
    const float K = 0.34;
    float D = 0.30 * r;                                          // depth of the bowl
    float rk = r * K;
    vec2 q = rot(p - c, -tilt);
    if (abs(q.x) > r * 1.08 || q.y > rk * 1.12 || q.y < -(rk + D) * 1.1) return;
    vec2 n = vec2(q.x / r, q.y / rk);
    float rho = length(n);
    float a = atan(n.y, n.x);
    float wav = 1.0 + 0.035 * sin(a * 6.0 + seed) + 0.02 * sin(a * 11.0 + 2.0 * seed);
    float g = length(vec2(n.x / r, n.y / rk)) / max(rho, 1e-4);
    float dIn = (rho - wav) / g;

    // Underside, between the front rim and the bottom of the bowl.
    float xn = q.x / (r * wav);
    if (abs(xn) < 1.0 && q.y < 0.0) {
        float yb = -(rk * sqrt(1.0 - xn * xn) + D * (1.0 - xn * xn)) * (1.0 + 0.05 * sin(xn * 9.0 + seed));
        float cov = smoothstep(-px, px, q.y - yb);
        if (cov > 0.0) {
            float t = clamp(q.y / yb, 0.0, 1.0);
            vec3 col = mix(vec3(0.52, 0.58, 0.39), vec3(0.30, 0.37, 0.25), t);
            vec2 nv = vec2(q.x / r, (q.y + 0.5 * D) / rk);
            col = mix(col, vec3(0.70, 0.72, 0.53), veins(nv, vec2(r, rk), 18.0, seed, px) * 0.7);
            over(acc, col, cov * LEAF_ALPHA);
        }
    }

    // Inside of the bowl, with veins converging on the sunken centre.
    float cov = smoothstep(px, -px, dIn);
    if (cov <= 0.0) return;
    vec2 nv = vec2(q.x / r, (q.y + 0.6 * D) / rk);
    vec3 col = vec3(0.24, 0.42, 0.33) * (0.82 + 0.20 * n.y);     // far wall faces the light
    col *= 0.95 + 0.05 * sin(q.x * 80.0 + seed) * sin(q.y * 190.0 - seed);
    col = mix(col, vec3(0.47, 0.58, 0.43), veins(nv, vec2(r, rk), 22.0, seed * 0.37, px) * 0.55);
    col = mix(col, vec3(0.56, 0.62, 0.42), smoothstep(0.10, 0.05, length(nv)));
    float edge = smoothstep(-2.5 * px, -0.3 * px, dIn);
    col = mix(col, vec3(0.62, 0.72, 0.52), edge * smoothstep(0.2, -0.3, n.y) * 0.85);  // lit front lip
    col = mix(col, vec3(0.13, 0.24, 0.18), edge * smoothstep(-0.2, 0.3, n.y) * 0.5);  // back rim
    over(acc, col, cov * LEAF_ALPHA);
}

// Screen position of a point on the inside of a raised leaf; n is in rim space.
vec2 onLeaf(vec2 c, float r, float tilt, vec2 n) {
    float D = 0.30 * r;
    return c + rot(vec2(n.x * r, n.y * r * 0.34 - 0.6 * D * (1.0 - dot(n, n))), tilt);
}

// ---------------------------------------------------------------- stems

// A lotus stalk from the water up to `top`: a gentle curve, round shading, tiny
// prickles, a ring where it enters the water and a wobbly reflection below.
void stem(inout vec4 acc, vec2 p, vec2 w, vec2 top, float wid, float seed, float px) {
    float h = top.y - w.y;
    if (p.y < w.y - 0.06 || p.y > top.y + 0.005) return;
    if (p.x < min(w.x, top.x) - 0.02 || p.x > max(w.x, top.x) + 0.02) return;
    float t = clamp((p.y - w.y) / h, 0.0, 1.0);
    float x = w.x + (top.x - w.x) * t * t;
    float slope = 2.0 * (top.x - w.x) * t / h;
    float d = (p.x - x) / sqrt(1.0 + slope * slope);
    float ww = wid * (1.0 - 0.25 * t);
    if (p.y >= w.y) {
        // Prickles alternate sides along the stalk.
        float bump = pow(max(sin(p.y * 520.0 + seed), 0.0), 14.0);
        float side = sin(p.y * 260.0 + seed) > 0.0 ? 1.0 : -1.0;
        float pw = ww + 0.0011 * bump * step(0.0, d * side);
        float cov = smoothstep(px, -px, abs(d) - pw);
        float xr = clamp(d / ww, -1.0, 1.0);
        vec3 col = vec3(0.40, 0.50, 0.29) * (0.80 - 0.28 * xr + 0.2 * (1.0 - xr * xr));
        over(acc, col, cov * FLOWER_ALPHA);
    } else {
        float dy = w.y - p.y;
        float xs = w.x + 0.0025 * sin(p.y * 140.0 + iTime * 2.0 + seed);
        float cov = smoothstep(px, -px, abs(p.x - xs) - wid);
        over(acc, vec3(0.20, 0.27, 0.17), cov * 0.35 * (1.0 - dy / 0.06));
    }
    vec2 rq = (p - w) * vec2(1.0, 1.0 / SE);
    float ring = abs(length(rq) - 2.6 * wid) * SE;
    over(acc, vec3(0.75, 0.84, 0.86), smoothstep(px, 0.0, ring - 0.3 * px) * 0.45);
}

// ---------------------------------------------------------------- flowers

// One petal: base b, axis A (its projected length and direction), half width w.
// Broad and slightly pointed; white at the base, flushing to deep pink at the tip,
// with fine veins and one side of the trough in shade.
void petal(inout vec4 acc, vec2 q, vec2 b, vec2 A, float w, float cup, float bud, bool outside, float px) {
    float la = length(A);
    vec2 ah = A / la;
    vec2 d = q - b;
    float v = dot(d, vec2(-ah.y, ah.x));
    // Near petals rise towards us more steeply than we look down, so we see their
    // rounded outer side: the edges fall away and the petal shows as a broad arch
    // rather than a flat disc.
    d.y += cup * min(v * v / (w * w), 1.4);
    float u = dot(d, ah) / la;
    if (u < -0.05 || u > 1.02) return;
    v = dot(d, vec2(-ah.y, ah.x));
    float uu = clamp(u, 0.0, 1.0);
    float s = w * sqrt(uu + 0.03) * pow(1.0 - uu, mix(0.72, 1.0, bud)) / mix(0.45, 0.39, bud);
    float cov = smoothstep(px, -px, abs(v) - s) * smoothstep(-0.05, 0.0, u);
    if (cov <= 0.0) return;
    float vr = clamp(v / max(s, 1e-5), -1.0, 1.0);

    float tint = smoothstep(mix(0.25, 0.05, bud), 1.0, uu) * (0.75 + 0.25 * abs(vr));
    vec3 col = mix(vec3(0.97, 0.94, 0.91), vec3(0.92, 0.53, 0.66), tint);
    col = mix(col, vec3(0.80, 0.28, 0.48), smoothstep(0.80, 1.0, uu) * 0.8);
    col = mix(col, vec3(0.88, 0.91, 0.72), (1.0 - smoothstep(0.0, 0.25, uu)) * 0.5);
    col = mix(col, vec3(0.60, 0.70, 0.48), bud * (1.0 - smoothstep(0.1, 0.6, uu)) * 0.65);
    // Fine veins run the length of the petal and gather at its base.
    float f = fract(vr * 3.5 + 0.5) - 0.5;
    float vein = smoothstep(px, 0.0, abs(f) / 3.5 * s - 0.25 * px) * smoothstep(0.05, 0.3, uu);
    col = mix(col, col * vec3(0.86, 0.72, 0.80), vein * (outside ? 0.55 : 0.30));
    // Light from the top left: the trough of the petal shades one side.
    col *= 1.0 - 0.16 * smoothstep(0.0, 1.0, vr * (outside ? -1.0 : 1.0));
    col *= 0.78 + 0.22 * smoothstep(0.0, 0.35, uu);                 // deeper inside the flower
    col *= 1.0 - 0.14 * smoothstep(0.82, 1.0, abs(vr));             // edges separate petals
    over(acc, col, cov * FLOWER_ALPHA);
}

void ringPetal(inout vec4 acc, vec2 q, vec2 cs, float st, float ct, float len, float wid,
               float r0, float bud, float px) {
    vec2 A = len * vec2(st * cs.x, ct * CE + st * cs.y * SE);
    vec2 b = r0 * vec2(cs.x, cs.y * SE);
    float cup = 0.16 * len * st * max(-cs.y, 0.0) * max(-cs.y, 0.0);
    petal(acc, q, b, A, wid * (0.55 + 0.45 * abs(cs.y)), cup, bud, cs.y < 0.0, px);
}

// The stamens: a fringe of fine yellow filaments with anther tips around the pod.
void stamens(inout vec4 acc, vec2 q, float L, float seed, bool front, float px) {
    vec2 n = vec2(q.x, (q.y - 0.34 * L) / 0.45);
    if (front != (n.y < 0.0)) return;
    float rr = length(n);
    float a = atan(n.y, n.x) / (2.0 * PI) * 30.0;
    float outer = 0.30 * L * (0.88 + 0.12 * hash1(floor(a) + seed));
    if (rr < 0.15 * L || rr > outer + 2.0 * px) return;
    float dist = abs(fract(a) - 0.5) / 30.0 * 2.0 * PI * rr;
    float anther = smoothstep(outer - 0.05 * L, outer - 0.035 * L, rr);
    float cov = smoothstep(px, 0.0, dist - mix(0.35, 1.3, anther) * px) * smoothstep(outer + px, outer - px, rr);
    over(acc, mix(vec3(0.90, 0.76, 0.36), vec3(1.0, 0.86, 0.40), anther), cov * 0.9);
}

// The seed pod: an upside-down cone with a flat, dotted top.
void pod(inout vec4 acc, vec2 q, float L, float px) {
    vec2 tc = vec2(0.0, 0.42 * L);
    vec2 tr = vec2(0.19 * L, 0.19 * L * SE * 1.2);
    float y0 = 0.15 * L;
    float k = clamp((q.y - y0) / (tc.y - y0), 0.0, 1.0);
    float side = max(abs(q.x) - mix(0.09 * L, tr.x, k), y0 - q.y);
    side = q.y > tc.y ? 1.0 : side;
    vec2 n = (q - tc) / tr;
    float dt = (length(n) - 1.0) * tr.y;
    float cs = smoothstep(px, -px, side);
    vec3 col = vec3(0.74, 0.73, 0.32) * (0.95 - 0.30 * q.x / tr.x);
    over(acc, col, cs * FLOWER_ALPHA);
    float ct = smoothstep(px, -px, dt);
    if (ct <= 0.0) return;
    vec3 top = vec3(0.87, 0.85, 0.44) * (0.9 + 0.1 * n.y);
    // Carpels: one in the middle and a ring of seven.
    float a = atan(n.y, n.x);
    float sa = (floor(a / (2.0 * PI) * 7.0) + 0.5) / 7.0 * 2.0 * PI;
    float dd = min(length((n - 0.6 * vec2(cos(sa), sin(sa))) * tr), length(n * tr));
    top = mix(top, vec3(0.55, 0.58, 0.26), smoothstep(px, -px, dd - 0.035 * L));
    top = mix(top, vec3(0.42, 0.45, 0.20), smoothstep(-px, 0.5 * px, dt) * 0.6);
    over(acc, top, ct * FLOWER_ALPHA);
}

// A lotus flower on top of its stem. o: 0 = closed bud, 1 = wide open.
void flower(inout vec4 acc, vec2 p, vec2 b, float tilt, float L, float o, float seed, float px) {
    vec2 q = rot(p - b, -tilt);
    if (length(q - vec2(0.0, 0.42 * L)) > 1.3 * L) return;
    float tO = mix(0.10, 0.98, o), tI = mix(0.04, 0.80, o);
    float sO = sin(tO), cO = cos(tO), sI = sin(tI), cI = cos(tI);
    float bud = 1.0 - smoothstep(0.0, 0.5, o);
    float wO = 0.42 * L, wI = 0.37 * L;
    float rO = mix(0.03, 0.07, o) * L, rI = mix(0.02, 0.05, o) * L;

    for (int k = 0; k < 3; k++)                                  // outer ring, far side
        ringPetal(acc, q, OUTER[k], sO, cO, L * (1.0 + 0.06 * sin(seed + float(k) * 2.7)), wO, rO, bud, px);
    for (int k = 0; k < 4; k++)                                  // inner ring, far side
        ringPetal(acc, q, INNER[k], sI, cI, 0.86 * L * (1.0 + 0.05 * sin(seed + float(k) * 1.9)), wI, rI, bud, px);
    if (o > 0.6) {
        stamens(acc, q, L, seed, false, px);
        pod(acc, q, L, px);
        stamens(acc, q, L, seed, true, px);
    }
    for (int k = 4; k < 6; k++)                                  // inner ring, near side
        ringPetal(acc, q, INNER[k], sI, cI, 0.74 * L * (1.0 + 0.05 * sin(seed + float(k) * 1.9)), wI, rI, bud, px);
    for (int k = 3; k < 6; k++)                                  // outer ring, near side
        ringPetal(acc, q, OUTER[k], sO, cO, L * (1.0 + 0.06 * sin(seed + float(k) * 2.7)), wO, rO, bud, px);
}

// ---------------------------------------------------------------- dragonfly

// One wing: root at r0 on the body, sweeping out at angle al from the head, side
// +1 = far wing (drawn up the screen), -1 = near wing. beat lifts it.
void wing(inout vec4 acc, vec2 q, vec2 r0, float al, float side, float len, float wid,
          float beat, bool hind, float S, float px) {
    vec2 A = len * vec2(cos(al), side * sin(al) * cos(beat) * 0.85 + sin(al) * sin(beat) * 0.5);
    vec2 B = wid * vec2(-sin(al), side * cos(al) * 0.85);
    if (abs(B.y) < 0.02 * wid) B.y = 0.02 * wid;
    vec2 d = q - r0;
    float det = A.x * B.y - A.y * B.x;
    float s = (d.x * B.y - d.y * B.x) / det;
    float t = (A.x * d.y - A.y * d.x) / det;
    if (s < -0.05 || s > 1.05) return;
    t *= sign(det) * side;                                       // t > 0: leading edge
    float e = length(vec2((s - 0.5) / 0.5, t / (t > 0.0 ? 0.75 : (hind ? 1.25 : 1.0))));
    float dist = (e - 1.0) * wid * S * 0.55;
    float cov = smoothstep(px, -px, dist);
    if (cov <= 0.0) return;
    vec3 col = vec3(0.86, 0.89, 0.92);
    float a = 0.26;
    if (hind) { col = mix(col, vec3(0.85, 0.52, 0.20), smoothstep(0.22, 0.05, s)); a += 0.3 * smoothstep(0.22, 0.05, s); }
    float edge = smoothstep(-2.0 * px, -0.5 * px, dist);
    col = mix(col, vec3(0.30, 0.22, 0.18), edge * 0.8);
    a = mix(a, 0.75, edge);
    float stig = step(0.80, s) * step(s, 0.90) * step(0.35, t);  // pterostigma
    col = mix(col, vec3(0.45, 0.14, 0.10), stig);
    a = max(a, stig * 0.95);
    over(acc, col, cov * a);
}

// A red darter (Sympetrum), seen from above at a low angle, head towards -x.
void dragonfly(inout vec4 acc, vec2 p, vec2 pos, float pitch, float beat, float legs, float px) {
    float S = DRAGON;
    if (length(p - pos) > 0.85 * S) return;
    vec2 hd = vec2(-cos(pitch), sin(pitch));                     // head direction
    vec2 up = vec2(hd.y, -hd.x);
    if (up.y < 0.0) up = -up;
    vec2 dq = p - pos;
    vec2 q = vec2(dot(dq, hd), dot(dq, up)) / S;
    float lpx = px / S;

    // Far wings, behind the body.
    wing(acc, q, vec2(0.30, 0.0), 1.22, 1.0, 0.74, 0.062, beat, false, S, px);
    wing(acc, q, vec2(0.22, 0.0), 1.95, 1.0, 0.70, 0.085, beat, true, S, px);

    // Legs gripping the perch.
    if (legs > 0.01) {
        float dl = 1e3;
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            vec2 hip = vec2(0.33 - 0.035 * fk, -0.02);
            vec2 foot = vec2(0.37 - 0.07 * fk, -0.02 - 0.11 * legs);
            dl = min(dl, segment(q, hip, mix(hip, foot, 0.5) + vec2(0.02, 0.0)));
            dl = min(dl, segment(q, mix(hip, foot, 0.5) + vec2(0.02, 0.0), foot));
        }
        over(acc, vec3(0.12, 0.08, 0.07), smoothstep(lpx, -lpx, dl - 0.6 * lpx) * 0.9);
    }

    // Abdomen: long and slim, slightly swollen at the base, ringed segments.
    float hw = 0.026 + 0.014 * smoothstep(0.04, 0.17, q.x) - 0.006 * smoothstep(-0.40, -0.58, q.x);
    float da = max(abs(q.y) - hw, max(-0.58 - q.x, q.x - 0.24));
    float ca = smoothstep(lpx, -lpx, da);
    if (ca > 0.0) {
        float yr = q.y / hw;
        vec3 col = vec3(0.74, 0.17, 0.10) * (0.62 + 0.38 * (1.0 - yr * yr));
        col = mix(col, vec3(0.92, 0.42, 0.28), smoothstep(0.55, 0.3, abs(yr - 0.35)) * 0.6);
        float seg = abs(fract((0.20 - q.x) / 0.085) - 0.5) * 0.085;
        col = mix(col, vec3(0.38, 0.09, 0.06), smoothstep(lpx, 0.0, 0.0425 - seg - 0.2 * lpx) * step(q.x, 0.18) * 0.6);
        over(acc, col, ca);
    }
    // Thorax with dark side stripes.
    float dt = length((q - vec2(0.30, 0.0)) / vec2(0.10, 0.068)) - 1.0;
    float ct = smoothstep(lpx, -lpx, dt * 0.068);
    if (ct > 0.0) {
        vec3 col = vec3(0.56, 0.25, 0.15) * (0.75 + 0.25 * smoothstep(-0.6, 0.6, q.y / 0.068));
        float st = abs(fract((q.x + q.y * 0.6) / 0.06) - 0.5);
        col = mix(col, vec3(0.22, 0.10, 0.07), smoothstep(0.12, 0.05, st) * 0.6);
        over(acc, col, ct);
    }
    // Head: big compound eyes, red-brown above, with a sharp glint.
    float dh = length((q - vec2(0.425, 0.0)) / vec2(0.058, 0.085)) - 1.0;
    float ch = smoothstep(lpx, -lpx, dh * 0.058);
    if (ch > 0.0) {
        vec3 col = mix(vec3(0.36, 0.30, 0.30), vec3(0.62, 0.22, 0.14), smoothstep(-0.06, 0.04, q.y));
        col *= 0.7 + 0.3 * smoothstep(0.0, -0.8, dh);
        over(acc, col, ch);
        over(acc, vec3(1.0), smoothstep(lpx, -lpx, length(q - vec2(0.44, 0.04)) - 0.014));
    }

    // Near wings, in front of the body.
    wing(acc, q, vec2(0.30, 0.0), 1.22, -1.0, 0.74, 0.062, beat, false, S, px);
    wing(acc, q, vec2(0.22, 0.0), 1.95, -1.0, 0.70, 0.085, beat, true, S, px);
}

// ---------------------------------------------------------------- scene

// Stem foot (on the water) and flower base (top of the stem) of flower i, swayed.
void flowerFrame(int i, float R, out vec2 w, out vec2 b, out float tilt, out float L, out float o) {
    if (i == 0)      { w = vec2(R - 0.64, 0.175); b = vec2(R - 0.645, 0.395); L = 0.072; o = 0.0; }   // bud
    else if (i == 1) { w = vec2(R - 1.05, 0.155); b = vec2(R - 1.08, 0.270); L = 0.080; o = 0.45; }  // half open
    else             { w = vec2(R - 0.49, 0.120); b = vec2(R - 0.52, 0.310); L = 0.105; o = 1.0; }   // open
    float h = b.y - w.y;
    float k = wind(b.x);
    b += vec2(0.10 * h * k, -0.004 * k * k);
    tilt = -0.10 * k;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float R = aspect;                                            // right edge
    float px = 1.0 / iResolution.y;
    vec4 acc = vec4(0.0);

    // ---- The dragonfly's state (needed below for the bud it lands on) ----
    vec2 w; vec2 b; float tilt; float L; float o;
    flowerFrame(0, R, w, b, tilt, L, o);
    vec2 tip = b + rot(vec2(0.0, 0.94 * L), tilt);
    vec2 perch = tip + vec2(0.30, 0.13) * DRAGON;
    float ft = mod(iTime + 0.8, FLY);
    vec2 dpos = vec2(-9.0);
    float pitch = 0.0, beat = 0.0, legs = 0.0;
    if (ft < 2.4) {
        // Arrive from the right along a curve, slowing down to land.
        float x = ft / 2.4;
        float t = 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x);
        vec2 a0 = vec2(R + 0.12, perch.y + 0.22), c0 = vec2(perch.x + 0.30, perch.y + 0.16);
        float m = 1.0 - t;
        dpos = m * m * a0 + 2.0 * m * t * c0 + t * t * perch;
        vec2 v = 2.0 * m * (c0 - a0) + 2.0 * t * (perch - c0);
        pitch = clamp(atan(v.y, -v.x), -0.35, 0.35) * (1.0 - smoothstep(0.75, 1.0, x));
        beat = 0.55 * sin(iTime * 38.0) * (1.0 - smoothstep(0.85, 1.0, x));
        legs = smoothstep(0.7, 1.0, x);
    } else if (ft < 12.0) {
        // Perched on the bud tip, riding its sway; wings settle, now and then dip.
        dpos = perch;
        pitch = 0.04 * sin(iTime * 0.9);
        beat = -0.08 - 0.10 * smoothstep(0.6, 1.0, sin(iTime * 0.8 + 1.0));
        legs = 1.0;
    } else if (ft < 14.4) {
        // Lift, then dart off low to the left.
        float x = (ft - 12.0) / 2.4;
        float t = x * x;
        vec2 c0 = perch + vec2(-0.25, 0.12), a1 = vec2(-0.2, 0.30);
        float m = 1.0 - t;
        dpos = m * m * perch + 2.0 * m * t * c0 + t * t * a1;
        vec2 v = 2.0 * m * (c0 - perch) + 2.0 * t * (a1 - c0);
        pitch = clamp(atan(v.y, -v.x), -0.35, 0.35) * smoothstep(0.0, 0.2, x);
        beat = 0.55 * sin(iTime * 38.0) * smoothstep(0.0, 0.08, x);
        legs = 1.0 - smoothstep(0.0, 0.25, x);
    }

    // ---- The pond (lower right) ----
    if (p.y < 0.56 && p.x > R - 1.45) {
        float pm = smoothstep(0.50, 0.30, p.y) * smoothstep(R - 1.45, R - 1.05, p.x);
        over(acc, vec3(0.03, 0.07, 0.08), pm * WATER_ALPHA);

        // Sky glints on the gently moving water: broken, crisp horizontal streaks.
        float wv = p.y * 150.0 + 1.5 * sin(p.x * 9.0 - iTime * 0.7 + p.y * 30.0);
        float ld = (0.5 - abs(fract(wv) - 0.5)) / 150.0;
        float dash = smoothstep(0.6, 0.9, sin(p.x * 26.0 + hash1(floor(wv)) * 6.28 - iTime * 0.45));
        over(acc, vec3(0.72, 0.80, 0.84), smoothstep(px, 0.0, ld - 0.2 * px) * dash * pm * 0.22);

        ripples(acc, p, R, px);

        // Far floating leaves.
        floatLeaf(acc, p, vec2(R - 1.30, 0.175), 0.075, 1.0, px);
        floatLeaf(acc, p, vec2(R - 0.62, 0.165), 0.100, 2.0, px);
        floatLeaf(acc, p, vec2(R - 0.10, 0.155), 0.110, 3.0, px);

        // The bud and the half-open flower (farther back).
        for (int i = 0; i < 2; i++) {
            flowerFrame(i, R, w, b, tilt, L, o);
            stem(acc, p, w, b, 0.0034, float(i) * 3.0, px);
            flower(acc, p, b, tilt, L, o, float(i) * 5.0 + 1.0, px);
        }

        // Raised leaf on the left, with one bead of water.
        {
            vec2 c = vec2(R - 0.82, 0.29), wl = vec2(R - 0.80, 0.14);
            float k = wind(c.x);
            c.x += 0.08 * (c.y - wl.y) * k;
            float tl = -0.06 * k;
            stem(acc, p, wl, c + rot(vec2(0.0, -0.034), tl), 0.0042, 7.0, px);
            raisedLeaf(acc, p, c, 0.12, tl, 1.7, px);
            droplet(acc, p, onLeaf(c, 0.12, tl, vec2(0.25, 0.45)), 0.0042, px);
        }

        // The open flower.
        flowerFrame(2, R, w, b, tilt, L, o);
        stem(acc, p, w, b, 0.0042, 11.0, px);
        flower(acc, p, b, tilt, L, o, 9.0, px);

        // Big raised leaf on the right: beads of water, and every few seconds a drop
        // rolls down the curved surface into the pool in the middle.
        {
            float r = 0.16;
            vec2 c = vec2(R - 0.20, 0.32), wl = vec2(R - 0.18, 0.10);
            float k = wind(c.x);
            c.x += 0.08 * (c.y - wl.y) * k;
            float tl = -0.06 * k;
            stem(acc, p, wl, c + rot(vec2(0.0, -0.048), tl), 0.0048, 13.0, px);
            raisedLeaf(acc, p, c, r, tl, 4.2, px);
            droplet(acc, p, onLeaf(c, r, tl, vec2(0.42, 0.42)), 0.0050, px);
            droplet(acc, p, onLeaf(c, r, tl, vec2(-0.55, 0.22)), 0.0040, px);

            float rt = (iTime + 2.0) / ROLL;
            float cyc = floor(rt), ph = fract(rt);
            float hit = smoothstep(0.38, 0.42, ph);
            float pool = 0.0105 * (1.0 + 0.22 * hit * (1.0 - smoothstep(0.45, 1.0, ph)));
            float wob = 1.0 + 0.10 * hit * sin((ph - 0.40) * 70.0) * exp(-(ph - 0.40) * 18.0);
            droplet(acc, p, onLeaf(c, r, tl, vec2(0.0, 0.0)), pool * wob, px);
            if (ph < 0.42) {
                float ang = 0.5 + 2.2 * hash1(cyc * 5.3);         // somewhere on the far half
                vec2 st = 0.80 * vec2(cos(ang), sin(ang));
                float x = clamp((ph - 0.06) / 0.34, 0.0, 1.0);
                vec2 at = st * (1.0 - x * x * (3.0 - 2.0 * x));
                float sz = 0.0050 * smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(0.38, 0.42, ph));
                if (sz > 0.0003) droplet(acc, p, onLeaf(c, r, tl, at), sz, px);
            }
        }

        // Near floating leaves.
        floatLeaf(acc, p, vec2(R - 0.95, 0.070), 0.150, 4.0, px);
        floatLeaf(acc, p, vec2(R - 0.36, 0.035), 0.190, 5.0, px);
        droplet(acc, p, vec2(R - 0.30, 0.044) + drift(5.0), 0.0058, px);
        droplet(acc, p, vec2(R - 0.47, 0.026) + drift(5.0), 0.0045, px);
    }

    dragonfly(acc, p, dpos, pitch, beat, legs, px);

    fragColor = vec4(base.rgb * (1.0 - acc.a * INTENSITY) + acc.rgb * INTENSITY, base.a);
}
