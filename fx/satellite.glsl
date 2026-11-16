// satellite — the International Space Station drifts slowly above Earth's night-side limb, sunlight glinting across its golden solar arrays.
// zh: 卫星
// group: space
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;    // overall strength (0 = off)
const float OPACITY   = 0.90;    // how much the station hides what is behind it
const float ISS_SIZE  = 0.0037;  // one metre of station in window heights (truss is 110 m)
const float SPIN      = 0.010;   // in-plane rotation speed, radians per second
const float GLINT     = 1.00;    // strength of the sun glints on arrays and modules
const float EARTH     = 0.90;    // brightness of the Earth's limb, day sliver and city lights
const float STARS     = 0.60;    // starfield brightness
const float PERSP     = 0.008;   // slight perspective, used only for reflections (moves glints)

const vec3 SUNC = vec3(1.00, 0.97, 0.92);   // sunlight colour
const vec3 AMB  = vec3(0.035, 0.05, 0.08);  // faint blue earthshine on the shadow side

// ---- Helpers ------------------------------------------------------------

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
               mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float sdBox(vec2 q, vec2 b) {
    vec2 d = abs(q) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Area coverage of a shape with signed distance d (aa = one pixel).
float cover(float d, float aa) { return clamp(0.5 - d / aa, 0.0, 1.0); }

// Exact pixel coverage of a straight line of half-width w at distance d, so
// hair-thin seams stay thin and crisp instead of shimmering.
float lineCov(float d, float w, float aa) {
    return max(min(d + 0.5 * aa, w) - max(d - 0.5 * aa, -w), 0.0) / aa;
}

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// Half vector between sun and a (very slightly perspective) view ray. The
// perspective is what lets a glint slide across a flat panel.
vec3 halfVec(vec2 q, vec3 L) {
    return normalize(L + normalize(vec3(-q * PERSP, 1.0)));
}

vec3 shade(vec3 n, vec3 L, vec3 H, vec3 kd, vec3 ks, float e) {
    float dif = max(dot(n, L), 0.0);
    float spe = pow(max(dot(n, H), 0.0), e);
    return kd * (AMB + SUNC * dif) + ks * SUNC * spe * GLINT;
}

// ---- The station ----------------------------------------------------------
// Local frame in metres: x along the main truss, y along the pressurised
// modules (forward is +y), z towards the viewer. Seen from below, near
// orthographic.

// Eight solar array wings: two columns at each end of the truss, every column
// one wing either side of it. Each wing is two blankets of cells on a mast.
void solarWings(inout vec4 acc, vec2 q, vec3 L, vec2 sp, float aa) {
    float ax = abs(q.x), ay = abs(q.y);
    if (ax < 28.4 || ax > 54.6 || ay < 2.6 || ay > 37.4) return;
    float sx = sign(q.x), sy = sign(q.y);
    float c  = ax < 41.5 ? 0.0 : 1.0;
    float cx = mix(34.7, 48.5, c);
    float u  = ax - cx;          // across the wing
    float v  = ay - 3.0;         // along the wing, from the truss outwards

    // The arrays are steered so their sun reflection lands on the point sp
    // (which wanders slowly); each column is aimed a little differently.
    vec2 colOff = (hash22(vec2(sx, c) * 7.3) - 0.5) * 10.0;
    vec3 n = halfVec(sp + colOff, L);

    // Blankets of cells, either side of the mast.
    float dB = sdBox(vec2(abs(u) - 3.15, v - 17.1), vec2(2.70, 16.2));
    float kB = cover(dB, aa);
    if (kB > 0.0) {
        float bu = abs(u) - 0.45, bv = v - 0.9;
        vec2 csz = vec2(5.40 / 4.0, 32.4 / 24.0);
        vec2 g = vec2(bu, bv) / csz;
        vec2 id = floor(g), f = fract(g);
        float ex = min(f.x, 1.0 - f.x) * csz.x;
        float ey = min(f.y, 1.0 - f.y) * csz.y;
        // Every sixth row is a fold hinge: a wider gap.
        float hinge = mod(floor(g.y + 0.5), 6.0) < 0.5 ? 0.16 : 0.06;
        float gap = max(lineCov(ex, 0.06, aa), lineCov(ey, hinge, aa));

        vec2 seed = id + vec2(sx * 13.0 + c * 5.0 + sign(u) * 2.0, sy * 31.0);
        vec2 hj = hash22(seed);
        // Each cell sits at a slightly different angle, so the glint breaks
        // up into a sparkle of individual cells rather than a smooth smear.
        vec3 nc = normalize(n + vec3((hj - 0.5) * 0.045, 0.0));
        vec2 qc = vec2(sx * (cx + sign(u) * (0.45 + (id.x + 0.5) * csz.x)),
                       sy * (3.9 + (id.y + 0.5) * csz.y));
        vec3 Hc = halfVec(qc, L);
        float dif = max(dot(n, L), 0.0);
        float hd  = max(dot(nc, Hc), 0.0);
        float spe = pow(hd, 1400.0) * 1.6 + pow(hd, 120.0) * 0.18;
        vec3 kd = vec3(0.36, 0.21, 0.07) * (0.82 + 0.36 * hash12(seed + 0.7));
        vec3 cell = kd * (AMB + SUNC * dif * 0.95)
                  + vec3(1.0, 0.80, 0.46) * SUNC * spe * GLINT;
        vec3 gapC = vec3(0.05, 0.045, 0.04) + vec3(0.30, 0.27, 0.22) * dif * 0.25;
        over(acc, mix(cell, gapC, gap), kB);
    }

    // Mast down the middle, and the stowage boxes at root and tip.
    float kM = cover(sdBox(vec2(u, v - 17.1), vec2(0.13, 16.6)), aa);
    float dif = max(dot(n, L), 0.0);
    over(acc, vec3(0.55, 0.55, 0.52) * (AMB + SUNC * dif), kM);
    float dBox = min(sdBox(vec2(u, v - 0.45), vec2(5.95, 0.42)),
                     sdBox(vec2(u, v - 33.75), vec2(5.95, 0.42)));
    vec3 boxC = shade(vec3(0.0, 0.0, 1.0), L, halfVec(q, L),
                      vec3(0.52, 0.52, 0.50), vec3(0.4), 60.0);
    over(acc, boxC, cover(dBox, aa));
}

// White heat-rejection radiators: three wide ones beside the centre of the
// truss on each side, and a smaller one inboard of each array pair.
void radiators(inout vec4 acc, vec2 q, vec3 L, float aa) {
    float ax = abs(q.x), sx = sign(q.x);
    vec3 H = halfVec(q, L);
    if (ax > 11.0 && ax < 22.2 && q.y < -2.0 && q.y > -26.6) {
        float k  = clamp(floor((ax - 11.2) / 3.6), 0.0, 2.0);
        float cr = 13.0 + k * 3.6;
        float u  = ax - cr, v = -q.y - 2.6;
        float d  = sdBox(vec2(u, v - 11.8), vec2(1.62, 11.8));
        float kc = cover(d, aa);
        if (kc > 0.0) {
            // Panels hinge at slightly different angles, so their brightness steps.
            vec3 n = normalize(vec3(sx * 0.18 * (k - 1.0), 0.10, 1.0));
            float pv = fract(v / 2.95);
            float seam = lineCov(min(pv, 1.0 - pv) * 2.95, 0.07, aa);
            float tube = 0.02 * step(0.5, fract(u * 2.5));
            vec3 kd = vec3(0.86, 0.87, 0.88) * (1.0 - tube);
            vec3 c = shade(n, L, H, kd, vec3(0.7), 90.0);
            over(acc, mix(c, c * 0.55, seam), kc);
        }
    }
    if (ax > 24.0 && ax < 27.6 && q.y > 2.0 && q.y < 16.0) {
        float d = sdBox(vec2(ax - 25.8, q.y - 9.0), vec2(1.45, 6.6));
        float pv = fract((q.y - 2.4) / 2.2);
        float seam = lineCov(min(pv, 1.0 - pv) * 2.2, 0.06, aa);
        vec3 n = normalize(vec3(-sx * 0.12, 0.0, 1.0));
        vec3 c = shade(n, L, H, vec3(0.84, 0.85, 0.86), vec3(0.6), 90.0);
        over(acc, mix(c, vec3(0.25), seam), cover(d, aa));
    }
}

// The integrated truss: an open lattice of rails and diagonal struts, with a
// solid centre segment and the two rotary joints that turn the arrays.
void truss(inout vec4 acc, vec2 q, vec3 L, float aa) {
    float ax = abs(q.x);
    if (ax > 55.3 || abs(q.y) > 3.2) return;
    vec3 H = halfVec(q, L);
    float hh = ax < 9.0 ? 2.45 : 2.15;
    float kO = cover(sdBox(q, vec2(55.0, hh)), aa);
    if (kO > 0.0) {
        if (ax < 9.0) {
            // Solid centre segment with equipment panels.
            vec2 pc = fract(vec2(q.x / 2.25, q.y / 1.6 + 0.5));
            float pe = min(min(pc.x, 1.0 - pc.x) * 2.25, min(pc.y, 1.0 - pc.y) * 1.6);
            float ny = clamp(q.y / hh, -1.0, 1.0) * 0.5;
            vec3 n = normalize(vec3(0.0, ny, 1.0));
            vec3 kd = vec3(0.74, 0.74, 0.72) * (0.9 + 0.15 * hash12(floor(vec2(q.x / 2.25, q.y / 1.6 + 0.5)) + 3.0));
            vec3 c = shade(n, L, H, kd, vec3(0.5), 60.0);
            over(acc, mix(c, c * 0.45, lineCov(pe, 0.06, aa)), kO);
        } else {
            // Equipment inside the open lattice: darker, partly see-through.
            over(acc, vec3(0.20, 0.20, 0.21) * (AMB * 3.0 + SUNC * 0.45 * L.z), kO * 0.55);
            float bay = 4.3;
            float bx = mod(ax, bay);
            float par = mod(floor(ax / bay), 2.0);
            float y2 = par > 0.5 ? -q.y : q.y;
            // Diagonal strut across the bay.
            vec2 a = vec2(0.0, -hh + 0.3), b = vec2(bay, hh - 0.3);
            vec2 pa = vec2(bx, y2) - a, ba = b - a;
            float dd = length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
            float kS = max(lineCov(dd, 0.14, aa), lineCov(min(bx, bay - bx), 0.16, aa));
            vec3 cs = shade(vec3(0.0, 0.0, 1.0), L, H, vec3(0.70, 0.70, 0.68), vec3(0.4), 50.0);
            over(acc, cs, kS * kO);
            // Top and bottom rails: little round tubes.
            float dr = abs(q.y) - (hh - 0.24);
            float kR = cover(abs(dr) - 0.24, aa) * kO;
            float ny = clamp(dr / 0.24, -1.0, 1.0);
            vec3 nr = normalize(vec3(0.0, sign(q.y) * ny, sqrt(1.0 - ny * ny)));
            over(acc, shade(nr, L, H, vec3(0.78, 0.78, 0.76), vec3(0.6), 80.0), kR);
        }
    }
    // Rotary joints (big drums) where the outer truss turns.
    float dJ = sdBox(vec2(ax - 28.0, q.y), vec2(0.75, 2.95)) - 0.1;
    float kJ = cover(dJ, aa);
    if (kJ > 0.0) {
        float nx = clamp((ax - 28.0) / 0.85, -1.0, 1.0);
        vec3 n = normalize(vec3(sign(q.x) * nx, 0.0, sqrt(1.0 - nx * nx)));
        over(acc, shade(n, L, H, vec3(0.80, 0.80, 0.78), vec3(0.7), 90.0), kJ);
    }
}

// A cylindrical module from a to b (axis-aligned), radius r, with blanket
// seams and the sun's highlight running along it as a crisp stripe.
void module(inout vec4 acc, vec2 q, vec2 a, vec2 b, float r, vec3 kd, vec3 L, float aa) {
    vec2 d = b - a;
    float len = length(d);
    d /= len;
    vec2 w = q - a;
    float s = dot(w, d);
    float c = d.x * w.y - d.y * w.x;
    float sm = s - 0.5 * len;
    float k = cover(sdBox(vec2(sm, c), vec2(0.5 * len - 0.3, r - 0.3)) - 0.3, aa);
    if (k <= 0.0) return;
    float ac = clamp(c / r, -0.995, 0.995);
    vec3 n = vec3(vec2(-d.y, d.x) * ac, sqrt(1.0 - ac * ac));
    // The end cones turn away from the viewer.
    float endF = smoothstep(0.5 * len - 0.7, 0.5 * len, abs(sm));
    n = normalize(n + vec3(d * sign(sm) * endF * 1.2, 0.0));
    // Blanket seams: rings and a few lengthwise lines; patches vary a little.
    float ring = 1.35;
    float rs = fract(s / ring);
    float seam = max(lineCov(min(rs, 1.0 - rs) * ring, 0.05, aa),
                     lineCov(abs(fract(ac * 1.5 + 0.5) - 0.5) * r / 1.5, 0.04, aa) * 0.6);
    float patchv = hash12(vec2(floor(s / ring), floor(ac * 1.5 + 2.0)) + a * 1.7);
    vec3 base = kd * (0.90 + 0.14 * patchv) * (1.0 - 0.35 * seam);
    vec3 col = shade(n, L, halfVec(q, L), base, vec3(0.65), 70.0);
    over(acc, col, k);
}

vec4 drawStation(vec2 q, vec3 L, vec2 sp, float aa) {
    vec4 acc = vec4(0.0);
    radiators(acc, q, L, aa);
    solarWings(acc, q, L, sp, aa);
    truss(acc, q, L, aa);
    if (abs(q.x) > 21.0 || q.y > 15.0 || q.y < -45.5) return acc;

    vec3 W = vec3(0.86, 0.86, 0.84);    // US / European / Japanese white blankets
    vec3 R = vec3(0.80, 0.82, 0.76);    // Russian segment, a little greener
    vec3 H = halfVec(q, L);

    // Small dark-blue arrays on the service module.
    float ax = abs(q.x);
    float dZ = sdBox(vec2(ax - 8.7, q.y + 31.5), vec2(6.2, 1.45));
    float kZ = cover(dZ, aa);
    if (kZ > 0.0) {
        vec3 n = normalize(vec3(0.0, 0.25, 1.0));
        float f = fract((ax - 2.5) / 1.55);
        float g = max(lineCov(min(f, 1.0 - f) * 1.55, 0.06, aa), lineCov(abs(q.y + 31.5), 0.05, aa));
        vec3 c = shade(n, L, H, vec3(0.06, 0.08, 0.16), vec3(0.55, 0.65, 0.9), 300.0);
        over(acc, mix(c, vec3(0.30, 0.30, 0.30) * (0.3 + L.z), g), kZ);
    }
    // Kibo's exposed platform with its payload boxes.
    float dE = sdBox(q - vec2(-16.9, 8.0), vec2(2.6, 2.1));
    float kE = cover(dE, aa);
    if (kE > 0.0) {
        vec2 bi = floor((q - vec2(-19.5, 5.9)) / vec2(1.3, 1.4));
        float hb = hash12(bi + 5.0);
        vec3 c = shade(vec3(0.0, 0.0, 1.0), L, H, mix(vec3(0.62, 0.62, 0.60), vec3(0.80, 0.70, 0.45), step(0.7, hb)) * (0.75 + 0.3 * hb), vec3(0.4), 60.0);
        over(acc, c, kE);
    }

    // Side modules first, so the main stack sits on top of their roots.
    module(acc, q, vec2(-2.0, 8.0),  vec2(-14.3, 8.0), 2.2, W, L, aa);  // Kibo
    module(acc, q, vec2(2.0, 8.0),   vec2(9.0, 8.0),   2.2, W, L, aa);  // Columbus
    module(acc, q, vec2(-2.0, -7.2), vec2(-9.4, -7.2), 2.2, W, L, aa);  // Tranquility
    module(acc, q, vec2(-9.2, -7.2), vec2(-10.9, -7.2), 1.45, vec3(0.70), L, aa);  // Cupola
    module(acc, q, vec2(2.0, -7.2),  vec2(7.2, -7.2),  1.9, W, L, aa);  // Quest airlock
    // Main stack, forward to aft.
    module(acc, q, vec2(0.0, 12.0),  vec2(0.0, 14.4),  1.3, vec3(0.62), L, aa);  // docking adapter
    module(acc, q, vec2(0.0, 4.4),   vec2(0.0, 12.2),  2.2, W, L, aa);  // Harmony
    module(acc, q, vec2(0.0, -4.6),  vec2(0.0, 4.6),   2.15, W, L, aa); // Destiny
    module(acc, q, vec2(0.0, -10.0), vec2(0.0, -4.4),  2.3, W, L, aa);  // Unity
    module(acc, q, vec2(0.0, -12.2), vec2(0.0, -9.8),  1.4, vec3(0.62), L, aa);
    module(acc, q, vec2(0.0, -24.6), vec2(0.0, -12.0), 2.05, R, L, aa); // Zarya
    module(acc, q, vec2(0.0, -37.8), vec2(0.0, -24.4), 2.1, R, L, aa);  // Zvezda
    module(acc, q, vec2(0.0, -44.8), vec2(0.0, -37.6), 1.35, vec3(0.58, 0.60, 0.52), L, aa); // Progress
    return acc;
}

// ---- Sky -----------------------------------------------------------------

// Crisp starfield: at most one point star per grid cell, about a pixel wide.
float starField(vec2 p, float t, float px) {
    float cs = 0.026;
    vec2 g = p / cs;
    vec2 id = floor(g);
    float h = hash12(id + 17.0);
    if (h > 0.34) return 0.0;
    vec2 o = 0.2 + 0.6 * hash22(id + 3.1);
    float d = length(fract(g) - o) * cs / px;      // distance in pixels
    float b = hash12(id + 9.7);
    float r = 0.55 + 0.6 * b * b;
    float tw = 0.85 + 0.15 * sin(t * (0.7 + 2.0 * h) + h * 60.0);
    return exp(-d * d / (r * r)) * (0.18 + 0.82 * b * b * b) * tw;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;
    float px = 1.0 / iResolution.y;
    vec3 col = base.rgb;

    // Sun: to the right and towards the viewer, so the station's left side is shadowed.
    vec3 Lw = normalize(vec3(0.62, 0.22, 0.72));

    // ---- Station placement (computed first so it can hide stars behind it).
    vec2 pos = vec2(aspect - 0.36 + 0.03 * sin(t * 0.037),
                    0.64 + 0.025 * sin(t * 0.029 + 1.0));
    float ang = 0.42 + t * SPIN;
    vec2 rel = p - pos;
    vec4 sat = vec4(0.0);
    if (length(rel) < 70.0 * ISS_SIZE) {
        vec2 q = rot(rel, -ang) / ISS_SIZE;
        vec3 L = vec3(rot(Lw.xy, -ang), Lw.z);
        // Point the arrays' reflection lands on, wandering slowly over the
        // whole station so the glint sweeps from cell to cell.
        vec2 sp = vec2(50.0 * cos(t * 0.071 + 0.35), 24.0 * sin(t * 0.113 + 0.75));
        sat = drawStation(q, L, sp, px / ISS_SIZE);
    }

    // ---- Earth: a huge sphere whose limb curves through the lower right.
    vec2 C = vec2(aspect + 0.30, -2.00);
    float R = 2.35;
    vec2 dp = p - C;
    float r = length(dp);
    vec2 nrm = dp / r;
    float h = r - R;                                  // height above the limb
    vec3 Le = normalize(vec3(0.999, 0.04, -0.30));    // sun for the Earth: low, behind the limb
    float dayLimb = dot(nrm, Le.xy);

    if (h > 0.0) {
        // Stars, dimmer over the text corner, hidden by the station.
        float textFade = mix(0.35, 1.0, smoothstep(0.25, 0.95, uv.x + uv.y * 0.6));
        vec3 sc = mix(vec3(1.0, 0.86, 0.72), vec3(0.78, 0.86, 1.0), hash12(floor(p / 0.026) + 2.0));
        col += sc * starField(p, t, px) * STARS * textFade * (1.0 - sat.a) * INTENSITY;
    } else {
        float depth = -h;
        float s = r / R;
        float mu = sqrt(max(1.0 - s * s, 0.0));
        vec3 N = vec3(nrm * s, mu);
        float day = smoothstep(-0.015, 0.03, dot(N, Le));
        // Day side: dark ocean with crisp-edged cloud patches, brightening
        // towards the limb where we look through more air.
        float along = atan(nrm.y, nrm.x) * R + t * 0.002;
        vec2 cp = vec2(along * 16.0, sqrt(depth) * 30.0);
        float cl = vnoise(cp) * 0.65 + vnoise(cp * 2.7 + 7.0) * 0.35;
        float clouds = smoothstep(0.56, 0.60, cl);
        vec3 dayC = mix(vec3(0.03, 0.09, 0.22), vec3(0.62, 0.68, 0.76), clouds * 0.8);
        dayC = mix(dayC, vec3(0.30, 0.52, 0.85), exp(-depth / 0.010) * 0.6);
        dayC *= 0.75 * clamp(dot(N, Le) * 3.0 + 0.4, 0.0, 1.0);
        vec3 nightC = vec3(0.004, 0.007, 0.016);
        // Thin orange band along the terminator.
        float term = exp(-pow(dot(N, Le) / 0.025, 2.0)) * exp(-depth / 0.05);
        vec3 surf = mix(nightC, dayC, day) + vec3(0.9, 0.38, 0.12) * term * 0.25;
        // City lights: crisp warm specks in loose clusters on the night side.
        vec2 cg = p / 0.011;
        vec2 cid = floor(cg);
        float cluster = smoothstep(0.62, 0.78, vnoise(cid * 0.11 + 4.0));
        if (hash12(cid + 41.0) < 0.30 * cluster) {
            vec2 o = 0.2 + 0.6 * hash22(cid + 8.0);
            float dpx = length(fract(cg) - o) * 0.011 / px;
            float b = hash12(cid + 2.3);
            float rr = 0.5 + 0.45 * b;
            surf += vec3(1.0, 0.72, 0.36) * exp(-dpx * dpx / (rr * rr)) * (0.35 + 0.65 * b)
                  * (1.0 - day) * smoothstep(0.0, 0.025, depth);
        }
        float body = clamp(depth / px, 0.0, 1.0);
        col = mix(col, surf * EARTH, body * 0.82 * INTENSITY);
    }

    // Atmosphere: a crisp, thin blue line on the limb (two pixels) and a faint
    // tight layer just above it. Bright where sunlit, dim airglow on the night side.
    if (h > -4.0 * px && h < 12.0 * px) {
        float hp = h / px;
        float line = lineCov(abs(hp - 1.0), 1.0, 1.0);
        float layer = exp(-max(hp, 0.0) / 3.0) * step(0.0, hp);
        float lit = smoothstep(-0.10, 0.12, dayLimb);
        vec3 atm = mix(vec3(0.10, 0.30, 0.70), vec3(0.40, 0.72, 1.00), lit);
        float bright = mix(0.45, 1.0, lit);
        col += atm * (line * 0.85 + layer * 0.22) * bright * EARTH * INTENSITY;
        col += vec3(1.0, 0.45, 0.15) * lineCov(abs(hp + 0.5), 0.8, 1.0)
             * exp(-pow(dayLimb / 0.05, 2.0)) * 0.5 * EARTH * INTENSITY;
    }

    // Station on top of everything.
    float k = OPACITY * INTENSITY;
    col = col * (1.0 - sat.a * k) + sat.rgb * k;

    fragColor = vec4(col, base.a);
}
