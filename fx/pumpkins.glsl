// pumpkins — a small cluster of candlelit jack-o'-lanterns glows in the lower right, warming the drifting ground mist under a hazy moon.
// zh: 南瓜灯
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float OPACITY   = 0.72;   // how solid the dark pumpkin silhouettes are
const float SIZE      = 0.090;  // half-height of the largest pumpkin (fraction of window height)
const float CANDLE    = 1.0;    // brightness of the carved faces and their bloom
const float SPILL     = 1.0;    // warm light pooled on the ground and lighting the mist
const float MIST      = 0.50;   // density of the low drifting ground mist
const float MOON      = 1.0;    // soft hazy moon in the upper right (0 = off)
const int   BATS      = 3;      // distant bats looping slowly near the moon

const float PI = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise1(float x) {
    float i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash1(i), hash1(i + 1.0), f);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

// Candle flicker: smooth noise at two rates plus a rare slow "gutter" dip, so it
// breathes irregularly and never repeats or pops between frames.
float flicker(float seed, float t) {
    float f = 0.70 + 0.20 * vnoise1(t * 5.3 + seed * 13.1)
                   + 0.10 * vnoise1(t * 12.7 + seed * 7.3);
    f -= 0.22 * smoothstep(0.72, 1.0, vnoise1(t * 0.9 + seed * 3.7));
    return f;
}

// Rough signed distance to an ellipse (fine at these sizes).
float sdEllipse(vec2 p, vec2 r) {
    return (length(p / r) - 1.0) * min(r.x, r.y);
}

// Signed distance to a triangle a-b-c (by Inigo Quilez).
float sdTri(vec2 p, vec2 a, vec2 b, vec2 c) {
    vec2 e0 = b - a, e1 = c - b, e2 = a - c;
    vec2 v0 = p - a, v1 = p - b, v2 = p - c;
    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

// Carved holes (pumpkin units): slanted eyes, a small nose, a jagged grin.
float sdFace(vec2 q) {
    vec2 m = vec2(abs(q.x), q.y);
    float eyes = sdTri(m, vec2(0.12, 0.10), vec2(0.44, 0.08), vec2(0.33, 0.36));
    float nose = sdTri(q, vec2(-0.07, -0.08), vec2(0.07, -0.08), vec2(0.0, 0.06));

    float top = -0.22 + 0.55 * q.x * q.x;
    float bot = -0.50 + 1.05 * q.x * q.x;
    float mouth = max(q.y - top, bot - q.y) * 0.7;
    mouth = max(mouth, abs(q.x) - 0.62);
    mouth = max(mouth, -max(abs(q.x) - 0.06, -(q.y + 0.33)));            // top tooth
    mouth = max(mouth, -max(abs(abs(q.x) - 0.24) - 0.05, q.y + 0.37));    // bottom teeth
    return min(min(eyes, nose), mouth);
}

// Pumpkin body as overlapping lobes; returns distance, and in `shade` the
// cylinder-like light of whichever lobe is frontmost (dark seams = ribs).
float sdPumpkin(vec2 q, out float shade) {
    float m = abs(q.x);
    float c  = sdEllipse(q - vec2(0.0, -0.02), vec2(0.44, 0.95));
    float in1 = sdEllipse(vec2(m - 0.44, q.y), vec2(0.48, 0.98));
    float out1 = sdEllipse(vec2(m - 0.80, q.y + 0.05), vec2(0.44, 0.86));
    float nx;
    if (c < 0.0)        nx = q.x / 0.44;
    else if (in1 < 0.0) nx = (m - 0.44) / 0.48;
    else                nx = (m - 0.80) / 0.44;
    shade = sqrt(max(1.0 - nx * nx, 0.0));
    return min(c, min(in1, out1));
}

// Distant bat seen from the front, wings flapping; returns coverage.
float bat(vec2 b, float flap, float aa) {
    float ax = abs(b.x);
    float yt = 0.08 + flap * 0.55 * ax - 0.12 * ax * ax;            // leading edge
    float yb = yt - (0.40 * (1.0 - ax) + 0.07)                     // scalloped trailing edge
             + 0.10 * abs(sin(ax * 3.0 * PI)) * smoothstep(0.15, 0.3, ax);
    float wing = max(max(b.y - yt, yb - b.y), ax - 1.0);
    float body = sdEllipse(b - vec2(0.0, -0.04), vec2(0.13, 0.26));
    float head = length(b - vec2(0.0, 0.20)) - 0.10;
    float ears = max(abs(ax - 0.06) - 0.03, abs(b.y - 0.31) - 0.06);
    float d = min(min(wing, body), min(head, ears));
    return smoothstep(aa, -aa, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;
    float R = aspect;
    float px = 1.0 / iResolution.y;

    vec3 col = base.rgb;
    vec3 warm = vec3(1.0, 0.52, 0.16);
    vec3 hot  = vec3(1.0, 0.82, 0.48);

    // ---- Hazy moon, upper right -------------------------------------------
    vec2 M = vec2(R - 0.20, 0.80);
    if (MOON > 0.0 && p.x > R - 0.85 && p.y > 0.45) {
        float d = length(p - M);
        float disc = smoothstep(0.034 + 2.0 * px, 0.034 - 2.0 * px, d);
        // Faint mottling so the disc is not a flat sticker.
        float mott = 0.90 + 0.10 * vnoise((p - M) * 60.0);
        float veil = 0.6 + 0.4 * vnoise(vec2(p.x * 4.0 - t * 0.05, p.y * 9.0));   // thin cloud drifting across
        col = mix(col, vec3(0.93, 0.90, 0.82) * mott, disc * 0.50 * MOON * veil);
        col += vec3(0.55, 0.60, 0.75) * MOON * (0.10 * exp(-d * 14.0) + 0.05 * exp(-d * 4.5)) * veil;

        // Bats loop slowly through the moonlit sky; dark against the halo.
        for (int k = 0; k < BATS; k++) {
            float fk = float(k);
            vec2 pos = M + vec2(-0.16 + 0.22 * sin(t * 0.21 + fk * 2.1) + 0.05 * sin(t * 0.57 + fk),
                                -0.06 + 0.08 * sin(t * 0.33 + fk * 1.7) + 0.025 * sin(t * 0.83 + fk * 3.0));
            float s = 0.016 + 0.005 * fk;
            vec2 b = (p - pos) / s;
            if (abs(b.x) > 1.3 || abs(b.y) > 1.3) continue;
            float flap = sin(t * (7.0 + 1.3 * fk) + fk * 4.0);
            float cov = bat(b, flap, 1.5 * px / s);
            col = mix(col, vec3(0.03, 0.025, 0.04), cov * 0.62);
        }
    }

    // ---- Lower-right lantern scene -----------------------------------------
    if (p.y < 0.40) {
        // Three pumpkins: medium behind-left, large in the middle, small in front.
        float g = 0.034;                                 // ground line
        vec2 c0 = vec2(R - 0.46, g + 0.62 * SIZE);  float r0 = 0.64 * SIZE;
        vec2 c1 = vec2(R - 0.28, g + 0.93 * SIZE);  float r1 = SIZE;
        vec2 c2 = vec2(R - 0.12, g - 0.006 + 0.48 * SIZE); float r2 = 0.50 * SIZE;
        float f0 = flicker(1.0, t), f1 = flicker(2.0, t), f2 = flicker(3.0, t);

        // Light emitted by each lantern (its carved face sits a bit above centre).
        vec2 l0 = c0 + vec2(0.0, 0.05 * r0), l1 = c1 + vec2(0.0, 0.05 * r1), l2 = c2 + vec2(0.04 * r2, 0.05 * r2);
        vec2 d0 = p - l0, d1 = p - l1, d2 = p - l2;
        float G0 = f0 / (1.0 + dot(d0, d0) / (r0 * r0 * 2.2));
        float G1 = f1 / (1.0 + dot(d1, d1) / (r1 * r1 * 2.2));
        float G2 = f2 / (1.0 + dot(d2, d2) / (r2 * r2 * 2.2));
        float G = G0 + G1 + G2;

        // Soft halo of candlelight in the night air.
        col += warm * G * 0.10 * SPILL * CANDLE;

        // Warm pools on the ground, flattened by perspective.
        float pool = 0.0;
        pool += f0 * exp(-pow((p.x - c0.x) / (r0 * 2.6), 2.0) - pow((p.y - g) / (r0 * 0.45), 2.0));
        pool += f1 * exp(-pow((p.x - c1.x) / (r1 * 2.6), 2.0) - pow((p.y - g) / (r1 * 0.45), 2.0));
        pool += f2 * exp(-pow((p.x - c2.x) / (r2 * 2.6), 2.0) - pow((p.y - g) / (r2 * 0.45), 2.0));
        col += warm * pool * 0.22 * SPILL;

        // Pumpkins, back to front.
        for (int i = 0; i < 3; i++) {
            vec2 c = i == 0 ? c0 : (i == 1 ? c1 : c2);
            float r = i == 0 ? r0 : (i == 1 ? r1 : r2);
            float fl = i == 0 ? f0 : (i == 1 ? f1 : f2);
            float other = G - (i == 0 ? G0 : (i == 1 ? G1 : G2));   // light from the neighbours
            vec2 q = (p - c) / r;
            if (abs(q.x) > 1.5 || q.y < -1.2 || q.y > 1.5) continue;
            float aa = 1.5 * px / r;

            float shade;
            float body = sdPumpkin(q, shade);
            float cover = smoothstep(aa, -aa, body);

            // Curved stem on top, leaning a little.
            vec2 sq = q - vec2(0.03, 0.86);
            sq.x -= 0.55 * max(sq.y, 0.0) * max(sq.y, 0.0);
            float sw = 0.085 - 0.035 * clamp(sq.y / 0.30, 0.0, 1.0);        // tapers upward
            float stem = max(abs(sq.x) - sw, abs(sq.y - 0.13) - 0.15);
            stem = max(stem, sq.y - 0.26 - 0.25 * sq.x);                   // slanted cut tip
            float stemCov = smoothstep(aa, -aa, stem);

            // Face: the small front pumpkin is turned a little to the right.
            float turn = i == 2 ? 0.16 : (i == 0 ? -0.08 : 0.0);
            float squ  = i == 2 ? 0.85 : 1.0;
            float fs   = i == 1 ? 0.82 : 0.78;
            vec2 fq = vec2((q.x - turn) / squ, q.y - 0.02) / fs;
            float face = sdFace(fq) * fs * squ;
            float inBody = smoothstep(-0.02, -0.10, body);
            float hole = smoothstep(aa, -aa, face) * inBody;
            // The cut wall: visible along the lower edge of each hole (we look slightly down).
            float wall = smoothstep(-aa, aa, sdFace(fq - vec2(0.0, 0.06)) * fs * squ) * hole;

            // Dark skin, gently modelled: lobe cylinders (ribs) times an overall sphere.
            float sphere = sqrt(max(1.0 - q.x * q.x / 1.6 - q.y * q.y * 0.85, 0.0));
            vec3 skin = vec3(0.11, 0.04, 0.012) * (0.30 + 0.70 * shade * (0.5 + 0.5 * sphere));
            // Candlelight glowing through the thin flesh around the carving.
            float sss = exp(-max(face, 0.0) * 9.0) * inBody;
            skin += vec3(0.55, 0.16, 0.03) * sss * fl * 0.55 * CANDLE * (0.4 + 0.6 * shade);
            // Rim light: an edge band lit by the ground pool from below and the neighbours.
            float edge = smoothstep(-0.20, -0.01, body) * cover;
            float below = smoothstep(0.1, -0.9, q.y);
            skin += warm * edge * (0.30 * below * fl + 0.55 * other) * SPILL * (0.5 + 0.5 * shade);
            // Cool moonlight catching the upper right shoulder.
            float up = clamp(dot(normalize(q + vec2(0.0, 0.2)), normalize(vec2(0.6, 0.8))), 0.0, 1.0);
            skin += vec3(0.35, 0.42, 0.60) * edge * up * up * 0.22 * MOON;

            vec3 stemCol = vec3(0.06, 0.05, 0.025) + vec3(0.30, 0.38, 0.5) * 0.10 * MOON
                         + warm * 0.12 * other;
            col = mix(col, stemCol, stemCov * (1.0 - cover) * OPACITY);
            col = mix(col, skin, cover * OPACITY);

            // Light through the carving: hot near the candle, deeper at the edges.
            vec3 holeCol = mix(warm, hot, smoothstep(0.0, -0.07, face)) * fl;
            holeCol = mix(holeCol, vec3(0.85, 0.36, 0.08) * fl, wall * 0.8);
            col = mix(col, holeCol, hole * 0.88 * CANDLE);

            // Bloom just outside the holes, spilling across the skin.
            float bloom = exp(-max(face, 0.0) * 22.0) * (1.0 - hole) * inBody;
            col += hot * bloom * 0.30 * fl * CANDLE;
        }

        // Low ground mist, drifting slowly sideways and lit by the lanterns.
        float h = smoothstep(0.26, 0.0, p.y);
        if (h > 0.0) {
            vec2 mp = vec2(p.x * 2.4 - t * 0.045, p.y * 7.0);
            float n = 0.55 * vnoise(mp) + 0.30 * vnoise(mp * 2.1 + vec2(t * 0.03, 3.1))
                    + 0.15 * vnoise(mp * 4.3 - vec2(t * 0.05, 0.0));
            float dens = smoothstep(0.25, 0.75, n) * h;
            dens *= mix(0.35, 1.0, smoothstep(0.2 * R, 0.6 * R, p.x));   // thinner under the text on the left
            vec3 mistCol = vec3(0.30, 0.33, 0.42) * 0.55 + warm * min(G, 1.6) * 0.75 * SPILL;
            col = mix(col, mistCol, dens * MIST);
        }
    }

    col = mix(base.rgb, col, INTENSITY);
    fragColor = vec4(col, base.a);
}
