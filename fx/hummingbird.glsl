// hummingbird — a small iridescent hummingbird hovers and darts between softly glowing flowers on the right.
// zh: 蜂鸟
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float SIZE      = 0.20;   // bird unit in window heights (beak-to-tail is ~0.78 units, so ~16 %)
const float SCENE     = 0.70;   // scale of the flower spray (1 = the old, much bigger one)
const float CYCLE     = 24.0;   // seconds before the choreography repeats
const float SWAY      = 0.06;   // how far the hanging flowers swing (radians)
const float WING      = 0.80;   // brightness of the shimmering wing blur
const float BODY_A    = 0.70;   // opacity of the bird's body (the rest is light)
const float FLOWER_A  = 0.40;   // opacity of the flower petals (the rest is glow)
const float HAZE      = 0.05;   // warm backlight / out-of-focus bokeh behind the scene

const float PI = 3.14159265;

// Four hanging flowers. FS: where on the stem the flower hangs (0 = window edge,
// 1 = stem tip), FLP/FLT: stalk and trumpet length, FANG: how far the mouth leans
// left, FTYPE: 0 warm coral, 1 rose-lilac. Lengths are scaled by SCENE.
const float FS[4]    = float[4](0.86, 0.63, 0.41, 0.18);
const float FLP[4]   = float[4](0.045, 0.085, 0.035, 0.095);
const float FLT[4]   = float[4](0.170, 0.180, 0.160, 0.180);
const float FANG[4]  = float[4](0.50, 0.38, 0.46, 0.30);
const float FTYPE[4] = float[4](0.0, 1.0, 0.0, 1.0);

// Choreography. Each keyframe: arrival time in the cycle, spot, and seconds of
// travel before arrival. Spots: 0-3 sip at flower i, 10-13 hover just below
// flower i, 30-31 hover in open air (still on the right side).
const int   NK = 12;
const float KT[12]  = float[12](0.0, 3.0, 4.3, 7.3, 8.6, 11.2, 12.6, 14.6, 15.8, 18.8, 20.2, 22.0);
const int   KS[12]  = int[12]  (1,   11,  2,   12,  0,   10,   30,   13,   3,    13,   31,   11);
const float KTR[12] = float[12](1.0, 0.6, 0.8, 0.6, 1.0, 0.6,  1.0,  1.1,  0.6,  0.5,  1.0,  1.1);

const vec2 BEAK_TIP = vec2(0.52, 0.022);   // in bird units, shoulder at the origin
const vec3 SUN      = vec3(1.00, 0.86, 0.66);   // warm key light, from the upper right
const vec2 SUN_DIR  = vec2(0.55, 0.835);

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sdEllipse(vec2 p, vec2 r) {
    return (length(p / r) - 1.0) * min(r.x, r.y);
}

// Distance to a capsule from a (radius ra) to b (radius rb); y = position along it.
vec2 taper(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h) - mix(ra, rb, h), h);
}

// Translucent layer: darkens what is behind by a and adds its own colour.
void over(inout vec4 acc, vec3 col, float a) {
    a = clamp(a, 0.0, 1.0);
    acc.rgb = col * a + acc.rgb * (1.0 - a);
    acc.a = a + acc.a * (1.0 - a);
}

// Pure light: adds brightness without hiding anything.
void glow(inout vec4 acc, vec3 col, float g) {
    acc.rgb += col * max(g, 0.0);
}

float smoother(float x) {
    x = clamp(x, 0.0, 1.0);
    return x * x * x * (x * (6.0 * x - 15.0) + 10.0);
}

// A dart: accelerate smoothly, overshoot the target by 5 %, settle back. Both
// halves start and end at rest, so there is never a jump in speed.
float dartEase(float u) {
    return u < 0.72 ? 1.05 * smoother(u / 0.72) : 1.05 - 0.05 * smoother((u - 0.72) / 0.28);
}

// The stem: a sagging curve that enters from the right edge, mid-height.
vec2 stemAt(float s, float t, float aspect) {
    vec2 a = vec2(aspect + 0.03, 0.70);
    vec2 b = a + SCENE * vec2(-0.33, -0.30);
    vec2 c = a + SCENE * vec2(-0.63, -0.15);
    vec2 q = mix(mix(a, b, s), mix(b, c, s), s);
    q += vec2(0.003, 0.005) * s * sin(t * 0.6 + s * 2.5);
    return q;
}

// Flower i: where its stalk leaves the stem (A) and the way it hangs (d, unit).
void flowerFrame(int i, float t, float aspect, out vec2 A, out vec2 d) {
    float fi = float(i);
    A = stemAt(FS[i], t, aspect);
    float ang = FANG[i] + SWAY * sin(t * 0.8 + fi * 1.9) + 0.015 * sin(t * 1.7 + fi * 3.0);
    d = vec2(-sin(ang), -cos(ang));
}

// Where the bird's shoulder sits, and its nose-up angle, at a given spot. At a
// flower the bird lines its beak up with the trumpet, so it rides the sway.
void spotPose(int s, float t, float aspect, out vec2 pos, out float pitch) {
    if (s < 20) {
        int i = s < 10 ? s : s - 10;
        vec2 A, d;
        flowerFrame(i, t, aspect, A, d);
        vec2 M = A + d * (FLP[i] + FLT[i]) * SCENE;
        pitch = atan(-d.y, -d.x) + 0.042;
        vec2 tip = M - d * 0.007;                                  // beak pushed into the tube
        if (s >= 10) { tip = M + d * 0.028 + vec2(-0.008, -0.006); pitch -= 0.15; }
        pos = tip - rot(BEAK_TIP, pitch) * SIZE;
    } else if (s == 30) { pos = vec2(aspect - 0.50, 0.30); pitch = 0.55; }
    else                { pos = vec2(aspect - 0.15, 0.26); pitch = 0.65; }
}

// Where the bird is right now. pose: x = pitch, y = sipping (0..1), z = braking.
void birdPose(float t, float aspect, out vec2 pos, out vec3 pose) {
    float ct = mod(t, CYCLE);
    int j = 0;
    for (int k = 1; k < NK; k++) if (KT[k] <= ct) j = k;
    int jn = j + 1;
    float tn = jn < NK ? KT[jn] : CYCLE;
    if (jn >= NK) jn = 0;
    float tr = KTR[jn];
    float start = tn - tr;

    vec2 pA; float pitA;
    int sA = KS[j];
    spotPose(sA, t, aspect, pA, pitA);
    float sip = 0.0, brake = 0.0, fly = 0.0;
    float pitch = pitA;
    pos = pA;

    if (ct >= start) {
        float u = (ct - start) / tr;
        vec2 pB; float pitB;
        spotPose(KS[jn], t, aspect, pB, pitB);
        float e = dartEase(u);
        vec2 dv = pB - pA;
        float len = length(dv);
        vec2 nrm = len > 1e-4 ? vec2(-dv.y, dv.x) / len : vec2(0.0, 1.0);
        if (nrm.y < 0.0) nrm = -nrm;                               // darts arc upward
        pos = mix(pA, pB, e) + nrm * 0.10 * len * sin(PI * clamp(e, 0.0, 1.0));
        fly = smoothstep(0.0, 0.25, u) * smoothstep(1.0, 0.7, u) * smoothstep(0.03, 0.15, len);
        pitch = mix(pitA, pitB, smoother(u));
        pitch = mix(pitch, 0.25, fly * 0.7);                      // flatter while darting
        brake = smoothstep(0.55, 0.72, u) * smoothstep(1.0, 0.8, u);
    } else if (sA < 4) {
        // Sipping: ease in after arrival and out before leaving.
        sip = smoothstep(0.0, 0.35, ct - KT[j]) * smoothstep(0.0, 0.35, start - ct);
    }

    // Gentle hovering bob, which fades out while the beak is in a flower.
    float hov = (1.0 - sip) * (1.0 - fly);
    pos += vec2(0.0025 * sin(t * 2.1), 0.0035 * sin(t * 3.3)) * hov;
    pitch += 0.035 * sin(t * 1.9) * hov;

    // While sipping the head nudges in and out along the trumpet.
    if (sA < 4) {
        vec2 A, d;
        flowerFrame(sA, t, aspect, A, d);
        pos += -d * sip * 0.0035 * (0.5 - 0.5 * cos(t * 6.5));
    }
    pose = vec3(pitch, sip, brake);
}

// Blur of a beating wing seen from the side: a fan swept from the shoulder,
// densest at both ends of the stroke where the wing slows to turn.
// Returns x = density, y = radius (for the shimmer bands).
vec2 wingBlur(vec2 v, vec2 sh, float c, float span, float R) {
    vec2 r2 = v - sh;
    float r = length(r2);
    if (r > R * 1.08) return vec2(0.0);
    float ang = atan(r2.y, r2.x);
    if (ang < c - PI) ang += 2.0 * PI;
    float ak = abs((ang - c) / span);
    if (ak > 1.15) return vec2(0.0);
    float ends = smoothstep(1.12, 0.90, ak);
    float dens = 0.22 + 0.78 * pow(ak, 5.0);
    float tip = R * (0.93 + 0.07 * cos(ak * 1.5708));
    float rad = smoothstep(0.05, 0.14, r) * smoothstep(tip, tip - 0.09, r);
    return vec2(ends * rad * dens, r);
}

// Soft iridescent palette: emerald -> teal -> gold, never a saturated primary.
vec3 irid(float x) {
    return 0.5 + 0.5 * cos(6.2832 * (x + vec3(0.33, 0.18, 0.62)) ) * vec3(0.55, 0.75, 0.55);
}

// The bird's silhouette (head turned by hr) as one smooth distance field.
float birdSD(vec2 v, float hr) {
    vec2 neck = vec2(0.13, 0.02);
    vec2 vh = rot(v - neck, -hr) + neck;
    float dHead = length(vh - vec2(0.20, 0.045)) - 0.082;
    float dBody = sdEllipse(rot(v - vec2(0.0, -0.008), 0.12), vec2(0.215, 0.100));
    float dRump = taper(v, vec2(-0.08, -0.012), vec2(-0.27, -0.045), 0.072, 0.026).x;
    return smin(smin(dBody, dRump, 0.04), dHead, 0.05);
}

// One hummingbird facing +x in its own units. L = light direction in these units.
vec4 bird(vec2 v, vec3 pose, float t, float aa, float tubeMask, vec2 L) {
    vec4 c = vec4(0.0);
    float sip = pose.y, brake = pose.z;
    float shim = t * 9.0;                                         // shimmer drift on the wings

    // Far wing: faint light only.
    vec2 wf = wingBlur(v, vec2(0.0, 0.045), 1.55 + 0.03 * sin(t * 23.0), 0.95, 0.42);
    if (wf.x > 0.0) {
        vec3 wc = mix(vec3(0.55, 0.75, 0.95), vec3(0.85, 0.75, 1.0), 0.5 + 0.5 * sin(wf.y * 40.0 - shim));
        over(c, vec3(0.05, 0.07, 0.09), wf.x * 0.10);
        glow(c, wc, wf.x * 0.16 * WING);
    }

    // Forked tail: five translucent feathers that fan out when braking.
    vec2 tb = vec2(-0.25, -0.045);
    float tilt = 0.10 * sin(t * 2.1) - 0.30 * brake;
    float spread = 0.14 + 0.05 * sin(t * 1.3) + 0.30 * brake;
    for (int k = 0; k < 5; k++) {
        float o = (float(k) - 2.0) * 0.5;
        float a = PI + 0.15 + tilt + o * spread;
        vec2 e = tb + (0.20 + 0.08 * o * o) * vec2(cos(a), sin(a));
        vec2 f = taper(v, tb, e, 0.028, 0.018);
        if (f.x > 0.03) continue;
        float m = smoothstep(aa, -aa, f.x);
        over(c, mix(vec3(0.03, 0.10, 0.07), vec3(0.03, 0.05, 0.05), f.y), m * BODY_A * (1.0 - 0.4 * f.y));
        glow(c, SUN * vec3(0.6, 0.9, 0.7), exp(-abs(f.x) * 300.0) * 0.30 * (1.0 - 0.6 * f.y));   // lit edges
    }

    // Head turns a little (not while drinking); the throat flashes when it tips up.
    float turn = sin(t * 0.9);
    float hr = 0.07 * turn * (1.0 - sip);
    float flash = max(smoothstep(0.1, 0.9, turn), 0.6 * sip * (0.5 + 0.5 * sin(t * 1.7)));
    vec2 neck = vec2(0.13, 0.02);
    vec2 vh = rot(v - neck, -hr) + neck;

    float d = birdSD(v, hr);
    float inBody = smoothstep(0.01, -0.03, d);
    // Soft bloom just outside the silhouette, so it sits in the light.
    glow(c, vec3(0.45, 0.80, 0.65), exp(-max(d, 0.0) * 40.0) * 0.05);

    if (d < 0.03) {
        // Surface normal from the distance field, for rim and sheen.
        vec2 e = vec2(0.004, 0.0);
        vec2 n = normalize(vec2(birdSD(v + e.xy, hr) - d, birdSD(v + e.yx, hr) - d) + 1e-6);
        float m = smoothstep(aa, -aa, d);
        float h = clamp(-d / 0.07, 0.0, 1.0);
        float ndl = dot(n, L);

        // Back is dark emerald, belly a pale smoky grey; both translucent.
        float dors = smoothstep(-0.015, 0.02, v.y - (0.002 + 0.12 * v.x));
        vec3 bodyCol = mix(vec3(0.20, 0.22, 0.22), vec3(0.02, 0.08, 0.06), dors);
        over(c, bodyCol, m * BODY_A * mix(0.75, 1.0, dors));

        // Iridescent sheen: hue shifts with the surface angle and drifts in time.
        float band = exp(-pow((v.x - (0.12 * sin(t * 0.9) - 0.02)) * 6.0, 2.0));
        vec3 sheen = irid(0.25 * ndl + 0.10 * v.x + 0.06 * sin(t * 0.7));
        glow(c, sheen, m * dors * (0.16 + 0.45 * band * sqrt(h)));
        float scales = sin(v.x * 90.0 + 2.0 * sin(v.y * 60.0)) * sin(v.y * 90.0);
        glow(c, sheen, m * dors * band * 0.09 * max(scales, 0.0));

        // Rim light on the edge that faces the sun; faint cool fill on the other.
        float edge = exp(-abs(d) * 130.0);
        glow(c, SUN, edge * smoothstep(-0.2, 0.8, ndl) * 0.85);
        glow(c, vec3(0.45, 0.65, 0.95), edge * smoothstep(0.2, -0.8, ndl) * 0.22);

        // Gorget: catches the light as a soft ruby-magenta glow.
        vec2 gq = rot(vh - vec2(0.19, -0.022), 0.55);
        float gm = smoothstep(0.02, -0.02, sdEllipse(gq, vec2(0.09, 0.05))) * (1.0 - dors) * m;
        vec3 ruby = mix(vec3(1.0, 0.25, 0.42), vec3(1.0, 0.45, 0.70), 0.5 + 0.5 * sin(t * 0.6));
        over(c, vec3(0.10, 0.02, 0.04), gm * 0.35 * (1.0 - flash));
        glow(c, ruby, gm * (0.08 + flash) * (0.50 + 0.05 * sin(gq.x * 140.0) * sin(gq.y * 140.0)));

        // Eye: a dark bead with a bright catchlight.
        float de = length(vh - vec2(0.222, 0.052));
        over(c, vec3(0.01, 0.01, 0.02), smoothstep(0.020, 0.015, de) * 0.8);
        glow(c, vec3(1.0, 0.97, 0.9), smoothstep(0.008, 0.002, length(vh - vec2(0.229, 0.060))) * 0.9);
    }
    // Throat glow spills a little outside the body when it flashes.
    glow(c, vec3(1.0, 0.35, 0.55), flash * 0.15 * exp(-length(vh - vec2(0.20, -0.03)) * 18.0));

    // Long thin beak: a dark sliver with a thin lit upper edge, hidden inside a flower.
    vec2 bq = taper(vh, vec2(0.26, 0.036), BEAK_TIP, 0.012, 0.003);
    if (bq.x < 0.02) {
        float bm = smoothstep(aa, -aa, bq.x) * (1.0 - tubeMask);
        over(c, vec3(0.04, 0.04, 0.05), bm * 0.80);
        float top = smoothstep(0.0, 0.006, vh.y - mix(0.036, BEAK_TIP.y, bq.y));
        glow(c, SUN, bm * (0.06 + top * 0.40));
    }

    // Near wing in front: a shimmering translucent fan of light.
    vec2 wn = wingBlur(v, vec2(0.03, 0.035), 1.75 - 0.03 * sin(t * 23.0), 1.05, 0.44);
    if (wn.x > 0.0) {
        float bands = 0.5 + 0.5 * sin(wn.y * 55.0 - shim);
        vec3 wc = mix(vec3(0.60, 0.85, 1.00), vec3(1.00, 0.85, 0.70), bands);
        wc = mix(wc, vec3(0.80, 0.70, 1.0), 0.5 + 0.5 * sin(wn.y * 23.0 + shim * 0.7));
        over(c, vec3(0.06, 0.08, 0.10), wn.x * 0.12 * (1.0 - inBody));
        glow(c, wc, wn.x * (0.22 + 0.10 * bands) * WING * (1.0 - 0.6 * inBody));
    }
    return c;
}

void drawBird(inout vec4 acc, vec2 p, float t, float aspect, float tubeMask) {
    vec2 pos; vec3 pose;
    birdPose(t, aspect, pos, pose);
    vec2 v = (p - pos) / SIZE;
    if (dot(v, v) > 0.40) return;                                // far from the bird: nothing to do
    v = rot(v, -pose.x);
    vec2 L = rot(SUN_DIR, -pose.x);
    float aa = 1.5 / (iResolution.y * SIZE);
    vec4 c = bird(v, pose, t, aa, tubeMask, L);
    acc.rgb = c.rgb + acc.rgb * (1.0 - c.a);
    acc.a = c.a + acc.a * (1.0 - c.a);
}

// Thin stem and a few translucent leaves, lit only along their edges.
void drawStem(inout vec4 acc, vec2 p, float t, float aspect, float aa) {
    if (p.y < 0.62 - 0.30 * SCENE || p.x < aspect - 0.75 * SCENE) return;
    float dmin = 1e3, sOn = 0.0;
    vec2 prev = stemAt(0.0, t, aspect);
    for (int k = 1; k <= 8; k++) {
        float s = float(k) / 8.0;
        vec2 cur = stemAt(s, t, aspect);
        vec2 pa = p - prev, ba = cur - prev;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float dd = length(pa - ba * h);
        if (dd < dmin) { dmin = dd; sOn = s - (1.0 - h) / 8.0; }
        prev = cur;
    }
    float w = mix(0.0040, 0.0015, sOn);
    over(acc, vec3(0.06, 0.10, 0.06), smoothstep(aa, -aa, dmin - w) * 0.40);
    glow(acc, vec3(0.70, 0.85, 0.55), exp(-max(dmin - w, 0.0) * 500.0) * 0.10);

    for (int k = 0; k < 5; k++) {
        float fk = float(k);
        float s = 0.08 + fk * 0.2;
        vec2 base = stemAt(s, t, aspect);
        float side = mod(fk, 2.0) < 0.5 ? 1.0 : -1.0;
        float a = -1.5708 + side * 0.80 + 0.12 * sin(t * 1.1 + fk * 1.7);
        vec2 dir = vec2(cos(a), sin(a));
        vec2 q = p - base;
        float lx = dot(q, dir), ly = dot(q, vec2(-dir.y, dir.x));
        float Ll = (0.065 - 0.006 * fk) * SCENE;
        if (lx < -0.004 || lx > Ll + 0.004 || abs(ly) > 0.02) continue;
        float x = clamp(lx / Ll, 0.0, 1.0);
        float half_ = 0.022 * SCENE * sin(PI * pow(x, 0.8)) * (1.0 - 0.15 * x);
        float dl = abs(ly) - half_;
        float leaf = smoothstep(aa, -aa, dl) * step(0.0, lx) * step(lx, Ll);
        over(acc, vec3(0.05, 0.12, 0.07), leaf * 0.12);
        glow(acc, vec3(0.65, 0.90, 0.50), leaf * (0.04 + exp(-abs(dl) * 700.0) * 0.16));      // backlit rim
        glow(acc, vec3(0.65, 0.90, 0.50), leaf * exp(-abs(ly) * 1500.0) * 0.06);     // midrib
    }
}

// A trumpet flower of light hanging from the stem, mouth glowing toward the ground.
// Returns how much of this pixel is covered by the trumpet (to hide the beak).
float drawFlower(inout vec4 acc, vec2 p, int i, float t, float aspect, float aa) {
    vec2 A, d;
    flowerFrame(i, t, aspect, A, d);
    float LP = FLP[i] * SCENE, LT = FLT[i] * SCENE, L = LP + LT;
    vec2 q = p - A;
    float s = dot(q, d), w = dot(q, vec2(-d.y, d.x));
    if (s < -0.02 || s > L + 0.07 || abs(w) > 0.07) return 0.0;

    vec3 c0 = FTYPE[i] < 0.5 ? vec3(0.95, 0.45, 0.32) : vec3(0.85, 0.40, 0.70);
    vec3 c1 = FTYPE[i] < 0.5 ? vec3(1.00, 0.72, 0.50) : vec3(1.00, 0.68, 0.88);

    // Hair-thin stalk.
    float ws = w - 0.006 * sin(clamp(s / LP, 0.0, 1.0) * PI);
    float stalk = smoothstep(aa, -aa, abs(ws) - 0.0018) * step(0.0, s) * step(s, LP + 0.003);
    over(acc, vec3(0.08, 0.12, 0.07), stalk * 0.35);
    glow(acc, vec3(0.6, 0.8, 0.5), stalk * 0.08);

    // Trumpet: slim tube widening to a flared mouth with a scalloped lip.
    float x = (s - LP) / LT;
    float rr = (0.0075 + 0.011 * x + 0.025 * pow(smoothstep(0.60, 1.0, x), 2.0)) * SCENE;
    float lip = L + 0.003 * cos(w / (0.030 * SCENE) * 4.7);
    float dt = max(abs(w) - rr, max(LP - s, s - lip));
    float soft = aa + 0.0025;                                     // a touch out of focus
    float tube = smoothstep(soft, -soft, dt);
    float cy = clamp(w / max(rr, 1e-4), -1.0, 1.0);

    // Translucent petal: thin in the middle, denser at its edges like real petals.
    float edge = pow(abs(cy), 3.0);
    over(acc, mix(c0, c1, x) * 0.30, tube * FLOWER_A * (0.35 + 0.65 * edge) * (0.5 + 0.5 * x));
    // Light passing through: dim at the base, brighter toward the open mouth.
    glow(acc, mix(c0, c1, x), tube * (0.04 + 0.34 * x * x * x) * (1.0 - 0.4 * edge));
    // Faint veins running down the trumpet.
    glow(acc, c1, tube * x * 0.05 * smoothstep(0.6, 1.0, sin(cy * 9.0)));
    // Luminous outline, strongest on the sunward side.
    float rimSide = 0.6 + 0.4 * cy * sign(-d.x + 1e-4);
    glow(acc, c1, exp(-abs(dt) * 650.0) * 0.22 * rimSide * smoothstep(LP, LP + 0.03, s));
    // Soft halo spilling from the mouth.
    float mouth = length(vec2(s - L, w) / vec2(0.75, 1.0));
    glow(acc, c1, exp(-mouth * 60.0) * (0.32 + 0.08 * sin(t * 1.3 + float(i) * 2.0)));

    // Three stamens with glowing pollen tips.
    for (int k = 0; k < 3; k++) {
        float o = float(k) - 1.0;
        float sl = L + (0.026 + 0.008 * (1.0 - abs(o))) * SCENE;
        vec2 a0 = vec2(L - 0.006, o * 0.003), a1 = vec2(sl, o * 0.009);
        vec2 f = taper(vec2(s, w), a0, a1, 0.0007, 0.0007);
        glow(acc, vec3(1.0, 0.9, 0.8), smoothstep(aa, -aa, f.x) * 0.15);
        glow(acc, vec3(1.0, 0.85, 0.45), exp(-length(vec2(s, w) - a1) * 600.0) * 0.40);
    }
    return tube;
}

// Out-of-focus backdrop: a warm backlight plus a few drifting bokeh discs and
// pollen motes, all very faint, to give the scene depth.
void drawHaze(inout vec4 acc, vec2 p, float t, float aspect) {
    vec2 ctr = vec2(aspect - 0.28, 0.50);
    float r = length((p - ctr) * vec2(0.8, 1.0));
    glow(acc, SUN * vec3(1.0, 0.85, 0.75), exp(-r * r * 9.0) * HAZE);
    if (r > 0.55) return;
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        vec2 b = ctr + vec2(0.30 * sin(fk * 2.4 + t * 0.05), 0.22 * cos(fk * 1.7 + t * 0.04))
               + vec2(0.0, 0.02 * sin(t * 0.3 + fk));
        float rad = 0.025 + 0.012 * fract(fk * 0.618);
        float db = length(p - b) - rad;
        vec3 bc = mod(fk, 2.0) < 0.5 ? vec3(1.0, 0.75, 0.55) : vec3(0.85, 0.65, 0.95);
        float tw = 0.6 + 0.4 * sin(t * 0.5 + fk * 1.3);
        glow(acc, bc, (smoothstep(0.004, -0.004, db) * 0.5 + exp(-abs(db) * 300.0) * 0.5) * HAZE * 0.9 * tw);
    }
    // Pollen motes drifting up through the light.
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        float life = fract(t * 0.06 + fk * 0.37);
        vec2 m = vec2(aspect - 0.40 + 0.06 * fk + 0.02 * sin(t * 0.7 + fk * 3.0), 0.25 + 0.40 * life);
        float g = exp(-length(p - m) * 900.0) * sin(PI * life);
        glow(acc, vec3(1.0, 0.9, 0.7), g * 0.5);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;
    float aa = 1.5 / iResolution.y;

    vec4 acc = vec4(0.0);
    // The whole scene lives in the right part of the window; skip the rest.
    if (p.x > aspect - 0.85) {
        drawHaze(acc, p, t, aspect);
        drawStem(acc, p, t, aspect, aa);
        float tube = 0.0;
        if (p.x > aspect - 0.85 * SCENE && p.y > 0.70 - 0.50 * SCENE) {
            for (int i = 0; i < 4; i++) tube = max(tube, drawFlower(acc, p, i, t, aspect, aa));
        }
        drawBird(acc, p, t, aspect, tube);
    }

    // Light layers add; translucent layers dim the terminal behind them a little.
    vec3 rgb = base.rgb * (1.0 - acc.a * INTENSITY) + acc.rgb * INTENSITY;
    fragColor = vec4(rgb, base.a);
}
