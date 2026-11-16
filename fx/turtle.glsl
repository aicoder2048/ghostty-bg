// turtle — a big green sea turtle glides across in three-quarter view, flippers flying slowly.
// zh: 海龟
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float OPACITY   = 0.80;   // how solid the turtle is; below 1 so text behind still shows
const float WIDTH     = 0.38;   // shell length as a fraction of the window width
const float HEIGHT    = 0.34;   // where it swims, in window heights from the bottom
const float CROSS     = 22.0;   // seconds one crossing takes
const float GAP       = 1.0;    // seconds of open water before it comes back the other way
const float STROKE    = 4.6;    // seconds per flipper stroke (power stroke + recovery)
const float BUBBLES   = 5.5;    // seconds between two little puffs of bubbles

float gAspect, gSize;           // window aspect and turtle size (half shell length)

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 v) { return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453); }
vec2 dir2(float a) { return vec2(cos(a), sin(a)); }
mat2 rot(float a) { return mat2(cos(a), sin(a), -sin(a), cos(a)); }   // CCW by a

// Distance to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

float tube(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 s = segment(p, a, b);
    return s.x - mix(ra, rb, s.y);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Hexagonal cells without a loop: (distance to the cell edge, cell id).
vec3 hexCell(vec2 p) {
    const vec2 s = vec2(1.0, 1.7320508);
    vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
    vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
    vec4 r = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy) : vec4(h.zw, hc.zw + 0.5);
    vec2 a = abs(r.xy);
    return vec3(0.5 - max(dot(a, vec2(0.5, 0.8660254)), a.x), r.zw);
}

// Turtle skin: dark brown scales with pale yellow seams between them, as on a
// green turtle's head and flippers. pxs is one pixel in scale units.
vec3 scaleSkin(vec2 sp, float pxs, vec3 dark, vec3 light) {
    sp += 0.22 * vec2(sin(sp.y * 1.3 + sin(sp.x * 0.7)), sin(sp.x * 1.5 + sin(sp.y * 0.9)));   // irregular, not a grid
    vec3 h = hexCell(sp);
    float r = hash2(h.yz);
    vec3 scale = mix(dark, dark * 1.45, r);
    scale *= 0.85 + 0.3 * smoothstep(0.0, 0.4, h.x);         // each scale slightly domed
    return mix(light, scale, smoothstep(0.03, 0.03 + max(0.06, 1.5 * pxs), h.x));
}

// Moving underwater light: bright wavy lines where a sum of drifting waves is zero.
float caustic(vec2 p, float t) {
    vec2 c = p * 20.0;
    c += 0.7 * vec2(sin(c.y * 0.8 + t * 0.7), sin(c.x * 0.9 - t * 0.6));
    float v = sin(c.x + t * 0.5) + sin(c.y * 1.2 - t * 0.4) + sin((c.x - c.y) * 0.7 + t * 0.3);
    return smoothstep(0.6, 0.0, abs(v));
}

// Where the turtle is at time t: (x, y, facing +-1, pitch). Also the stroke phase.
vec4 pose(float t, out float phase) {
    float period = CROSS + GAP;
    float clock = t + 0.33 * CROSS;                 // already well inside at the start
    float cyc = floor(clock / period);
    float ct = clock - cyc * period;
    float face = mod(cyc, 2.0) < 0.5 ? 1.0 : -1.0;  // alternate sides, mirrored
    phase = fract(t / STROKE);
    float w = 6.2831853 * phase;
    float margin = 1.7 * gSize;
    // Each power stroke gives a small surge forward and a lift; the nose follows.
    float x = mix(-margin, gAspect + margin, ct / CROSS) - 0.08 * gSize * cos(w);
    if (face < 0.0) x = gAspect - x;
    float y = HEIGHT + 0.035 * sin(clock * 0.23 + cyc * 1.7) - 0.05 * gSize * cos(w);
    float pitch = 0.05 * sin(w) + 0.06 * cos(clock * 0.23 + cyc * 1.7);
    return vec4(x, y, face, pitch);
}

float headAngle(float t) {
    return 0.05 * sin(t * 0.41) + 0.03 * sin(6.2831853 * fract(t / STROKE) + 2.0);
}

// A flipper blade from root along angle ang; the tip turns by bend (CCW +).
// Returns (signed distance, 0..1 along, -1..1 across, y of the outward normal).
vec4 flipper(vec2 q, vec2 root, float ang, float bend, float len, float wid) {
    vec2 mid = root + 0.45 * len * dir2(ang + 0.25 * bend);
    vec2 tip = mid + 0.55 * len * dir2(ang + bend);
    vec2 s1 = segment(q, root, mid), s2 = segment(q, mid, tip);
    bool first = s1.x < s2.x;
    vec2 a = first ? root : mid, b = first ? mid : tip;
    float T = first ? 0.45 * s1.y : 0.45 + 0.55 * s2.y;
    float dd = min(s1.x, s2.x);
    vec2 dv = normalize(b - a);
    vec2 ln = vec2(-dv.y, dv.x);
    float side = dot(q - a, ln) >= 0.0 ? 1.0 : -1.0;
    vec2 n = ln * side;
    // Long and narrow, widest a little before the middle, pointed tip; the
    // rear-facing (trailing) edge is fuller than the straight leading edge.
    float prof = (0.5 + 2.2 * T) * pow(1.0 - T, 0.85);
    float w = wid * prof * (1.0 + 0.25 * clamp(-n.x * 2.0, -1.0, 1.0)) + 0.008;
    return vec4(dd - w, T, side * dd / w, n.y);
}

// Premultiplied "over": put a layer of colour c with coverage ca on top.
void over(inout vec4 acc, vec3 c, float ca) {
    acc = vec4(c * ca, ca) + acc * (1.0 - ca);
}

// Colour a flipper layer. shade < 1 for the far side (in shadow, behind the body).
void drawFlipper(inout vec4 acc, vec2 q, vec4 f, float len, float wid, float aa,
                 float px, float shade, float cs, float fade) {
    if (f.x > aa) return;
    float cov = smoothstep(aa, -aa, f.x) * fade;
    if (cov <= 0.0) return;
    float dens = 15.0;
    vec2 sp = vec2(f.y * len, f.z * wid * (0.6 + 1.4 * (1.0 - f.y))) * dens;
    vec3 c = scaleSkin(sp, px * dens, vec3(0.30, 0.25, 0.14), vec3(0.66, 0.62, 0.42));
    float rim = smoothstep(-0.035, 0.0, f.x);                 // pale margin all round
    c = mix(c, vec3(0.90, 0.84, 0.62), rim * 0.75);
    c *= (0.8 + 0.35 * f.w) * shade;                          // upper edge catches light
    c += cs * vec3(0.55, 0.90, 0.85) * 0.35 * shade;
    over(acc, c, cov);
}

// Colour of one shell plate: amber/olive with dark streaks radiating from its
// growth centre, a lighter border and a thin dark seam.
vec3 plate(vec2 lp, vec2 org, float id, float seamD, float px) {
    float h = hash1(id * 7.31 + 1.7);
    vec3 c = mix(vec3(0.80, 0.54, 0.24), vec3(0.58, 0.55, 0.27), h);
    vec2 d = lp - org;
    float ang = atan(d.y, d.x);
    float rr = length(d);
    float st = sin(ang * 9.0 + h * 20.0 + 1.4 * sin(ang * 4.0 + h * 9.0) + rr * 2.0);
    st = smoothstep(0.0, 0.9, st) * smoothstep(0.05, 0.45, rr);
    c = mix(c, vec3(0.30, 0.17, 0.08), 0.6 * st);
    float fl = sin(ang * 5.0 + h * 13.0) * sin(rr * 9.0 - h * 5.0);
    c = mix(c, vec3(0.95, 0.72, 0.32), 0.35 * smoothstep(0.45, 0.9, fl));   // golden flecks
    c = mix(c, vec3(0.96, 0.86, 0.60), 0.55 * smoothstep(0.08, 0.015, seamD));
    c = mix(c, vec3(0.20, 0.12, 0.06), 0.85 * smoothstep(0.007 + px, 0.004, seamD));
    return c;
}

// The carapace as seen from the side and a little above. x along the body
// (-1 tail, +1 head), vn from the near lower rim (0) to the top ridge (1).
vec3 shellColor(vec2 q, float vn, float hgt, float px) {
    float x = q.x;
    float seamD;
    vec2 lp, org;
    float id;
    float vb = 0.64 + 0.03 * sin(x * 9.0);                    // vertebral / costal border
    if (vn < 0.22 || abs(x) > 0.9) {
        // Marginal plates: a ring of small plates along the rim.
        float u = (x + 1.0) / 0.17 + 0.6 * vn;
        float cell = floor(u);
        float lx = fract(u) - 0.5;
        seamD = min((0.5 - abs(lx)) * 0.17, max(0.22 - vn, 0.0) * hgt + step(0.9, abs(x)));
        lp = vec2(lx * 2.0, vn / 0.22);
        org = vec2(0.0, 0.9);
        id = cell + 40.0;
    } else if (vn < vb) {
        // Four costal plates, the front one largest; seams fan out a little.
        // Seams bow a little and fan out, as the plates wrap round the dome.
        float f = 1.0 + 0.15 * (vn - 0.4);
        float bow = 0.06 * sin(3.14159 * (vn - 0.22) / 0.42);
        float b0 = 0.30 * f + bow, b1 = -0.15 * f + bow * 0.6, b2 = -0.55 * f - bow * 0.3;
        float lo = -0.9, hi = 0.9;
        id = 0.0;
        if (x > b0) { lo = b0; id = 1.0; }
        else if (x > b1) { lo = b1; hi = b0; id = 2.0; }
        else if (x > b2) { lo = b2; hi = b1; id = 3.0; }
        else { hi = b2; id = 4.0; }
        seamD = min(min(abs(x - b0), abs(x - b1)), abs(x - b2));
        seamD = min(seamD, min(vn - 0.22, vb - vn) * hgt);
        lp = vec2((x - 0.5 * (lo + hi)) / (0.5 * (hi - lo)), (vn - 0.22) / (vb - 0.22));
        org = vec2(-0.3, 0.85);
    } else {
        // Five vertebral plates down the middle of the back.
        float lo = -0.95, hi = 0.9;
        id = 10.0;
        x -= 0.05 * sin(3.14159 * (vn - vb) / (1.0 - vb));   // gently curved seams
        if (x > 0.55) { lo = 0.55; id = 11.0; }
        else if (x > 0.08) { lo = 0.08; hi = 0.55; id = 12.0; }
        else if (x > -0.36) { lo = -0.36; hi = 0.08; id = 13.0; }
        else if (x > -0.72) { lo = -0.72; hi = -0.36; id = 14.0; }
        else { hi = -0.72; id = 15.0; }
        seamD = min(min(abs(x - 0.55), abs(x - 0.08)), min(abs(x + 0.36), abs(x + 0.72)));
        seamD = min(seamD, (vn - vb) * hgt);
        lp = vec2((x - 0.5 * (lo + hi)) / (0.5 * (hi - lo)), (vn - vb) / (1.0 - vb));
        org = vec2(-0.25, 0.4);
    }
    return plate(lp, org, id, seamD, px);
}

vec4 drawTurtle(vec2 q, float ph, float t, vec2 wp, float px) {
    float aa = 1.2 * px;
    float cs = caustic(wp, t);
    vec4 acc = vec4(0.0);

    // Front flipper stroke: a strong down-and-back power stroke, then a slower,
    // feathered (edge-on, so narrower) recovery up and forward.
    float s, v, feather = 1.0;
    if (ph < 0.45) {
        float u = ph / 0.45;
        s = u * u * (3.0 - 2.0 * u);
        v = 6.0 * u * (1.0 - u) / 0.45;
    } else {
        float u = (ph - 0.45) / 0.55;
        s = 1.0 - u * u * (3.0 - 2.0 * u);
        v = -6.0 * u * (1.0 - u) / 0.55;
        feather = 1.0 - 0.45 * sin(3.14159 * u);
    }
    float th = mix(2.45, 3.9, s);
    // Swept back, and the tip lags behind the way the flipper moves.
    float bend = 0.30 * sin(3.14159 - th) - 0.06 * 1.75 * v;
    float w = 6.2831853 * ph;

    // Far side first (darker, mostly hidden behind the shell).
    vec2 rrF = vec2(-0.76, 0.04);
    vec4 f = flipper(q, rrF, 3.3 + 0.18 * sin(w + 2.0), 0.15, 0.42, 0.13);
    drawFlipper(acc, q, f, 0.42, 0.13, aa, px, 0.55, cs, 1.0);
    f = flipper(q, vec2(0.52, 0.16), th + 0.10, bend, 1.12, 0.14 * feather);
    drawFlipper(acc, q, f, 1.12, 0.14, aa, px, 0.55, cs, 1.0);

    // Near rear flipper: a rounded paddle that steers.
    f = flipper(q, vec2(-0.72, -0.14), 3.55 + 0.18 * sin(w + 1.2), 0.2, 0.50, 0.16);
    drawFlipper(acc, q, f, 0.50, 0.16, aa, px, 0.95, cs, 1.0);

    // Shell outline: domed top, flatter bottom rim.
    float w2 = max(1.0 - q.x * q.x, 1e-3);
    float pw = pow(w2, 0.6);
    float yT = 0.04 + 0.50 * pw * (1.0 + 0.08 * q.x);
    float yB = -0.06 - 0.15 * sqrt(w2);
    float slT = -0.6 * q.x * pw / w2 * (1.0 + 0.08 * q.x) + 0.04 * pw;
    float slB = 0.15 * q.x / sqrt(w2);
    float dS = max(max((q.y - yT) / sqrt(1.0 + slT * slT), (yB - q.y) / sqrt(1.0 + slB * slB)),
                   abs(q.x) - 1.0);

    // Pale plastron (belly plate) showing under the rim.
    float xp = q.x / 0.8;
    float yP = yB - 0.11 * pow(max(1.0 - xp * xp, 0.0), 0.6);
    float dP = max(max(yP - q.y, q.y - yB - 0.03), abs(q.x) - 0.8);
    if (dP < aa) {
        vec3 c = vec3(0.92, 0.84, 0.58) * (0.65 + 0.35 * smoothstep(yP, yB, q.y));
        c *= 1.0 - 0.25 * smoothstep(0.012, 0.0, abs(fract(q.x * 3.2 + 0.3) - 0.5) * 0.31);
        over(acc, c, smoothstep(aa, -aa, dP));
    }

    // Head and neck, coming out from under the front of the shell.
    float ha = headAngle(t);
    vec2 hq = rot(-ha) * (q - vec2(0.86, -0.02)) / 1.15;   // head drawn 15% larger
    float hpx = px / 1.15;
    float neck = tube(hq, vec2(-0.22, -0.01), vec2(0.20, 0.01), 0.15, 0.135);
    vec2 e = vec2((hq.x - 0.38) / 0.26, (hq.y - 0.02) / (hq.y > 0.02 ? 0.165 : 0.135));
    float dH = smin(neck, (length(e) - 1.0) * 0.15, 0.06);
    if (dH < aa) {
        float m = smoothstep(0.14, 0.24, hq.x);              // neck -> head
        vec3 big = scaleSkin(hq * 9.0, px * 9.0, vec3(0.30, 0.22, 0.12), vec3(0.88, 0.80, 0.52));
        vec3 small = scaleSkin(hq * 20.0, px * 20.0, vec3(0.42, 0.40, 0.26), vec3(0.70, 0.68, 0.50));
        small *= 1.0 - 0.2 * smoothstep(0.3, 1.0, sin(hq.x * 45.0));     // neck folds
        vec3 c = mix(small, big, m);
        // Pale chin and throat.
        float pale = smoothstep(-0.03, -0.11, hq.y - 0.12 * (hq.x - 0.3));
        c = mix(c, vec3(0.86, 0.80, 0.58), pale * 0.8);
        // Horny beak with its cutting edge, and the mouth line.
        float beak = smoothstep(0.52, 0.57, hq.x) * smoothstep(0.02, -0.02, hq.y);
        c = mix(c, vec3(0.78, 0.70, 0.46), beak);
        float dx = 0.63 - hq.x;
        float my = -0.03 - 0.30 * dx + 0.40 * dx * dx;
        float mouth = smoothstep(0.010 + px, 0.003, abs(hq.y - my)) * step(0.0, dx) * smoothstep(0.34, 0.20, dx);
        c = mix(c, vec3(0.12, 0.08, 0.05), mouth * 0.9);
        // Eye: a dark lid ring, a dark brown eye and a bright catchlight.
        vec2 ec = hq - vec2(0.42, 0.055);
        float er = length(ec);
        c = mix(c, vec3(0.24, 0.17, 0.10), smoothstep(0.074 + hpx, 0.068, er));
        c = mix(c, vec3(0.70, 0.62, 0.42), 0.6 * smoothstep(0.008, 0.0, abs(er - 0.066)) * step(0.0, ec.y));
        vec3 eye = mix(vec3(0.05, 0.035, 0.02), vec3(0.42, 0.26, 0.10), smoothstep(0.026, 0.047, er));
        c = mix(c, eye, smoothstep(0.053 + hpx, 0.050, er));
        c = mix(c, vec3(1.0), smoothstep(0.015 + hpx, 0.011, length(ec - vec2(0.014, 0.020))));
        c = mix(c, vec3(0.9), 0.7 * smoothstep(0.007 + hpx, 0.004, length(ec - vec2(-0.017, -0.016))));
        // Nostril.
        c = mix(c, vec3(0.08, 0.05, 0.03), smoothstep(0.012 + px, 0.008, length(hq - vec2(0.615, 0.07))));
        // Light from above, a darker outline for shape.
        c *= 0.75 + 0.45 * smoothstep(-0.14, 0.16, hq.y);
        c *= 1.0 - 0.35 * smoothstep(-0.02, 0.0, dH);
        c += cs * vec3(0.55, 0.90, 0.85) * 0.35 * smoothstep(-0.1, 0.15, hq.y);
        over(acc, c, smoothstep(aa, -aa, dH));
    }

    // The carapace.
    if (dS < aa) {
        float hgt = yT - yB;
        float vn = clamp((q.y - yB) / hgt, 0.0, 1.0);
        vec3 c = shellColor(q, vn, hgt, px);
        // Dome lighting: lit from above, a soft sheen near the ridge, shadow at the rim.
        c *= (0.62 + 0.55 * vn) * (0.85 + 0.15 * sqrt(w2));
        c += vec3(1.0, 0.92, 0.75) * 0.22 * exp(-pow((vn - 0.82) / 0.1, 2.0));
        c *= 1.0 - 0.3 * smoothstep(0.10, 0.0, q.y - yB);
        // The lit top edge where the shell curves away from the light.
        c = mix(c, vec3(1.0, 0.95, 0.80), 0.55 * smoothstep(-0.05, -0.005, dS) * smoothstep(-0.1, 0.1, q.y));
        c = mix(c, vec3(0.18, 0.11, 0.05), 0.5 * smoothstep(-0.012, 0.0, dS) * step(q.y, 0.0));
        c += cs * vec3(0.60, 0.95, 0.85) * (0.15 + 0.4 * vn);
        over(acc, c, smoothstep(aa, -aa, dS));
    }

    // A remora riding under the belly, its tail flicking now and then.
    vec2 rq = q - vec2(0.08, -0.36);
    if (abs(rq.y) < 0.15 && rq.x > -0.75 && rq.x < 0.1) {
        float wag = 0.04 * sin(t * 2.3) * smoothstep(-0.3, -0.55, rq.x);
        vec2 r2 = rq - vec2(0.0, wag - 0.05 * min(rq.x, 0.0));
        float dr = tube(r2, vec2(0.0, 0.0), vec2(-0.40, 0.0), 0.058, 0.022);
        dr = min(dr, tube(r2, vec2(-0.40, 0.0), vec2(-0.50, 0.055), 0.018, 0.006));   // forked tail
        dr = min(dr, tube(r2, vec2(-0.40, 0.0), vec2(-0.50, -0.055), 0.018, 0.006));
        if (dr < aa) {
            vec3 c = mix(vec3(0.62, 0.62, 0.58), vec3(0.30, 0.31, 0.34), smoothstep(-0.03, 0.03, r2.y));
            c = mix(c, vec3(0.16, 0.16, 0.20), 0.8 * smoothstep(0.010, 0.004, abs(r2.y + 0.004)) * step(-0.40, r2.x));
            c = mix(c, vec3(0.05), smoothstep(0.011 + px, 0.007, length(r2 - vec2(-0.025, 0.012))));
            over(acc, c * 0.9, smoothstep(aa, -aa, dr) * 0.95);
        }
    }

    // Near front flipper last: it sweeps in front of the shell. Its root is
    // tucked under the rim, so let the shell hide the first part of it.
    f = flipper(q, vec2(0.60, -0.10), th, bend, 1.30, 0.17 * feather);
    float tuck = dS < 0.0 ? smoothstep(0.06, 0.16, f.y) : 1.0;
    drawFlipper(acc, q, f, 1.30, 0.17, aa, px, 1.0 - 0.15 * (1.0 - feather), cs, tuck);

    vec3 col = acc.a > 1e-4 ? acc.rgb / acc.a : vec3(0.0);
    col = col * vec3(0.88, 1.0, 1.03) + vec3(0.0, 0.015, 0.025);      // a touch of sea colour
    return vec4(col, acc.a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    gAspect = aspect;
    gSize = min(0.5 * WIDTH * aspect, 0.42);        // cap so a very wide window stays sane

    vec3 rgb = base.rgb;
    float ph;
    vec4 ps = pose(iTime, ph);
    vec2 q = (p - ps.xy) / gSize;
    q.x *= ps.z;                                    // face the way it swims
    q = rot(-ps.w) * q;

    // Keep the top-left (where the shell prompt and text live) a bit lighter.
    float guard = 1.0 - 0.35 * smoothstep(0.55, 0.85, p.y) * (1.0 - smoothstep(0.35, 0.65, uv.x));

    // Bounding box: pixels away from the turtle skip all the drawing.
    if (q.x > -1.75 && q.x < 1.85 && q.y > -1.05 && q.y < 1.5) {
        float px = 1.0 / (iResolution.y * gSize);   // one pixel in turtle units
        vec4 c = drawTurtle(q, ph, iTime, p, px);
        rgb = mix(rgb, c.rgb, c.a * OPACITY * INTENSITY * guard);
    }

    // Now and then a few bubbles leave the nostrils and wobble up to the surface.
    float pxw = 1.0 / iResolution.y;
    for (int k = 0; k < 8; k++) {
        float fk = mod(float(k), 4.0);
        float puff = floor((iTime - 1.0) / BUBBLES) - floor(float(k) / 4.0);
        if (puff < 0.0) continue;
        float h = hash1(puff * 4.0 + fk + 0.5);
        float te = 1.0 + puff * BUBBLES + fk * 0.22 + 0.08 * h;
        float age = iTime - te;
        if (age < 0.0 || age > 3.4) continue;
        float ph2;
        vec4 ps2 = pose(te, ph2);
        vec2 nos = vec2(0.86, -0.02) + rot(headAngle(te)) * vec2(0.615, 0.07) * 1.15;
        vec2 bp = ps2.xy + gSize * vec2(ps2.z, 1.0) * (rot(ps2.w) * nos);
        bp += vec2(ps2.z * 0.03 * (1.0 - exp(-2.0 * age)) + 0.008 * sin(age * 7.0 + fk * 2.0),
                   0.04 * age + 0.035 * age * age);
        float r = gSize * (0.022 + 0.016 * h) * (1.0 + 0.25 * age);
        float d = length(p - bp);
        if (d > r * 1.3) continue;
        float ring = 1.0 - smoothstep(0.0, r * 0.16 + pxw, abs(d - r * 0.85));
        float fill = 0.15 * smoothstep(r, r * 0.8, d);
        float hl = smoothstep(r * 0.28, r * 0.1, length(p - bp - vec2(-0.3, 0.35) * r));
        float fade = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(2.7, 3.4, age));
        rgb = mix(rgb, vec3(0.85, 0.97, 1.0), clamp(0.7 * ring + fill + 0.9 * hl, 0.0, 1.0) * fade * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
