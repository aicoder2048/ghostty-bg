// coral — a lively coral reef along the bottom: staghorn, brain and fan corals, sponges, anemones and darting reef fish.
// zh: 珊瑚礁
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.80;   // overall strength (0 = off)
const float CURRENT   = 1.0;    // how strongly the current sways fans and tentacles
const float HAZE      = 0.55;   // blue depth haze on the back row of corals (0 = none)
const float CAUSTICS  = 1.0;    // strength of the moving dappled light on the reef
const float FISH_SIZE = 0.075;  // reef fish length as a fraction of the window height

const float PI = 3.14159265;

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Paint a colour with coverage a over what is already there (premultiplied).
void over(inout vec4 dst, vec3 c, float a) {
    a = clamp(a, 0.0, 1.0);
    dst.rgb = c * a + dst.rgb * (1.0 - a);
    dst.a = a + dst.a * (1.0 - a);
}

// One slow back-and-forth current; x shifts the phase so a wave rolls along the reef.
float current(float t, float x) {
    return CURRENT * (0.65 * sin(t * 0.55 - x * 1.2) + 0.35 * sin(t * 0.91 - x * 2.0 + 1.0));
}

// ---------------------------------------------------------------- staghorn
// Antler-like branching coral. q: base at the origin, about 1 unit tall.
// Four main branches, each forking twice; pale growing tips like the real thing.
vec4 staghorn(vec2 q, float seed, float sway, vec3 cBase, vec3 cTip, float aa) {
    if (abs(q.x) > 0.85 || q.y < -0.05 || q.y > 1.1) return vec4(0.0);
    q.x -= sway * q.y * q.y;                                   // rigid near the base, a little give at the tips
    float best = 1e9, bw = 1.0, tip = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float h1 = hash1(seed + fi * 7.31);
        float h2 = hash1(seed + fi * 3.17 + 5.0);
        float ang = (fi - 1.5) * 0.46 + (h1 - 0.5) * 0.25;
        float len = 0.95 + 0.15 * h2 - abs(fi - 1.5) * 0.14;
        vec2 a = vec2((fi - 1.5) * 0.045, 0.0);
        vec2 m = a + vec2(sin(ang), cos(ang)) * len * 0.42;
        float ang2 = ang * 0.55;                               // upper part curls back toward vertical
        vec2 b = m + vec2(sin(ang2), cos(ang2)) * len * 0.55;
        float s1 = ang + (h1 > 0.5 ? 0.62 : -0.62);
        vec2 c1 = m + vec2(sin(s1), cos(s1)) * len * 0.36;
        vec2 m2 = mix(m, b, 0.45);
        float s2 = ang2 - (h1 > 0.5 ? 0.55 : -0.55);
        vec2 c2 = m2 + vec2(sin(s2), cos(s2)) * len * 0.30;

        vec2 g; float w, d;
        g = seg(q, a, m);  w = mix(0.070, 0.055, g.y); d = g.x - w;
        if (d < best) { best = d; bw = w; tip = 0.0; }
        g = seg(q, m, b);  w = mix(0.055, 0.036, g.y); d = g.x - w;
        if (d < best) { best = d; bw = w; tip = g.y; }
        g = seg(q, m, c1); w = mix(0.045, 0.032, g.y); d = g.x - w;
        if (d < best) { best = d; bw = w; tip = g.y; }
        g = seg(q, m2, c2); w = mix(0.040, 0.030, g.y); d = g.x - w;
        if (d < best) { best = d; bw = w; tip = g.y; }
    }
    float a = smoothstep(aa, -aa, best);
    float round = sqrt(clamp(-best / bw, 0.0, 1.0));           // fake cylinder shading
    float polyps = smoothstep(0.5, 1.0, sin(q.y * 95.0 + 4.0 * sin(q.x * 37.0)));   // rows of tiny polyp cups
    vec3 c = mix(cBase, cTip, smoothstep(0.35, 1.0, tip));
    c *= (0.45 + 0.65 * round) * (1.0 - 0.10 * polyps * round);
    return vec4(c, a);
}

// ---------------------------------------------------------------- brain coral
// A dome with meandering grooves. q in units of the dome radius, base at origin.
vec4 brain(vec2 q, vec3 col, float aa) {
    if (abs(q.x) > 1.05 || q.y < -0.1 || q.y > 0.8) return vec4(0.0);
    vec2 e = vec2(q.x, q.y / 0.74);
    float r = length(e);
    float a = smoothstep(aa, -aa, (r - 1.0) * 0.74) * smoothstep(-0.08, 0.0, q.y);
    float z = sqrt(max(0.0, 1.0 - r * r));
    vec3 n = vec3(e, z);
    // A gyroid sampled on the dome surface: its zero lines meander like brain ridges
    // and squeeze together toward the rim, as they would on a real sphere.
    vec3 s = n * 8.5 + vec3(0.0, 0.0, 1.3);
    float gy = sin(s.x) * cos(s.y) + sin(s.y) * cos(s.z) + sin(s.z) * cos(s.x);
    float groove = 1.0 - smoothstep(0.08, 0.45, abs(gy));
    float diff = clamp(dot(n, normalize(vec3(-0.35, 0.8, 0.5))), 0.0, 1.0);
    vec3 c = col * (0.30 + 0.85 * diff) * (1.0 - 0.65 * groove);
    c += col * 0.25 * smoothstep(0.35, 0.0, abs(gy)) * diff;   // lit ridge crests
    return vec4(c, a);
}

// ---------------------------------------------------------------- sea fan
vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Distance to the nearest cell wall of a jittered grid (Voronoi): small on the walls.
float cellWalls(vec2 x) {
    vec2 n = floor(x), f = fract(x);
    float d1 = 8.0, d2 = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 g = vec2(float(i), float(j));
        vec2 r = g + hash2(n + g) * 0.9 + 0.05 - f;
        float d = dot(r, r);
        if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
    }
    return sqrt(d2) - sqrt(d1);
}

// A lacy gorgonian fan on a short stem that bends with the current. q: base at origin,
// about 1 unit tall.
vec4 seafan(vec2 q, float sway, float t, vec3 col, float aa) {
    if (abs(q.x) > 0.95 || q.y < -0.02 || q.y > 1.1) return vec4(0.0);
    q.x -= sway * pow(max(q.y, 0.0), 1.5) + 0.025 * sin(t * 1.3 - q.y * 5.0) * q.y;
    vec2 v = q - vec2(0.0, 0.07);
    float r = length(v);
    float th = atan(v.x, v.y);
    float R = 0.92 - 0.22 * th * th + 0.03 * sin(th * 11.0) + 0.02 * sin(th * 23.0 + 1.0);
    float inside = smoothstep(aa, -aa, max(r - R, abs(th) - 1.2) * 0.6);
    float stem = smoothstep(aa, -aa, seg(q, vec2(0.0), vec2(0.0, 0.12)).x - 0.03);

    // A few thicker main ribs radiate from the stem.
    // Lace: an irregular net of small holes (cell walls), holes a bit taller than wide.
    float mesh = 1.0 - smoothstep(0.05, 0.16, cellWalls(vec2(th * (4.0 + 14.0 * r), r * 17.0)));
    float rib = 1.0 - smoothstep(0.04, 0.10 + 0.05 * (1.0 - r), abs(sin(th * 3.3 + 0.3 * sin(r * 6.0))));
    float rim = smoothstep(0.05, 0.0, R - r);
    float lace = max(max(mesh * 0.85, rib), rim) ;
    float a = max(inside * (0.16 + 0.84 * lace), stem);
    vec3 c = col * (0.65 + 0.5 * smoothstep(0.2, 0.9, r / R)) * (0.8 + 0.3 * max(rib, rim));
    return vec4(c, a);
}

// ---------------------------------------------------------------- tube sponges
// Three vase-shaped tubes with dark openings. q: base at origin, tallest tube 1 unit.
vec4 tubes(vec2 q, float t, float seed, vec3 col, float aa) {
    if (abs(q.x) > 0.75 || q.y < -0.02 || q.y > 1.15) return vec4(0.0);
    vec4 acc = vec4(0.0);
    for (int j = 0; j < 3; j++) {
        float fj = float(j);
        float k = j == 0 ? -1.0 : (j == 1 ? 1.0 : 0.0);        // middle tube drawn last, in front
        float hj = hash1(seed + fj * 4.7);
        float h = k == 0.0 ? 1.0 : 0.62 + 0.2 * hj;
        float rr0 = 0.11 + 0.02 * hj;
        vec2 l = q - vec2(k * 0.22, 0.0);
        l.x -= (k * 0.22 + 0.03 * sin(t * 0.7 + fj * 2.1)) * l.y;   // splay out, sway a little
        float rr = rr0 * (0.80 + 0.35 * clamp(l.y / h, 0.0, 1.0));  // flares toward the rim
        float body = max(abs(l.x) - rr, max(l.y - h, -l.y));
        vec2 rim = (l - vec2(0.0, h)) / vec2(rr, rr * 0.32);
        float rimD = (length(rim) - 1.0) * rr * 0.32;
        float a = smoothstep(aa, -aa, min(body, rimD));
        float shade = sqrt(max(0.0, 1.0 - (l.x / rr) * (l.x / rr)));
        float hole = smoothstep(0.9, 0.7, length(rim / vec2(0.85, 0.8)));
        float lip = smoothstep(0.6, 1.0, length(rim)) * step(h - rr * 0.5, l.y);
        vec3 c = col * (0.35 + 0.75 * shade) * (0.9 + 0.1 * sin(l.y * 70.0 + l.x * 30.0));
        c = mix(c, col * 1.25, lip * 0.5);
        c = mix(c, col * 0.12, hole);
        over(acc, c, a);
    }
    if (acc.a > 0.0) acc.rgb /= acc.a;
    return acc;
}

// ---------------------------------------------------------------- anemone
// A sea anemone: short column, then many soft tentacles fanning up from the oral
// disc, waving in the current. row 0 = column + back tentacles, row 1 = front ones,
// so a clownfish can hide between the two. q: base at origin, about 1 unit tall.
vec4 anemone(vec2 q, float t, float cur, int row, vec3 cT, vec3 cTip, vec3 cCol, float aa) {
    if (abs(q.x) > 1.1 || q.y < -0.02 || q.y > 1.2) return vec4(0.0);
    vec4 acc = vec4(0.0);
    if (row == 0) {
        float w = 0.17 + 0.10 * clamp(q.y / 0.3, 0.0, 1.0);
        float col = smoothstep(aa, -aa, max(abs(q.x) - w, max(q.y - 0.32, -q.y)));
        float sh = sqrt(max(0.0, 1.0 - (q.x / w) * (q.x / w)));
        over(acc, cCol * (0.35 + 0.7 * sh) * (0.85 + 0.15 * sin(q.y * 60.0)), col);
    }
    vec2 v = q - vec2(0.0, 0.0);
    float r = length(v);
    float th = atan(v.x, v.y);
    const float R0 = 0.30, L = 0.72, N = 15.0, SPAN = 2.9;
    float rel = r - R0;
    if (rel > -0.06 && rel < L * 1.15) {
        float fr = float(row);
        float dth = SPAN / (N - 1.0);
        float off = row == 0 ? 0.5 * dth : 0.0;
        // The whole crown leans with the current; a wave also runs up each tentacle.
        float bend = (cur * 0.45 + 0.30 * sin(t * 1.15 - rel * 6.0 + fr * 1.3)) * max(rel, 0.0);
        float tb = th - bend;
        float n0 = floor((tb - off) / dth + 0.5);
        for (int k = -1; k <= 1; k++) {
            float m = n0 + float(k);
            if (abs(m) > (N - 1.0) * 0.5 + 0.1 - fr * 0.0) continue;
            float hm = hash1(m * 3.7 + fr * 17.0 + 1.0);
            float wob = 0.10 * sin(t * 1.7 + m * 2.3 + fr - rel * 8.0) * max(rel, 0.0);
            float thc = m * dth + off + wob;
            float side = abs(thc) / (SPAN * 0.5);
            float len = L * (0.78 + 0.22 * hm) * (1.0 - 0.30 * side * side);
            float tt = rel / len;
            float w = mix(0.050, 0.030, clamp(tt, 0.0, 1.0)) * (1.0 + 0.35 * smoothstep(0.8, 1.0, tt));
            float across = abs(tb - thc) * r;
            float d = max(across - w, rel - len);
            // round tip
            d = min(d, length(vec2(across, max(rel - len, 0.0))) - w);
            d = max(d, rel - len - w);
            float a = smoothstep(aa, -aa, d) * smoothstep(-0.06, 0.0, rel);
            float sh = sqrt(clamp(-d / w, 0.0, 1.0));
            vec3 c = mix(cT, cTip, smoothstep(0.55, 0.98, tt)) * (0.40 + 0.70 * sh);
            c *= row == 0 ? 0.62 : 1.0;
            over(acc, c, a);
        }
    }
    if (acc.a > 0.0) acc.rgb /= acc.a;
    return acc;
}

// ---------------------------------------------------------------- fish
// A small reef fish seen from the side, facing +x, about 1 unit long.
// kind 0 blue-green chromis, 1 blue damsel with yellow tail, 2 royal gramma, 3 yellow tang.
vec4 reefFish(vec2 q, float tail, float kind, float aa) {
    if (q.x < -0.85 || q.x > 0.58 || abs(q.y) > 0.5) return vec4(0.0);
    float hb = 0.27 + 0.03 * q.x;
    float db = (length(vec2(q.x / 0.5, q.y / hb)) - 1.0) * hb;
    vec2 tq = q - vec2(-0.42, 0.0);
    float tx = -tq.x;
    tq.y -= tail * 0.35 * max(tx, 0.0);                        // tail swings side to side (seen as up/down flex)
    float dt = max(max(abs(tq.y) - (0.04 + 0.85 * tx), -tx), tx - 0.34);
    dt = max(dt, (tx - 0.17) * 0.9 - abs(tq.y));               // forked notch
    vec2 fd = seg(q, vec2(0.18, 0.20), vec2(-0.36, 0.10));
    float dorsal = fd.x - mix(0.07, 0.02, fd.y);
    vec2 fa = seg(q, vec2(-0.02, -0.20), vec2(-0.34, -0.10));
    float anal = fa.x - mix(0.06, 0.02, fa.y);
    float d = min(min(db, dt), min(dorsal, anal));
    float a = smoothstep(aa, -aa, d);

    vec3 c1, c2;
    if (kind < 0.5)      { c1 = vec3(0.30, 0.85, 0.95); c2 = c1; }
    else if (kind < 1.5) { c1 = vec3(0.20, 0.42, 1.00); c2 = vec3(1.00, 0.85, 0.15); }
    else if (kind < 2.5) { c1 = vec3(0.80, 0.30, 1.00); c2 = vec3(1.00, 0.82, 0.10); }
    else                 { c1 = vec3(1.00, 0.88, 0.18); c2 = c1; }
    float back = smoothstep(0.05, -0.30, q.x);                 // rear half / tail colour
    vec3 c = mix(c1, c2, back);
    c *= 0.65 + 0.45 * smoothstep(0.25, -0.15, q.y);           // pale belly, darker back
    c *= 1.0 - 0.25 * smoothstep(-0.02, -0.0, max(dorsal, -db)) * step(db, 0.0); // fins a bit darker
    float fin = step(0.0, db) * a;
    c = mix(c, c * 0.7, fin * 0.6);
    float eye = smoothstep(0.065, 0.045, length(q - vec2(0.30, 0.05)));
    float glint = smoothstep(0.022, 0.0, length(q - vec2(0.315, 0.068)));
    c = mix(c, vec3(0.03), eye);
    c += glint * 0.9;
    return vec4(c, a);
}

// Clownfish: rounder, orange with three white bands edged in black, rounded tail.
vec4 clownfish(vec2 q, float tail, float aa) {
    if (q.x < -0.85 || q.x > 0.6 || abs(q.y) > 0.55) return vec4(0.0);
    float hb = 0.30 + 0.02 * q.x;
    float db = (length(vec2(q.x / 0.5, q.y / hb)) - 1.0) * hb;
    vec2 tq = q - vec2(-0.40, 0.0);
    tq.y -= tail * 0.30 * max(-tq.x, 0.0);
    float dt = length(tq / vec2(1.0, 1.15) - vec2(-0.18, 0.0)) - 0.20;
    dt = max(dt, tq.x - 0.02);
    vec2 fd = seg(q, vec2(0.22, 0.24), vec2(-0.34, 0.16));
    float dorsal = fd.x - mix(0.08, 0.05, fd.y) - 0.03 * sin(fd.y * PI * 2.0);
    vec2 fa = seg(q, vec2(-0.05, -0.24), vec2(-0.32, -0.14));
    float anal = fa.x - 0.06;
    float fins = min(min(dt, dorsal), anal);
    float d = min(db, fins);
    float a = smoothstep(aa, -aa, d);

    vec3 orange = vec3(1.00, 0.45, 0.06);
    vec3 c = orange * (0.70 + 0.40 * smoothstep(0.25, -0.15, q.y));
    // Bands curve with the body; each is white with a black edge.
    float bx = 1e9;
    bx = min(bx, abs(q.x - 0.24 + 0.25 * q.y * q.y) - 0.07);
    bx = min(bx, abs(q.x + 0.05 - 0.10 * q.y * q.y) - 0.075);
    bx = min(bx, abs(q.x + 0.40) - 0.035);
    float band = smoothstep(0.012, -0.004, bx);
    float edge = smoothstep(0.035, 0.018, abs(bx));
    c = mix(c, vec3(0.95), band);
    c *= 1.0 - 0.85 * edge * (1.0 - band);
    // Fins have black tips.
    float finEdge = smoothstep(-0.05, -0.01, fins) * step(0.0, db);
    c *= 1.0 - 0.8 * finEdge;
    float eye = smoothstep(0.07, 0.05, length(q - vec2(0.33, 0.06)));
    float glint = smoothstep(0.025, 0.0, length(q - vec2(0.345, 0.08)));
    c = mix(c, vec3(0.03), eye);
    c += glint;
    return vec4(c, a);
}

// dir is about +1 swimming right, -1 swimming left. Turn a fish smoothly: when its horizontal speed reverses, it narrows to a sliver
// and widens facing the other way instead of flipping in one frame.
vec2 fishLocal(vec2 p, vec2 pos, float dir, float size) {
    vec2 q = (p - pos) / size;
    float f = clamp(dir * 3.0, -1.0, 1.0);
    float s = (f < 0.0 ? -1.0 : 1.0) * (0.2 + 0.8 * abs(f));
    q.x /= s;
    return q;
}

// Path of reef fish i: darts and pauses (speed swings between 0.1x and 1.9x),
// weaving up and down between the corals.
vec2 fishPath(float i, float t, float W, out float vx) {
    float h1 = hash1(i * 12.9898 + 1.0), h2 = hash1(i * 78.233 + 2.0), h3 = hash1(i * 39.425 + 3.0);
    float w = 0.22 + 0.16 * h1;
    float s = w * t + 0.45 * sin(2.0 * w * t + h2 * 6.28) + h3 * 6.28;
    float ds = w * (1.0 + 0.9 * cos(2.0 * w * t + h2 * 6.28));
    float cx = (0.12 + 0.80 * fract(i * 0.381 + 0.13)) * W;
    float amp = 0.12 + 0.18 * h2;
    float xn = cx / W;
    float cy = 0.08 + 0.20 * xn + 0.05 * h3;
    vx = cos(s);                                                   // facing: sign of the x velocity
    return vec2(cx + amp * sin(s), cy + 0.035 * sin(1.3 * s + h1 * 6.0) + 0.01 * sin(t * 1.7 + i));
}

// Dappled light from the wavy surface above: three drifting, warped sine waves;
// where they cancel out we get a moving network of thin bright lines.
float caustic(vec2 p, float t) {
    vec2 q = p * 11.0;
    float a = sin(q.x + 1.5 * sin(q.y * 0.8 + t * 0.7) + t * 0.4);
    float b = sin(q.y * 1.1 + 1.5 * sin(q.x * 0.9 - t * 0.6) - t * 0.5);
    float c = sin((q.x + q.y) * 0.7 + sin(q.x * 0.6 + t * 0.5) + t * 0.3);
    return smoothstep(0.30, 0.0, abs(a + b + c) / 3.0);
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float W = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * W, 1.0 - uv.y);
    float xn = uv.x;
    float t = iTime;
    float px = 1.0 / iResolution.y;

    // Everything lives under a line that rises from left to right; bubbles may drift
    // a little higher on the right. Above that, return at once (costs almost nothing).
    float reefTop = 0.17 + 0.34 * xn;
    bool bubbleZone = xn > 0.55 && p.y < 0.80;
    if (p.y > reefTop && !bubbleZone) { fragColor = base; return; }

    vec4 acc = vec4(0.0);
    vec3 haze = vec3(0.25, 0.50, 0.80);

    if (p.y < reefTop) {
        // Back reef: a rocky ridge and taller corals, washed blue by distance.
        float hb = 0.07 + 0.11 * xn + 0.015 * sin(p.x * 5.0 + 1.0) + 0.008 * sin(p.x * 13.0);
        float rockB = smoothstep(px, -px, p.y - hb);
        over(acc, mix(vec3(0.30, 0.28, 0.40), haze, HAZE) * 0.55, rockB * 0.55);

        vec4 e; vec2 b; float S;
        #define BACK(E) e = E; over(acc, mix(e.rgb, haze, HAZE) * 0.85, e.a * 0.75);
        #define BASEB(X) b = vec2((X) * W, 0.0); b.y = 0.06 + 0.11 * (X) + 0.015 * sin(b.x * 5.0 + 1.0);

        BASEB(0.26) S = 0.17;
        BACK(seafan((p - b) / S, 0.06 * current(t, b.x), t, vec3(0.80, 0.35, 0.95), px * 1.5 / S))
        BASEB(0.46) S = 0.15;
        BACK(tubes((p - b) / S, t, 3.0, vec3(0.60, 0.45, 1.00), px * 1.5 / S))
        BASEB(0.58) S = 0.26;
        BACK(seafan((p - b) / S, 0.06 * current(t, b.x), t + 2.0, vec3(1.00, 0.50, 0.32), px * 1.5 / S))
        BASEB(0.77) S = 0.24;
        BACK(staghorn((p - b) / S, 11.0, 0.02 * current(t, b.x), vec3(0.70, 0.50, 0.95), vec3(0.95, 0.85, 1.0), px * 1.5 / S))
        BASEB(0.92) S = 0.31;
        BACK(seafan((p - b) / S, 0.06 * current(t, b.x), t + 4.0, vec3(1.00, 0.38, 0.72), px * 1.5 / S))

        // Fish swimming behind the front corals.
        for (int i = 0; i < 3; i++) {
            float fi = float(i) * 2.0 + 1.0, vx;
            vec2 fp = fishPath(fi, t, W, vx);
            float sz = FISH_SIZE * (0.8 + 0.3 * hash1(fi * 5.1));
            if (abs(p.x - fp.x) > sz || abs(p.y - fp.y) > sz) continue;
            vec4 f = reefFish(fishLocal(p, fp, vx, sz), sin(t * 9.0 + fi * 2.0), mod(fi, 4.0), px * 1.5 / sz);
            over(acc, mix(f.rgb, haze, 0.2), f.a);
        }

        // Front reef rock, then the front corals planted on it.
        float hf = 0.035 + 0.05 * xn + 0.012 * sin(p.x * 9.0) + 0.006 * sin(p.x * 23.0 + 2.0);
        float rockF = smoothstep(px, -px, p.y - hf);
        // Lumpy rock crusted with patches of pink coralline algae and green turf.
        float bumps = sin(p.x * 47.0 + 3.0 * sin(p.y * 31.0)) + sin(p.y * 53.0 + 3.0 * sin(p.x * 29.0));
        vec3 rockC = mix(vec3(0.45, 0.32, 0.42), vec3(0.35, 0.45, 0.32), 0.5 + 0.5 * sin(p.x * 6.0 + 1.5 * sin(p.x * 17.0)));
        over(acc, rockC * (0.8 + 0.12 * bumps), rockF * 0.6);

        #define FRONT(E) e = E; over(acc, e.rgb, e.a);
        #define BASEF(X) b = vec2((X) * W, 0.0); b.y = 0.025 + 0.05 * (X) + 0.012 * sin(b.x * 9.0);

        BASEF(0.06) S = 0.065;
        FRONT(brain((p - b) / S, vec3(0.70, 0.85, 0.40), px * 1.5 / S))
        BASEF(0.17) S = 0.15;
        FRONT(staghorn((p - b) / S, 3.0, 0.02 * current(t, b.x), vec3(0.95, 0.35, 0.65), vec3(1.0, 0.85, 0.92), px * 1.5 / S))
        BASEF(0.30) S = 0.13;
        FRONT(tubes((p - b) / S, t + 1.0, 7.0, vec3(1.00, 0.58, 0.18), px * 1.5 / S))
        BASEF(0.40) S = 0.075;
        FRONT(brain((p - b) / S, vec3(1.00, 0.62, 0.45), px * 1.5 / S))
        BASEF(0.50) S = 0.13;
        float c1 = current(t, b.x);
        FRONT(anemone((p - b) / S, t, c1, 0, vec3(1.0, 0.55, 0.80), vec3(1.0, 0.92, 0.95), vec3(0.85, 0.35, 0.50), px * 1.5 / S))
        FRONT(anemone((p - b) / S, t, c1, 1, vec3(1.0, 0.55, 0.80), vec3(1.0, 0.92, 0.95), vec3(0.85, 0.35, 0.50), px * 1.5 / S))
        BASEF(0.64) S = 0.27;
        FRONT(staghorn((p - b) / S, 5.0, 0.02 * current(t, b.x), vec3(0.65, 0.35, 1.00), vec3(0.95, 0.82, 1.0), px * 1.5 / S))
        BASEF(0.73) S = 0.08;
        FRONT(brain((p - b) / S, vec3(0.95, 0.85, 0.35), px * 1.5 / S))

        // The clownfish's anemone: back tentacles, the clownfish, then front tentacles
        // so it really dips in among them.
        BASEF(0.84) S = 0.17;
        vec2 ab = b; float aS = S;
        float c2 = current(t, b.x);
        vec3 aT = vec3(0.70, 0.95, 0.55), aTip = vec3(0.95, 0.55, 0.95), aCol = vec3(0.90, 0.50, 0.35);
        FRONT(anemone((p - ab) / aS, t + 3.0, c2, 0, aT, aTip, aCol, px * 1.5 / aS))
        {
            // 10 s cycle: tucked in, rises out, loops above the crown, sinks back.
            float ph = fract((t + 6.5) / 10.0);
            float out1 = smoothstep(0.05, 0.25, ph) * (1.0 - smoothstep(0.70, 0.92, ph));
            float ang = ph * 2.0 * PI;
            vec2 cp = ab + aS * vec2(0.08 + 0.50 * out1 * sin(ang * 1.5) + 0.06 * sin(t * 1.3),
                                      0.62 + 0.55 * out1 + 0.10 * out1 * sin(ang * 3.0) + 0.03 * sin(t * 2.1));
            float vx = (0.47 * out1 * cos(ang * 1.5) + 0.078 * cos(t * 1.3)) / 0.12;
            float sz = 0.10;
            if (abs(p.x - cp.x) < sz && abs(p.y - cp.y) < sz) {
                vec4 f = clownfish(fishLocal(p, cp, vx, sz), sin(t * 8.0), px * 1.5 / sz);
                over(acc, f.rgb, f.a);
            }
        }
        FRONT(anemone((p - ab) / aS, t + 3.0, c2, 1, aT, aTip, aCol, px * 1.5 / aS))

        BASEF(0.965) S = 0.37;
        FRONT(seafan((p - b) / S, 0.07 * current(t, b.x), t + 1.0, vec3(1.00, 0.32, 0.28), px * 1.5 / S))

        // Fish in front of everything.
        for (int i = 0; i < 4; i++) {
            float fi = float(i) * 2.0, vx;
            vec2 fp = fishPath(fi, t, W, vx);
            float sz = FISH_SIZE * (0.85 + 0.3 * hash1(fi * 5.1));
            if (abs(p.x - fp.x) > sz || abs(p.y - fp.y) > sz) continue;
            vec4 f = reefFish(fishLocal(p, fp, vx, sz), sin(t * 9.0 + fi * 2.0), mod(fi + 1.0, 4.0), px * 1.5 / sz);
            over(acc, f.rgb, f.a);
        }

        // Moving dapples of sunlight, strongest on the upper parts of the reef.
        float cs = caustic(p, t);
        float up = 0.5 + 0.8 * clamp(p.y / reefTop, 0.0, 1.0);
        acc.rgb *= 0.85 + 0.45 * CAUSTICS * cs * up;
        acc.rgb += acc.a * CAUSTICS * 0.45 * cs * up * vec3(0.8, 1.0, 1.0);
    }

    // A few bubbles rising from the reef on the right.
    if (xn > 0.55) {
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            float h1 = hash1(fi * 21.7 + 4.0), h2 = hash1(fi * 9.3 + 1.0);
            float T = 5.0 + 3.0 * h2;
            float age = mod(t + h1 * T, T);
            float r = (0.006 + 0.007 * h1) * (1.0 + 0.15 * age);
            vec2 c = vec2((0.62 + 0.36 * hash1(fi * 3.3)) * W + 0.012 * sin(age * 2.5 + fi), 0.22 + 0.08 * fi * 0.1 + age * 0.085);
            if (abs(p.y - c.y) > r + 0.01) continue;
            float d = length(p - c);
            float ring = smoothstep(r, r - 2.0 * px, d) * (0.25 + 0.75 * smoothstep(r * 0.55, r, d));
            float glint = smoothstep(r * 0.35, 0.0, length(p - c - vec2(-0.35, 0.35) * r));
            float fade = smoothstep(0.0, 0.5, age) * (1.0 - smoothstep(0.52, 0.66, c.y));
            over(acc, vec3(0.75, 0.92, 1.0), (ring * 0.6 + glint) * fade);
        }
    }

    vec3 col = acc.a > 0.0 ? acc.rgb / acc.a : vec3(0.0);
    vec3 rgb = blend(base.rgb, col, acc.a * INTENSITY);
    fragColor = vec4(rgb, base.a);
}
