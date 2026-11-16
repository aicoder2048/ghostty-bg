// ladybugs — glossy ladybugs crawl along the bottom and right edges; now and then one splits its shell, buzzes its wings and flies off while another lands.
// zh: 瓢虫
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.92;   // overall strength (0 = off)
const float SIZE      = 0.060;  // ladybug body length, in window heights
const int   COUNT     = 5;      // ladybugs on screen (one cycle slot each)
const float CYCLE     = 24.0;   // seconds per slot: fly in, crawl, take off (slots are staggered)
const float WALK      = 0.045;  // average crawling speed while striding, window heights per second
const float STRIDE    = 0.42;   // body lengths covered per leg cycle
const float EDGE      = 0.040;  // track distance from the window edges, in window heights
const float TOP       = 0.60;   // how far up the right edge they crawl (window heights)

const float PI   = 3.14159265;
const float FLY  = 3.0;         // fly-in time
const float LAND = 4.4;         // wings folded, shell closed, start crawling
const float TAKE = 19.0;        // shell starts to open
const float LIFT = 1.5;         // after TAKE: lift off
const float OUT  = 3.5;         // fly-out time (LIFT + OUT = CYCLE - TAKE)

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float wrapA(float a) { return mod(a + PI, 2.0 * PI) - PI; }
float mixA(float a, float b, float k) { return a + wrapA(b - a) * k; }

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// ---------------------------------------------------------------- the track
// An L-shaped path: along the bottom, round the corner, up the right edge.
const float X0 = 0.10;   // start of the track, in window widths
const float RC = 0.10;   // corner radius

float trackLen(float aspect) {
    return (aspect - EDGE - RC - X0 * aspect) + RC * PI * 0.5 + (TOP - EDGE - RC);
}

void track(float s, float aspect, out vec2 pos, out vec2 tang) {
    float xr = aspect - EDGE;
    float lb = xr - RC - X0 * aspect;
    float la = RC * PI * 0.5;
    if (s < lb) {
        pos = vec2(X0 * aspect + s, EDGE);  tang = vec2(1.0, 0.0);
    } else if (s < lb + la) {
        float a = (s - lb) / RC;
        pos = vec2(xr - RC, EDGE + RC) + RC * vec2(sin(a), -cos(a));
        tang = vec2(cos(a), sin(a));
    } else {
        pos = vec2(xr, EDGE + RC + s - lb - la);  tang = vec2(0.0, 1.0);
    }
}

// Position and heading of a crawler at distance s along the track. It weaves a
// little to the side (always tied to s, so it only turns while it moves).
void walker(float s, float dir, float seed, float aspect, out vec2 pos, out float head) {
    vec2 P, T;
    track(s, aspect, P, T);
    vec2 N = vec2(-T.y, T.x);                       // into the window
    float a1 = s * 9.0 + seed, a2 = s * 23.0 + seed * 1.7;
    float l  = 0.012 * (1.0 + 0.6 * sin(a1) + 0.4 * sin(a2));
    float dl = 0.012 * (5.4 * cos(a1) + 9.2 * cos(a2));
    pos = P + N * l;
    vec2 v = (T + N * dl) * dir;
    head = atan(v.y, v.x);
}

// Distance walked after t seconds: stride for 65% of each period with a
// smooth start and stop (velocity 1 - cos), then pause.
float walkDist(float t, float per, float d) {
    float x = clamp(fract(t / per) / 0.65, 0.0, 1.0);
    return d * (floor(t / per) + x - sin(2.0 * PI * x) / (2.0 * PI));
}

// An off-screen point to fly to/from, and the control point of a gentle arc.
void flightEnds(vec2 P, float h, float aspect, out vec2 far, out vec2 ctrl) {
    if (P.x > aspect - 0.2 || (P.x > aspect * 0.55 && h < 0.5)) {
        far  = vec2(aspect + 0.14, clamp(P.y + 0.12 + 0.30 * h, 0.15, 0.85));
        ctrl = mix(P, far, 0.5) + vec2(-0.16, 0.20);
    } else {
        // Swoop sideways and out past the bottom edge (mostly to the right).
        float side = h < 0.75 ? 1.0 : -1.0;
        far  = vec2(P.x + side * (0.35 + 0.3 * h), -0.14);
        ctrl = mix(P, far, 0.5) + vec2(0.0, 0.26);
    }
}

vec2 bez(vec2 a, vec2 c, vec2 b, float t)  { float m = 1.0 - t; return m * m * a + 2.0 * m * t * c + t * t * b; }
vec2 bezD(vec2 a, vec2 c, vec2 b, float t) { return 2.0 * (1.0 - t) * (c - a) + 2.0 * t * (b - c); }

// ---------------------------------------------------------------- drawing
const vec3 BLACK = vec3(0.075, 0.07, 0.075);
const vec3 SHEEN = vec3(0.42, 0.40, 0.40);   // thin light rim so black parts read on dark themes
const vec3 LEGC  = vec3(0.30, 0.28, 0.28);
const vec2 EC    = vec2(-0.10, 0.0);         // elytra dome centre
const vec2 ER    = vec2(0.40, 0.37);         // elytra dome radii

// Spots on the left elytron (mirrored on the right), most important first.
vec3 spotAt(int k) {
    if (k == 0) return vec3(-0.10, 0.19, 0.072);
    if (k == 1) return vec3( 0.09, 0.17, 0.060);
    if (k == 2) return vec3(-0.31, 0.15, 0.058);
    if (k == 3) return vec3(-0.06, 0.31, 0.050);
    if (k == 4) return vec3( 0.13, 0.29, 0.045);
    return vec3(-0.37, 0.04, 0.045);
}

// A ladybug from above, facing +x, about 1 unit long. Returns premultiplied colour.
vec4 ladybug(vec2 q, float px, float phase, float open, float wing, float tuck,
             float buzz, float twitch, vec2 light, vec3 red, int nSpots, bool scut) {
    vec4 acc = vec4(0.0);

    // Six legs, mostly hidden under the shell: tripod gait (L1 R2 L3 vs R1 L2 R3).
    // A planted foot slides back; a lifted one swings forward, pulled in a little.
    float dl = 1e3;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        for (int j = 0; j < 2; j++) {
            float s = j == 0 ? 1.0 : -1.0;
            float ph = phase + mod(fi + float(j), 2.0) * PI;
            vec2 hip = vec2(0.16 - 0.15 * fi, 0.12 * s);
            vec2 foot = vec2(hip.x + 0.14 - 0.14 * fi + 0.07 * sin(ph),
                             s * (0.52 - 0.05 * max(cos(ph), 0.0) - 0.04 * abs(fi - 1.0)));
            foot = mix(foot, hip + vec2(-0.05, 0.24 * s), tuck);
            vec2 knee = vec2(mix(hip.x, foot.x, 0.35), s * mix(0.42, 0.22, tuck));
            dl = min(dl, min(segment(q, hip, knee), segment(q, knee, foot)));
        }
    }
    over(acc, LEGC, smoothstep(px, -px, dl - max(0.022, 0.5 * px)) * 0.9);

    // Abdomen, only seen while the shell is open.
    if (open > 0.01) {
        float d = ellipse(q, vec2(-0.10, 0.0), vec2(0.32, 0.23));
        float rings = smoothstep(0.6, 1.0, 0.5 + 0.5 * cos(q.x * 48.0)) * smoothstep(0.0, -0.08, d);
        over(acc, mix(BLACK, vec3(0.24, 0.20, 0.17), rings * 0.35), smoothstep(px, -px, d));
    }

    // Hind wings: unfold from under the shell, then buzz.
    if (wing > 0.01) {
        for (int j = 0; j < 2; j++) {
            float s = j == 0 ? 1.0 : -1.0;
            float ang = s * (mix(PI - 0.25, PI * 0.5 + 0.40, wing) + buzz);
            float len = mix(0.40, 0.98, wing);
            vec2 base = vec2(0.15, 0.06 * s);
            vec2 w = rot(q - base, -ang);
            w.y *= s;                                    // leading edge on +y for both
            float dw = ellipse(w, vec2(len * 0.5, -0.01), vec2(len * 0.5, 0.15));
            dw = max(dw, -w.x);
            float memb = smoothstep(px, -px, dw);
            float dv = min(segment(w, vec2(0.02, 0.10), vec2(len * 0.92, 0.07)),
                           segment(w, vec2(0.03, 0.01), vec2(len * 0.75, -0.06)));
            dv = min(dv, segment(w, vec2(len * 0.32, 0.10), vec2(len * 0.55, -0.04)));
            dv = min(dv, segment(w, vec2(len * 0.55, -0.04), vec2(len * 0.80, -0.11)));
            float vein = smoothstep(px, -px, dv - 0.004) * memb;
            float edge = smoothstep(px, -px, abs(dw) - 0.004);
            float a = smoothstep(0.0, 0.4, wing);
            over(acc, vec3(0.86, 0.88, 0.92), memb * 0.30 * a);
            over(acc, vec3(0.95, 0.94, 0.90), edge * 0.35 * a);
            over(acc, vec3(0.42, 0.30, 0.20), vein * 0.75 * a);
        }
    }

    // Head with two small white cheek spots, and short clubbed antennae.
    float da = 1e3;
    for (int j = 0; j < 2; j++) {
        float s = j == 0 ? 1.0 : -1.0;
        vec2 tip = vec2(0.53, 0.125 * s) + 0.012 * vec2(twitch, s * twitch);
        da = min(da, segment(q, vec2(0.44, 0.06 * s), tip) - max(0.011, 0.45 * px));
        da = min(da, length(q - tip) - 0.022);
    }
    over(acc, LEGC, smoothstep(px, -px, da));
    vec2 qa = vec2(q.x, abs(q.y));
    float dh = ellipse(q, vec2(0.40, 0.0), vec2(0.075, 0.13));
    over(acc, mix(BLACK, SHEEN, smoothstep(-2.0 * px, 0.0, dh)), smoothstep(px, -px, dh));
    over(acc, vec3(0.93, 0.92, 0.88), smoothstep(px, -px, length(qa - vec2(0.43, 0.07)) - 0.026));

    // Pronotum: black with white front corners and a small gloss.
    float dp = ellipse(q, vec2(0.27, 0.0), vec2(0.12, 0.25));
    vec3 pc = mix(BLACK, SHEEN, smoothstep(-2.0 * px, 0.0, dp));
    pc = mix(pc, vec3(0.93, 0.92, 0.88), smoothstep(px, -px, ellipse(qa, vec2(0.31, 0.165), vec2(0.055, 0.068))));
    over(acc, pc, smoothstep(px, -px, dp));

    // The two elytra. Opening: each swings its rear outward about a front hinge
    // and looks narrower as it tilts up.
    for (int j = 0; j < 2; j++) {
        float s = j == 0 ? 1.0 : -1.0;
        vec2 H = vec2(0.22, 0.02 * s);
        vec2 e = rot(q - H, s * open * 0.72) + H;
        e.y = H.y + (e.y - H.y) / (1.0 - 0.42 * open);
        float de = max(ellipse(e, EC, ER), -s * e.y);
        float cov = smoothstep(px, -px, de);
        if (cov <= 0.0) continue;

        // Glossy dome: darker towards the rim, lit from the light side.
        vec2 n = (e - EC) / ER;
        float r2 = dot(n, n);
        vec3 col = red * (0.50 + 0.50 * (1.0 - r2)) * (0.86 + 0.26 * dot(n, light));
        col *= 1.0 - 0.38 * smoothstep(-0.05, 0.0, de);         // darker rim band
        col = mix(col, red * 0.32, smoothstep(px, -px, abs(e.y) - 0.007) * (1.0 - open)); // seam

        // Spots (symmetric), plus the shared scutellar spot at the front.
        vec2 m = vec2(e.x, s * e.y);
        float ds = 1e3;
        for (int k = 0; k < 6; k++) {
            if (k >= nSpots) break;
            vec3 sp = spotAt(k);
            float rr = sp.z * (nSpots <= 2 ? 1.35 : 1.0);
            ds = min(ds, length(m - sp.xy) - rr);
        }
        if (scut) ds = min(ds, length(m - vec2(0.17, 0.0)) - 0.07);
        col = mix(col, BLACK * (0.7 + 0.5 * (1.0 - r2)), smoothstep(px, -px, ds));

        // Crisp highlight: a short arc on the lit side, plus a tiny glint.
        float la = atan(light.y, light.x);
        vec2 hq = rot(e - (EC + light * vec2(0.22, 0.20)), -la);
        float hl = smoothstep(px, -px, ellipse(hq, vec2(0.0), vec2(0.035, 0.12)));
        float gl = smoothstep(px, -px, length(e - (EC + light * 0.07 + vec2(-light.y, light.x) * 0.10)) - 0.022);
        col = mix(col, vec3(1.0, 0.97, 0.92), max(hl * 0.80, gl * 0.55));

        over(acc, col, cov);
    }
    return acc;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 rgb = base.rgb;
    float L = trackLen(aspect);
    vec2 lightS = normalize(vec2(-0.55, 0.83));              // light from the top left

    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        // Staggered slots: every CYCLE/COUNT seconds one leaves and one arrives.
        float u0 = iTime + fi * CYCLE / float(COUNT) + 5.5;
        float cyc = floor(u0 / CYCLE);
        float u = u0 - cyc * CYCLE;
        float seed = fi * 7.13 + cyc * 3.71;
        float h1 = hash1(seed), h2 = hash1(seed + 1.3), h3 = hash1(seed + 2.9);
        float h4 = hash1(seed + 4.1), h5 = hash1(seed + 5.7), h6 = hash1(seed + 6.3);

        // Where it lands and how far it will crawl (always staying on the track).
        float dir = h2 < 0.7 ? 1.0 : -1.0;
        float per = 2.6 + 1.4 * h3;
        float dStep = WALK * per * 0.65;
        float dTot = walkDist(TAKE - LAND, per, dStep);
        // Each slot crawls around its own stretch of the track so they rarely pile up.
        float mid = L * (fi + 0.3 + 0.4 * h1) / float(COUNT);
        float sLand = clamp(mid - dir * 0.5 * dTot, 0.03 + max(-dir, 0.0) * dTot,
                            L - 0.03 - max(dir, 0.0) * dTot);
        float dist = walkDist(clamp(u - LAND, 0.0, TAKE - LAND), per, dStep);

        vec2 pos; float head;
        walker(sLand + dir * dist, dir, seed, aspect, pos, head);

        float scale = 1.0, open = 0.0, wing = 0.0, tuck = 0.0, alt = 0.0;
        float phase = dist / (STRIDE * SIZE) * 2.0 * PI + 7.0;   // +7: matches the touch-down shuffle
        if (u < LAND) {
            // Fly in along an arc, touch down, turn to the crawl heading, fold up.
            vec2 far, ctrl;
            flightEnds(pos, h4, aspect, far, ctrl);
            float x = clamp(u / FLY, 0.0, 1.0);
            float t = 1.0 - (1.0 - x) * (1.0 - x);
            vec2 fd = bezD(far, ctrl, pos, t);
            float turn = smoothstep(FLY, LAND, u);
            head = mixA(atan(fd.y, fd.x), head, turn);
            phase += (turn - 1.0) * 7.0;                     // legs shuffle while it turns
            pos = bez(far, ctrl, pos, t);
            alt = 1.0 - t;
            wing = 1.0 - smoothstep(FLY + 0.05, FLY + 0.75, u);
            open = 1.0 - smoothstep(FLY + 0.55, FLY + 1.3, u);
            tuck = 1.0 - smoothstep(FLY - 0.6, FLY, u);
        } else if (u > TAKE) {
            // Split the shell, unfold and buzz the wings, turn, and lift off.
            float k = u - TAKE;
            vec2 far, ctrl;
            flightEnds(pos, h5, aspect, far, ctrl);
            float x = clamp((k - LIFT) / OUT, 0.0, 1.0);
            float t = x * x;
            vec2 fd = bezD(pos, ctrl, far, t);
            float turn = smoothstep(0.3, LIFT, k);
            head = mixA(head, atan(fd.y, fd.x), turn);
            phase += turn * 7.0;
            pos = bez(pos, ctrl, far, t);
            alt = t;
            open = smoothstep(0.0, 0.6, k);
            wing = smoothstep(0.35, 1.1, k);
            tuck = smoothstep(LIFT - 0.2, LIFT + 0.4, k);
        }
        scale = 1.0 + 0.35 * alt;

        // Cheap reject: this pixel is nowhere near this ladybug or its shadow.
        vec2 sOff = vec2(0.10, -0.14) * SIZE * (1.0 + 8.0 * alt);
        if (length(p - pos - 0.5 * sOff) > 1.3 * SIZE * scale + length(sOff)) continue;

        float unit = SIZE * scale;
        float px = 1.0 / (iResolution.y * unit);

        // Soft-edged contact shadow; it slides away and fades as the bug climbs.
        vec2 qs = rot(p - pos - sOff, -head) / unit;
        float sh = smoothstep(2.5 * px, -2.5 * px, ellipse(qs, vec2(-0.02, 0.0), vec2(0.50, 0.42)));
        rgb *= 1.0 - sh * 0.30 * (1.0 - 0.75 * alt) * INTENSITY;

        vec2 q = rot(p - pos, -head) / unit;
        float buzz = wing > 0.5 ? 0.28 * sin(iTime * 57.0 + fi * 2.3) : 0.0;
        float twitch = sin(iTime * 2.3 + fi * 4.0) * (0.5 + 0.5 * sin(iTime * 0.7 + fi));
        vec3 red = mix(vec3(0.80, 0.10, 0.07), vec3(0.88, 0.30, 0.06), h6 * h6);
        int nSpots = h3 < 0.25 ? 1 : (h3 < 0.55 ? 3 : (h3 < 0.8 ? 5 : 6));
        bool scut = hash1(seed + 8.8) < 0.6 && nSpots != 1;
        vec4 bug = ladybug(q, px, phase, open, wing, tuck, buzz, twitch,
                           rot(lightS, -head), red, nSpots, scut);
        rgb = rgb * (1.0 - bug.a * INTENSITY) + bug.rgb * INTENSITY;
    }

    fragColor = vec4(rgb, base.a);
}
