// waves — rows of ocean waves roll along the bottom; every few seconds a big one curls into a foam-clawed tube and breaks.
// zh: 海浪
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float PERIOD    = 9.0;    // seconds between two big breaking waves
const float BIG       = 0.19;   // height of a big wave in window heights (keep < ~0.2)
const float ROLL      = 1.0;    // speed of the small rolling waves
const int   DROPS     = 18;     // spray droplets when a big wave breaks

const float PI = 3.14159265;

const vec3 FAR_COL   = vec3(0.22, 0.50, 0.60);
const vec3 MID_DEEP  = vec3(0.07, 0.27, 0.47);
const vec3 MID_LIT   = vec3(0.17, 0.53, 0.63);
const vec3 NEAR_COL  = vec3(0.04, 0.16, 0.35);
const vec3 LINE_COL  = vec3(0.72, 0.90, 0.94);
const vec3 FOAM_COL  = vec3(0.97, 0.96, 0.90);

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A peaked crest: sharp tops, broad troughs (like real swell), 0..1.
float crest(float th, float sharp) {
    return exp(sharp * (cos(th) - 1.0));
}

// Height of one row of small waves rolling to the left.
float rowH(float x, float base, float amp, float k, float spd, float seed) {
    float t = iTime * ROLL;
    float a = crest(k * x + spd * t + seed, 1.8);
    float b = crest(1.71 * k * x + 1.37 * spd * t + seed * 2.3, 2.4);
    return base + amp * (0.70 * a + 0.35 * b + 0.15 * sin(0.37 * k * x + 0.5 * t + seed));
}

// Signed distance (approx.) to a height field, negative below the surface.
float rowD(vec2 p, float base, float amp, float k, float spd, float seed) {
    float e = 0.002;
    float h  = rowH(p.x, base, amp, k, spd, seed);
    float dh = (rowH(p.x + e, base, amp, k, spd, seed) - rowH(p.x - e, base, amp, k, spd, seed)) / (2.0 * e);
    return (p.y - h) / sqrt(1.0 + dh * dh);
}

// Shape of the big wave at s seconds into its life.
struct Big {
    float xc;     // x of the crest / top of the lip
    float H;      // height above the base line
    float c;      // how far the lip has curled, 0..1
    float R;      // radius of the curl
    float w0;     // lip thickness at its root
    float S;      // angle the lip has swept round, radians
    vec2  O;      // centre of the curl
    float open;   // 0..1, how hollow the tube is
};

const float B0 = 0.095;          // base line of the big wave (the middle row)

Big bigAt(float s, float xs, float hm) {
    Big b;
    b.xc = xs - 0.05 * s;                                   // drifts toward the shore (left)
    float brk = smoothstep(4.6, 6.2, s);
    b.H = hm * smoothstep(0.0, 2.6, s) * (1.0 - brk);
    b.c = smoothstep(1.4, 4.2, s);
    b.R = hm * 0.37 * (0.45 + 0.55 * smoothstep(0.5, 3.2, s)) * (1.0 - 0.5 * brk);
    b.w0 = b.R * 0.46;
    b.S = b.c * 2.05 + brk * 0.9;                            // lip keeps falling as it breaks
    b.O = vec2(b.xc, B0 + b.H - b.R);
    b.open = smoothstep(0.15, 0.55, b.c) * (1.0 - smoothstep(4.35, 4.85, s));   // the tube closes out
    return b;
}

// Lip thickness at angle u along the curl (tapers toward the tip).
float lipW(Big b, float u) {
    return b.w0 * (1.0 - 0.65 * clamp(u / max(b.S, 1e-3), 0.0, 1.0));
}

// Outer radius of the lip: a spiral that tightens toward the tip.
float spiralR(Big b, float u) {
    return b.R * (1.0 - 0.22 * clamp(u / PI, 0.0, 1.0));
}

// Height of the front of the wave (dx < 0): a smooth swell that turns into a
// concave face rising from the trough to the floor of the tube.
float frontH(Big b, float dx) {
    float wf = mix(0.11, 0.07, b.c);
    float bump = b.H * exp(-dx * dx / (wf * wf));
    // The face stays below the curl so the tube opens forward, not a closed ring.
    float floorH = max(b.O.y - 1.9 * (b.R - b.w0) * b.open - B0, 0.0);
    float f = clamp(1.0 + dx / (3.4 * b.R), 0.0, 1.0);
    float face = floorH * f * f;
    // Behind the tube floor the face meets the back slope.
    return mix(bump, face, b.open);
}

vec2 tipOf(Big b) {
    float a = PI * 0.5 + b.S;
    return b.O + vec2(cos(a), sin(a)) * (spiralR(b, b.S) - 0.5 * lipW(b, b.S));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 rgb = base.rgb;
    if (p.y > 0.36) {                        // nothing up here: the text area is free
        fragColor = base;
        return;
    }

    float px = 1.0 / iResolution.y;          // one pixel in scene units
    float k = INTENSITY;

    // ---- back row: pale, low and calm --------------------------------------
    {
        float d = rowD(p, 0.150, 0.030, 9.0, 1.1, 1.7);
        float fill = smoothstep(0.8 * px, -0.8 * px, d);
        float a = fill * mix(0.42, 0.22, smoothstep(0.0, 0.08, -d));
        rgb = mix(rgb, FAR_COL, a * k);
        float line = 1.0 - smoothstep(0.5 * px, 1.4 * px, abs(d));
        rgb = mix(rgb, LINE_COL, line * 0.45 * k);
    }

    // ---- the big wave of this cycle -----------------------------------------
    float tc = iTime + 2.8;                  // start partway in: a wave is already rising
    float n = floor(tc / PERIOD);
    float s = tc - n * PERIOD;
    float seed = n * 7.31 + 3.0;
    float xs = aspect * (0.58 + 0.30 * hash1(seed));
    float hm = BIG * (0.88 + 0.12 * hash1(seed + 1.0));
    Big b = bigAt(s, xs, hm);

    // ---- middle row, with the big wave rising out of it ----------------------
    float dMid = rowD(p, B0, 0.026, 12.0, 1.5, 4.2);
    float dWater = dMid;
    float foamLip = 0.0;
    vec2 q = p - b.O;
    float r = length(q);
    float u = mod(atan(q.y, q.x) - PI * 0.5 + 2.0 * PI, 2.0 * PI);  // angle from the top, going left

    if (b.H > 0.002 && abs(p.x - b.xc) < 0.55) {
        // Body: a broad back slope behind the crest; in front, a concave face
        // that sweeps up from the trough into the tube as the wave curls.
        float dx = p.x - b.xc;
        float hb, sl;
        if (dx >= 0.0) {
            hb = b.H * exp(-dx * dx / 0.05);
            sl = -2.0 * dx / 0.05 * hb;
        } else {
            float e = 0.002;
            hb = frontH(b, dx);
            sl = (frontH(b, dx + e) - hb) / e;
        }
        float dBody = (p.y - B0 - hb) / sqrt(1.0 + sl * sl);

        // Lip: a band along an inward spiral, from the top round to the tip.
        bool back = u > 2.0 * PI - 0.7;                      // just behind the top
        float w = back ? b.w0 : lipW(b, u);
        float rc = back ? b.R : spiralR(b, u);
        float dBand = abs(r - (rc - 0.5 * w)) - 0.5 * w;
        float over = back ? 0.0 : max(u - b.S, 0.0);
        float dLip = max(dBand, over * r);
        dLip = mix(1.0, dLip, smoothstep(0.0, 0.08, b.S));     // no lip before it curls
        dLip += smoothstep(4.7, 5.4, s) * b.w0;                // the lip dissolves into foam

        // Hollow of the tube: everything inside the lip's inner edge.
        float uh = min(u, b.S);
        float dHole = r - (spiralR(b, uh) - lipW(b, uh)) * b.open;
        // ...and the mouth below it, so the tube opens down toward the sea.
        float rh = (b.R - b.w0) * b.open;
        dHole = min(dHole, length(p - b.O - vec2(-0.55, -0.95) * rh) - 1.05 * rh);
        if (b.open < 0.3) dHole = 1.0;                        // no tube yet: no pinhole

        float dBig = max(dBody, -dHole);
        dBig = min(dBig, dLip);
        dWater = min(dWater, dBig);

        // Foam on the outer side of the lip, scalloped on its inner edge;
        // the whole lip turns to foam as it crashes.
        float brk = smoothstep(4.4, 5.6, s);
        float uu = u / max(b.S, 1e-3);
        float grow = smoothstep(0.12, 0.75, uu + 0.4 * brk);   // a thin rim that thickens to the tip
        float fl = step(0.12, uu + brk) * step(u, b.S + 0.01);
        float cut = rc - w * grow * (0.62 + 0.14 * sin(u * 26.0)) - 0.6 * px;
        float edge = smoothstep(cut - px, cut + px, r);
        foamLip = fl * edge * smoothstep(px, -px, dLip);

        // Foam claws: tapering fingers reaching past the tip, flaring outward.
        float ex = u - b.S;
        float clawLen = 0.85;
        if (ex > 0.0 && ex < clawLen && b.S > 0.6) {
            float wt = lipW(b, b.S);
            float e = ex / clawLen;
            float fr = (spiralR(b, b.S) - r) / wt + e * 0.7;  // 0 at the outer edge
            float ki = floor(fr * 4.0);
            if (ki >= 0.0 && ki < 4.0) {
                float len = 0.45 + 0.55 * hash1(ki * 3.7 + seed);
                float cen = (ki + 0.5) / 4.0;
                float half_ = 0.17 * max(1.0 - e / len, 0.0);
                float dc = (abs(fr - cen) - half_) * wt;
                foamLip = max(foamLip, smoothstep(px, -px, dc) * step(e, len));
            }
        }
        foamLip *= 1.0 - smoothstep(5.4, 6.4, s);
    }

    {
        float fill = smoothstep(0.8 * px, -0.8 * px, dWater);
        float depth = -dWater;
        // Light shines through the thin water near the crest: lighter higher up.
        float lit = smoothstep(B0 - 0.02, B0 + 0.16, p.y);
        vec3 col = mix(MID_DEEP, MID_LIT, lit);
        float a = fill * mix(0.36, 0.64, smoothstep(B0 - 0.07, B0 + 0.03, p.y));
        rgb = mix(rgb, col, a * k);

        // Engraved contour lines just under the surface (Hokusai-style).
        for (int i = 1; i <= 2; i++) {
            float off = float(i) * 0.011;
            float l = 1.0 - smoothstep(0.4 * px, 1.2 * px, abs(dWater + off));
            rgb = mix(rgb, LINE_COL, l * fill * (0.30 - 0.08 * float(i)) * k);
        }
        float line = 1.0 - smoothstep(0.6 * px, 1.6 * px, abs(dWater));
        rgb = mix(rgb, LINE_COL, line * 0.75 * k);
        rgb = mix(rgb, FOAM_COL, foamLip * 0.92 * k);
    }

    // ---- whitewater: the broken wave runs on as a mound of lacy foam -----
    float sb = s - 4.75;
    if (sb > 0.0) {
        Big bb = bigAt(4.75, xs, hm);
        vec2 tip = tipOf(bb);
        float age = sb / (PERIOD - 4.75);
        float xl = tip.x - 0.06 - 0.10 * sb;                  // leading edge runs ahead
        float xr = bb.xc + 0.12 - 0.02 * sb;
        float fade = 1.0 - smoothstep(0.5, 1.0, age);
        if (p.x > xl - 0.02 && p.x < xr + 0.02) {
            float span = clamp((p.x - xl) / (xr - xl), 0.0, 1.0);
            float env = smoothstep(0.0, 0.15, span) * smoothstep(1.0, 0.55, span);
            float sea = rowH(p.x, B0, 0.026, 12.0, 1.5, 4.2);
            float hgt = (0.010 + 0.035 * exp(-sb * 1.2)) * env;
            // Bubbly top edge.
            float fb = fract(p.x * 70.0 - sb * 0.6) * 2.0 - 1.0;
            float top = sea + hgt * (0.80 + 0.20 * sqrt(1.0 - fb * fb));   // round bubbly bumps
            float solid = smoothstep(px, -px, p.y - top) * smoothstep(-px, px, p.y - sea + 0.004);
            // Lace below: dots of foam on a small grid, thinning out with depth.
            vec2 g = vec2(p.x - 0.02 * sb, p.y) / 0.0068;
            vec2 id = floor(g);
            float h = hash2(id + n * 13.0);
            float rad = 0.16 + 0.26 * hash2(id + 7.1);
            float dot_ = smoothstep(rad + 0.14, rad - 0.14, length(fract(g) - 0.5));
            float below = sea - 0.004 - p.y;                          // depth under the foam
            float lace = dot_ * step(0.0, below) * step(h, env * (1.0 - below / 0.035));
            // Loose bubbles drifting just above the mound.
            float above = p.y - top;
            lace = max(lace, dot_ * step(0.0, above) * step(above, 0.02) * step(h, 0.18 * env));
            float foam = max(solid * smoothstep(0.02, 0.2, env), lace);
            rgb = mix(rgb, FOAM_COL, foam * fade * 0.85 * k);
        }
    }

    // ---- spray: crisp droplets arc out of the breaking lip and fall ---------
    if (s > 4.0 && s < 7.2 && abs(p.x - b.xc) < 0.5 && p.y < 0.36) {
        float sp = 0.0;
        for (int j = 0; j < DROPS; j++) {
            float fj = float(j);
            float hj = hash1(fj * 3.1 + seed);
            float tb = 4.2 + 0.7 * hj;                           // staggered birth
            float tau = s - tb;
            if (tau < 0.0 || tau > 1.5) continue;
            Big bt = bigAt(tb, xs, hm);
            vec2 o = tipOf(bt) + vec2(0.04 * hash1(fj + seed * 2.0), 0.02);
            vec2 v = vec2(-0.05 - 0.22 * hash1(fj * 5.3 + seed), 0.12 + 0.28 * hash1(fj * 7.7 + seed));
            vec2 pos = o + v * tau + vec2(0.0, -0.45) * tau * tau;
            float rad = (0.0028 + 0.0040 * hash1(fj * 9.1 + seed)) * (1.0 - tau / 1.6);
            float dd = length(p - pos) - rad;
            sp = max(sp, smoothstep(px, -px, dd) * step(B0 - 0.02, pos.y));
        }
        rgb = mix(rgb, FOAM_COL, sp * 0.9 * k);
    }

    // ---- front row: deepest blue, closest to us ------------------------------
    {
        float d = rowD(p, 0.035, 0.032, 7.0, 2.0, 0.6);
        float fill = smoothstep(0.8 * px, -0.8 * px, d);
        float a = fill * mix(0.66, 0.40, smoothstep(0.0, 0.05, -d));
        rgb = mix(rgb, NEAR_COL, a * k);
        float l2 = 1.0 - smoothstep(0.4 * px, 1.2 * px, abs(d + 0.010));
        rgb = mix(rgb, LINE_COL, l2 * fill * 0.22 * k);
        // Whitecaps: a scalloped cap of foam on the tallest crests.
        float t = iTime * ROLL;
        float c = crest(7.0 * p.x + 2.0 * t + 0.6, 1.8);
        float capT = 0.007 * smoothstep(0.75, 1.0, c) * (0.75 + 0.25 * sin(p.x * 420.0));
        float cap = fill * smoothstep(-capT - px, -capT + px, d);
        float line = 1.0 - smoothstep(0.6 * px, 1.6 * px, abs(d));
        rgb = mix(rgb, LINE_COL, line * 0.7 * k);
        rgb = mix(rgb, FOAM_COL, cap * 0.85 * k);
    }

    fragColor = vec4(rgb, base.a);
}
