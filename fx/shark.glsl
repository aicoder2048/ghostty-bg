// shark — a great white shark glides past in side view, tail sweeping, sunlight dappling its back.
// zh: 鲨鱼
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float WIDTH     = 0.40;   // shark length (snout to tail tip) as a fraction of the window width
const float DEPTH_Y   = 0.30;   // cruising height of the shark's centre line (0 = bottom, 1 = top)
const float CROSS     = 20.0;   // seconds to cross the window
const float GAP       = 3.0;    // seconds off-screen before it comes back the other way
const float BEAT      = 2.3;    // seconds per tail stroke (left-right-left)
const float OPACITY   = 0.88;   // body opacity; just below 1 so it still sits in the scene
const float DAPPLE    = 0.07;   // sunlight dapples on the back (keep subtle)

const float PI = 3.14159265;

// Exact signed distance to a triangle (Inigo Quilez).
float sdTri(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// A shark fin: triangle with root A (leading) - B (trailing) and tip T. Pushing
// the middle of the fin forward gives the convex leading edge and the hollow
// (falcate) trailing edge that real shark fins have.
float fin(vec2 q, vec2 A, vec2 B, vec2 T, float bow) {
    vec2 M = 0.5 * (A + B), mt = T - M;
    float h = clamp(dot(q - M, mt) / dot(mt, mt), 0.0, 1.0);
    q -= normalize(A - B) * bow * 4.0 * h * (1.0 - h);
    return sdTri(q, A, B, T);
}

// ---- Body profile ------------------------------------------------------
// Units: total length = 1, snout at x = +0.5, tail tips at x = -0.5, facing +x.
// s = 0 at the snout, 1 at the tail. Great-white proportions: conical snout,
// deepest around a third of the way back, long taper to a slim tail stock.
float topY(float s) {
    float u = clamp(s / 0.34, 0.0, 1.0);
    float y = 0.007 + 0.112 * (1.0 - (1.0 - u) * (1.0 - u));
    return mix(y, 0.021, smoothstep(0.34, 0.85, s));
}
float botY(float s) {
    float u = clamp(s / 0.42, 0.0, 1.0);
    float y = 0.003 - 0.114 * (1.0 - pow(1.0 - u, 1.8));
    return mix(y, -0.019, smoothstep(0.42, 0.85, s));
}

// White belly below this line: an irregular boundary that runs below the eye,
// pushes up into the gill area, dips past the pectoral fin and rises at the tail.
float lineFrac(float s) {
    float f = 0.36 + 0.10 * exp(-pow((s - 0.20) / 0.05, 2.0))
            - 0.06 * smoothstep(0.24, 0.34, s) + 0.14 * smoothstep(0.55, 0.85, s);
    f += 0.022 * sin(s * 47.0 + 1.0) + 0.014 * sin(s * 103.0 + 2.3) + 0.010 * sin(s * 211.0);
    return f;
}

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// Pectoral fin, rowing a little about its root.
float pectoral(vec2 q, float row) {
    vec2 A = vec2(0.270, -0.045);
    vec2 r = q - A;
    float c = cos(row), sn = sin(row);
    r = vec2(c * r.x - sn * r.y, sn * r.x + c * r.y) + A;
    return fin(r, A, vec2(0.150, -0.080), vec2(0.098, -0.188), 0.026) - 0.004;
}

// Crisp sunlight pattern from the wavy surface, in world coordinates so it stays
// in the water while the shark slides beneath it.
float dapple(vec2 p, float t) {
    // Blotches (not thin lines) read as light patches rather than scratches.
    vec2 q = p * 75.0;
    vec2 w = q + 0.9 * vec2(sin(q.y * 0.45 + t * 0.8), sin(q.x * 0.40 - t * 0.6));
    float v = sin(w.x) * sin(w.y + 0.5 * w.x);
    float m = 0.5 + 0.5 * sin(p.x * 9.0 + p.y * 5.0 - t * 0.3);   // patchy, not uniform
    return smoothstep(0.55, 0.75, v) * m;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec3 rgb = base.rgb;

    // ---- Path: steady glide across, alternating direction, gentle depth changes.
    float L = min(WIDTH * aspect, 0.80);                  // body length in window heights
    float period = CROSS + GAP;
    float clock = iTime + 0.27 * CROSS;                   // already in view at start
    float n = floor(clock / period);
    float tc = (clock - n * period) / CROSS;              // 0..1 while crossing, >1 in the gap
    float dir = mod(n, 2.0) < 0.5 ? 1.0 : -1.0;
    float margin = 0.55 * L;
    float speed = (aspect + 2.0 * margin) / CROSS;
    float x = -margin + tc * (aspect + 2.0 * margin);
    if (dir < 0.0) x = aspect - x;
    float w = clock * 0.21 + n * 1.7;
    float y = DEPTH_Y + 0.035 * sin(w);
    float pitch = atan(0.035 * 0.21 * cos(w), speed);     // nose follows the climb
    pitch += 0.012 * sin(clock * 0.53);

    if (tc < 1.0) {
        vec2 q = (p - vec2(x, y)) / L;
        q.x *= dir;                                       // face the way it swims
        float cp = cos(pitch), sp = sin(pitch);
        q = vec2(cp * q.x + sp * q.y, -sp * q.x + cp * q.y);

        // Bounding box early-out: only pixels near the shark pay for it.
        if (q.x > -0.56 && q.x < 0.53 && q.y > -0.26 && q.y < 0.28) {
            float px = 1.0 / (iResolution.y * L);         // one pixel in body units
            float ph = 2.0 * PI * clock / BEAT;

            // Swimming, seen from the side: a wave runs down the rear body (a
            // slight flex), and the tail fin foreshortens as it sweeps out of the
            // picture plane and back, catching the light on one side then the other.
            float s0 = clamp(0.5 - q.x, 0.0, 1.0);
            float flex = smoothstep(0.45, 1.0, s0);
            q.y -= 0.012 * flex * flex * sin(ph - 5.0 * s0);
            float sweep = sin(ph - 4.0);
            float fs = 1.0 - 0.22 * sweep * sweep;
            const float XR = -0.335;                      // tail fin root
            vec2 qt = q;
            if (q.x < XR) qt.x = XR + (q.x - XR) / fs;
            float row = 0.05 * sin(clock * 0.6);

            float s = clamp(0.5 - q.x, 0.0, 1.0);
            float t = topY(s), b = botY(s);
            float e = 0.003;
            float st = (topY(s + e) - topY(s - e)) / (2.0 * e);
            float sb = (botY(s + e) - botY(s - e)) / (2.0 * e);
            float dBody = max((q.y - t) * inversesqrt(1.0 + st * st),
                              (b - q.y) * inversesqrt(1.0 + sb * sb));
            dBody = max(dBody, max(q.x - 0.5, -0.42 - q.x));

            float dDors = fin(q, vec2(0.205, 0.100), vec2(0.050, 0.098), vec2(0.100, 0.236), 0.018) - 0.003;
            float dSmall = fin(q, vec2(-0.185, 0.034), vec2(-0.232, 0.028), vec2(-0.240, 0.068), 0.004) - 0.002;   // 2nd dorsal
            dSmall = min(dSmall, fin(q, vec2(-0.200, -0.032), vec2(-0.248, -0.025), vec2(-0.255, -0.062), 0.004) - 0.002); // anal
            dSmall = min(dSmall, fin(q, vec2(-0.055, -0.072), vec2(-0.115, -0.060), vec2(-0.130, -0.118), 0.006) - 0.002); // pelvic
            float up = fin(qt, vec2(-0.315, 0.026), vec2(-0.425, -0.004), vec2(-0.495, 0.192), 0.024) - 0.003;
            float lo = fin(qt, vec2(-0.320, -0.020), vec2(-0.425, 0.004), vec2(-0.478, -0.158), 0.020) - 0.003;
            float dTail = min(up, lo) * fs;

            float dSil = smin(dBody, dDors, 0.012);
            dSil = smin(dSil, dSmall, 0.008);
            dSil = smin(dSil, dTail, 0.012);

            float dPec = pectoral(q, row);
            float dFar = pectoral(q - vec2(-0.025, 0.010), row * 0.7 + 0.06);

            vec3 GREY  = vec3(0.37, 0.41, 0.45);          // slate back
            vec3 WHITE = vec3(0.90, 0.91, 0.90);          // belly
            vec4 acc = vec4(0.0);

            // Far pectoral fin, in shadow; only its tip peeks out below the body.
            float kFar = smoothstep(px, -px, dFar);
            if (kFar > 0.0) over(acc, GREY * 0.50, kFar);

            float kSil = smoothstep(px, -px, dSil);
            if (kSil > 0.0) {
                float v = clamp((q.y - b) / max(t - b, 1e-3), 0.0, 1.0);   // 0 belly .. 1 back
                float ny = 2.0 * v - 1.0;                                  // rough up-facing normal
                bool tail = q.x < XR - 0.01;
                float lineY = b + (t - b) * lineFrac(s);
                float belly = tail ? 0.0 : smoothstep(-px, px, lineY - q.y);
                if (q.y > t) belly = 0.0;                                   // dorsal fins
                if (q.y < b && !tail) belly = 0.85;                         // pelvic / anal fins

                // Faint mottling so the grey isn't a flat fill.
                float mott = 0.04 * sin(q.x * 90.0 + sin(q.y * 70.0) * 2.0) * sin(q.y * 60.0 + q.x * 30.0);
                vec3 grey = GREY * (1.0 + mott);

                // Light from above: back brightest, belly shading into its own shadow.
                float lg = 0.80 + 0.22 * ny;
                float lw = 0.80 + 0.20 * ny;
                lw *= 1.0 - 0.22 * pow(max(-ny, 0.0), 3.0);
                vec3 col = mix(grey * lg, WHITE * lw, belly);

                // A soft sheen along the upper flank.
                col += vec3(0.07, 0.08, 0.09) * exp(-pow((v - 0.74) / 0.08, 2.0)) * (1.0 - belly) * step(q.y, t);

                // Fins: darker toward their tips and trailing margins.
                if (q.y > t && q.x > -0.3) col = grey * mix(1.02, 0.80, smoothstep(t, 0.236, q.y));
                if (tail) {
                    float lit = 0.92 + 0.10 * sin(ph - 4.6);             // one face, then the other
                    col = grey * 0.86 * lit * mix(1.0, 0.80, smoothstep(-0.38, -0.50, qt.x));
                }

                // Caudal keel: a fine ridge along the tail stock.
                if (s > 0.74 && s < 0.86) {
                    float kd = q.y - 0.001;
                    float kf = smoothstep(0.74, 0.78, s) * smoothstep(0.86, 0.82, s);
                    col *= 1.0 + kf * (0.08 * smoothstep(1.5 * px, 0.0, abs(kd - 0.002)) - 0.08 * smoothstep(1.5 * px, 0.0, abs(kd + 0.003)));
                }

                // Shadow cast by the near pectoral fin onto the flank below it.
                col *= 1.0 - 0.18 * smoothstep(0.012, -0.004, pectoral(q + vec2(0.006, 0.014), row));

                // Five gill slits, gently curved, longer toward the back.
                float gill = 0.0, lip = 0.0;
                for (int k = 0; k < 5; k++) {
                    float fk = float(k);
                    vec2 g = q - vec2(0.326 - 0.021 * fk, -0.008);
                    g.x += 2.2 * g.y * g.y - 0.12 * g.y;
                    float hl = 0.030 + 0.004 * fk;
                    float lenK = smoothstep(hl, hl - 0.006, abs(g.y));
                    gill = max(gill, smoothstep(px, -px, abs(g.x) - max(0.0015, 0.5 * px)) * lenK);
                    lip = max(lip, smoothstep(px, -px, abs(g.x + 0.0045) - max(0.0012, 0.4 * px)) * lenK);
                }
                col *= 1.0 + 0.14 * lip;
                col = mix(col, col * 0.50, gill * 0.6);

                // Mouth line under the snout, curving up a little at the corner.
                float mu = clamp((s - 0.04) / 0.115, 0.0, 1.0);
                float my = b + 0.004 + 0.020 * pow(mu, 2.5);
                float mouth = smoothstep(px, -px, abs(q.y - my) - max(0.0016, 0.5 * px))
                            * smoothstep(0.035, 0.05, s) * smoothstep(0.162, 0.150, s);
                col = mix(col, col * 0.40, mouth * 0.8);

                // Sunlight dapples on the back, crisp but faint.
                float dap = dapple(p, iTime) * smoothstep(0.55, 0.85, v) * (1.0 - belly);
                col += vec3(0.85, 0.92, 0.95) * dap * DAPPLE;

                // Eye: black, round, with a tiny highlight.
                vec2 ev = q - vec2(0.412, 0.023);
                float eye = smoothstep(px, -px, length(ev) - 0.0085);
                col = mix(col, vec3(0.02, 0.025, 0.03), eye);
                float glint = smoothstep(px, -px, length(ev - vec2(0.0028, 0.0030)) - max(0.0022, 0.7 * px));
                col = mix(col, vec3(0.92, 0.95, 1.0), glint * eye * 0.9);

                over(acc, col, kSil);
            }

            // Near pectoral fin: grey top side, darker toward the tip, a fine lit
            // leading edge.
            float kPec = smoothstep(px, -px, dPec);
            if (kPec > 0.0) {
                float h = clamp(dot(q - vec2(0.21, -0.062), vec2(-0.112, -0.126)) / 0.0284, 0.0, 1.0);
                vec3 col = GREY * mix(0.98, 0.70, h);
                float le = segment(q, vec2(0.272, -0.043), vec2(0.104, -0.184));
                col *= 1.0 + 0.18 * smoothstep(0.008, 0.002, le);
                over(acc, col, kPec);
            }

            rgb = rgb * (1.0 - acc.a * OPACITY * INTENSITY) + acc.rgb * OPACITY * INTENSITY;
        }
    }

    fragColor = vec4(rgb, base.a);
}
