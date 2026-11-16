// fish — a silver bait ball swirls and bolts mid-right while big reef fish swim past in front.
// zh: 鱼群
// group: ocean
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY  = 0.90;   // overall strength (0 = off)
const float SCHOOL     = 0.60;   // brightness of the little silver fish
const float BALL_R     = 0.20;   // bait-ball radius in window heights
const float BOLT_EVERY = 8.0;    // seconds between two bolts of the school
const float BOLT_TIME  = 2.6;    // seconds one bolt (turn, stream off, regroup) takes
const float CELL       = 0.028;  // spacing of the little fish in window heights
const float SPIN       = 0.55;   // how fast the ball turns (radians per second)
const float TEXT_FADE  = 0.55;   // how much the big fish fade over the top-left text

const float PI = 3.14159265;

// The three big fish: 0 = blue tang, 1 = Moorish idol, 2 = clownfish.
// Each swims x = CX + AMP * sin(phase), so it slows, turns and comes back.
const float F_CX[3]    = float[3](0.50, 0.55, 0.62);     // path centre (fraction of width)
const float F_AMP[3]   = float[3](0.74, 0.70, 0.20);     // path half width (fraction of width)
const float F_PER[3]   = float[3](30.0, 38.0, 17.0);     // seconds for one back-and-forth
const float F_PH0[3]   = float[3](-0.35, 2.68, -0.45);   // where each starts (all in view)
const float F_Y[3]     = float[3](0.27, 0.41, 0.13);     // swimming height (window heights)
const float F_SIZE[3]  = float[3](0.100, 0.096, 0.088);  // half body length (window heights)
const float F_BEAT[3]  = float[3](1.6, 1.2, 2.4);        // tail beats per second

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec2 rot2(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Signed distance to an ellipse (good approximation, also near the tips).
float sdEllipse(vec2 p, vec2 c, vec2 r) {
    vec2 d = p - c;
    float k0 = length(d / r);
    float k1 = length(d / (r * r)) + 1e-5;
    return k0 * (k0 - 1.0) / k1;
}

float sdSeg(vec2 p, vec2 a, vec2 b, out float h) {
    vec2 pa = p - a, ba = b - a;
    h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float sdTri(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Paint colour c with coverage a over the premultiplied colour acc.
void over(inout vec4 acc, vec3 c, float a) {
    acc = vec4(c * a, a) + acc * (1.0 - a);
}

float fill(float d, float px) { return smoothstep(px, -px, d); }

// ---------------------------------------------------------------------------
// Big fish. All face +x with the snout near x = 1 (fish units = half length).
// A fish seen from the side beats its tail toward and away from us, so the
// tail fin is foreshortened and catches the light, and the rear body only
// flexes a little; the pectoral fins row on their own rhythm.

float bendAt(float x, float amp) {
    float k = clamp((0.2 - x) / 1.2, 0.0, 1.5);
    return amp * k * k;
}

// Tail-fin space: origin at the tail root, x forward along the spine there.
vec2 tailSpace(vec2 q, float xr, float amp, float ph) {
    float y0 = bendAt(xr, amp), y1 = bendAt(xr + 0.02, amp);
    vec2 a = normalize(vec2(0.02, y1 - y0));
    vec2 t = q - vec2(xr, y0);
    t = vec2(dot(t, a), dot(t, vec2(-a.y, a.x)));
    t.x /= cos(0.8 * sin(ph));                       // swept toward us: looks shorter
    t.y -= 0.35 * cos(ph) * t.x * t.x;               // the fin flexes behind the stroke
    return t;
}

void drawEye(inout vec4 acc, vec2 b, vec2 c, float r, vec3 iris, float px) {
    vec2 e = b - c;
    float d = length(e);
    over(acc, vec3(0.02), fill(d - r, px));
    over(acc, mix(iris, iris * 0.45, smoothstep(-r, r, e.y)), fill(d - r * 0.78, px));
    over(acc, vec3(0.01), fill(d - r * 0.46, px));
    over(acc, vec3(1.0), fill(length(e - r * vec2(0.30, 0.32)) - r * 0.22, px));
    over(acc, vec3(1.0), 0.7 * fill(length(e - r * vec2(-0.22, -0.30)) - r * 0.09, px));
}

// Body shading: darker toward the outline (roundness), lit from above, and a
// soft sheen along the upper flank.
vec3 shade(vec3 c, float dIn, float y, float top) {
    c *= mix(0.62, 1.0, smoothstep(0.0, 0.14, -dIn));
    c *= mix(0.80, 1.08, smoothstep(-top, top, y));
    return c + 0.16 * exp(-pow((y - top * 0.45) / (top * 0.22), 2.0)) * smoothstep(0.02, 0.1, -dIn);
}

// Fin colour with dark rays.
vec3 rays(vec3 c, vec2 t, float n) {
    return c * (0.86 + 0.14 * smoothstep(-0.4, 0.6, sin(atan(t.y, t.x) * n)));
}

vec4 drawClown(vec2 q, float ph, float pf, float px) {
    const vec3 ORANGE = vec3(1.00, 0.45, 0.06);
    const vec3 WHITE  = vec3(0.99, 0.98, 0.96);
    const vec3 BLACK  = vec3(0.03, 0.02, 0.02);
    float amp = 0.04 * sin(ph);
    vec2 b = vec2(q.x, q.y - bendAt(q.x, amp));
    float h;

    float dB = sdEllipse(b, vec2(0.12, 0.0), vec2(0.88, b.y > 0.0 ? 0.40 : 0.43));
    float dP = sdSeg(b, vec2(-0.35, 0.0), vec2(-0.66, 0.0), h) - mix(0.17, 0.11, h);
    dB = smin(dB, dP, 0.08);

    vec2 t = tailSpace(q, -0.64, amp, ph);
    float dT = max(sdEllipse(t, vec2(-0.25, 0.0), vec2(0.28, 0.31)), t.x - 0.02);
    float dD = min(sdEllipse(b, vec2(-0.26, 0.36), vec2(0.30, 0.22)),
                   sdEllipse(b, vec2(0.14, 0.37), vec2(0.22, 0.12)));
    dD = max(dD, 0.12 - b.y);
    float dA = max(sdEllipse(b, vec2(-0.26, -0.40), vec2(0.20, 0.18)), b.y + 0.12);
    vec2 pv = rot2(b - vec2(0.30, -0.33), -0.9);
    float dV = sdEllipse(pv, vec2(0.11, 0.0), vec2(0.13, 0.05));
    float pa = PI + 0.75 + 0.35 * sin(pf);
    vec2 pc = rot2(b - vec2(0.42, -0.07), -pa);
    float dC = sdEllipse(pc, vec2(0.15, 0.0), vec2(0.17, 0.075 * (0.75 + 0.25 * cos(pf))));

    // White bands, each edged in black: behind the eye, mid-body (pointing
    // forward), and round the tail root. The mid band runs into the dorsal fin.
    float b1 = abs(b.x - (0.47 - 0.6 * b.y * b.y)) - 0.075;
    float b2 = abs(b.x - (-0.10 + 0.12 * max(0.0, 1.0 - abs(b.y) / 0.3))) - 0.08;
    float b3 = abs(b.x + 0.60) - 0.055;
    float band = min(min(b1, b2), b3);

    vec4 acc = vec4(0.0);
    float dAll = min(min(dB, dT), min(min(dD, dA), dV));
    over(acc, BLACK, fill(dAll - 1.5 * px, px));                     // crisp outline

    // Fins: orange, rayed, with a black margin.
    vec3 fc = rays(ORANGE * 0.95, t + vec2(0.05, 0.0), 22.0) * (0.85 + 0.15 * sin(ph));
    over(acc, mix(fc, BLACK, smoothstep(-0.075, -0.055, dT)), fill(dT, px));
    vec3 dc = mix(ORANGE, WHITE, fill(b2, px) * 0.9);
    over(acc, mix(dc, BLACK, smoothstep(-0.06, -0.045, dD)), fill(dD, px));
    over(acc, mix(ORANGE * 0.95, BLACK, smoothstep(-0.06, -0.045, dA)), fill(dA, px));

    vec3 bc = mix(ORANGE, BLACK, fill(band - 0.035, px));
    bc = mix(bc, WHITE, fill(band, px));
    over(acc, shade(bc, dB, b.y, 0.40), fill(dB, px));

    // Mouth and gill line.
    float m = sdSeg(b, vec2(0.99, -0.07), vec2(0.88, -0.11), h);
    over(acc, BLACK, 0.8 * fill(m - 0.012, px));

    over(acc, mix(ORANGE, BLACK, smoothstep(-0.05, -0.03, dV)), 0.95 * fill(dV, px));
    over(acc, mix(ORANGE * 1.05, BLACK, smoothstep(-0.035, -0.02, dC)), 0.8 * fill(dC, px));
    drawEye(acc, b, vec2(0.71, 0.10), 0.085, vec3(1.0, 0.55, 0.10), px);
    return acc;
}

vec4 drawIdol(vec2 q, float ph, float pf, float px) {
    const vec3 WHITE  = vec3(0.98, 0.97, 0.90);
    const vec3 YELLOW = vec3(1.00, 0.82, 0.12);
    const vec3 BLACK  = vec3(0.03, 0.03, 0.04);
    const vec3 ORANGE = vec3(1.00, 0.55, 0.12);
    float amp = 0.03 * sin(ph);
    vec2 b = vec2(q.x, q.y - bendAt(q.x, amp));
    float h;

    // Tall disc body, tube snout, thin tail root.
    float dB = sdEllipse(b, vec2(0.0, 0.0), vec2(0.55, 0.58));
    float dS = sdSeg(b, vec2(0.30, -0.02), vec2(0.90, -0.12), h) - mix(0.16, 0.045, sqrt(h));
    dB = smin(dB, dS, 0.10);
    dB = smin(dB, sdSeg(b, vec2(-0.3, 0.0), vec2(-0.62, 0.0), h) - mix(0.17, 0.07, h), 0.08);

    // Sweeping dorsal and anal fins; the dorsal ends in a long white streamer.
    float dD = sdTri(b, vec2(-0.40, 0.40), vec2(0.24, 0.42), vec2(-0.02, 1.02));
    dD = max(dD, -sdEllipse(b, vec2(-0.52, 0.92), vec2(0.36, 0.42)));   // hollow trailing edge
    float dA = sdTri(b, vec2(-0.40, -0.40), vec2(0.18, -0.44), vec2(-0.16, -0.94));
    dA = max(dA, -sdEllipse(b, vec2(-0.55, -0.86), vec2(0.34, 0.38)));
    float dF = 1e3;
    vec2 a0 = vec2(-0.02, 1.0);
    for (int i = 1; i < 4; i++) {
        float fi = float(i);
        vec2 a1 = vec2(-0.02 - 0.38 * fi, 1.0 + 0.16 * fi - 0.065 * fi * fi)
                + vec2(0.0, 0.05 * fi * sin(ph * 0.5 - fi * 0.9));
        float d = sdSeg(b, a0, a1, h) - mix(0.032, 0.008, (fi - 1.0 + h) / 3.0);
        dF = min(dF, d);
        a0 = a1;
    }
    vec2 t = tailSpace(q, -0.62, amp, ph);
    float dT = max(sdEllipse(t, vec2(-0.19, 0.0), vec2(0.21, 0.26)), t.x - 0.02);
    dT = max(dT, -sdEllipse(t, vec2(-0.56, 0.0), vec2(0.18, 0.20)));   // shallow notch
    float pa = PI + 0.6 + 0.3 * sin(pf);
    vec2 pc = rot2(b - vec2(0.18, -0.10), -pa);
    float dC = sdEllipse(pc, vec2(0.13, 0.0), vec2(0.14, 0.06 * (0.75 + 0.25 * cos(pf))));

    // Pattern: white face, black band through the eye, pale-yellow middle,
    // broad black band (running into both fins), yellow rear, black tail.
    float band1 = abs(b.x - (0.27 - 0.25 * b.y)) - 0.12;
    float band2 = abs(b.x - (-0.22 - 0.12 * b.y)) - 0.14;
    vec3 c = mix(WHITE, YELLOW, smoothstep(0.15, 0.45, b.y) * step(b.x, 0.25));
    c = mix(c, YELLOW, smoothstep(-0.34, -0.40, b.x));
    c = mix(c, WHITE, fill(abs(b.x + 0.50) - 0.018, px));
    c = mix(c, ORANGE, fill(sdEllipse(b, vec2(0.56, 0.04), vec2(0.13, 0.06)), px));
    c = mix(c, BLACK, max(fill(band1, px), fill(band2, px)));

    vec4 acc = vec4(0.0);
    float dAll = min(min(dB, dT), min(dD, dA));
    over(acc, BLACK, fill(dAll - 1.5 * px, px));
    vec3 tc = mix(BLACK, WHITE, smoothstep(-0.07, -0.04, dT) * smoothstep(-0.26, -0.34, t.x));   // white rear margin only
    over(acc, tc, fill(dT, px));
    vec3 fc = mix(mix(WHITE, YELLOW, 0.35), BLACK, fill(band2, px));
    over(acc, rays(fc, b - vec2(-0.1, 0.4), 30.0), fill(dD, px));
    over(acc, rays(fc, b - vec2(-0.1, -0.4), 30.0), fill(dA, px));
    over(acc, WHITE, 0.95 * fill(dF, px));
    over(acc, shade(c, dB, b.y, 0.58), fill(dB, px));
    over(acc, mix(vec3(0.95, 0.92, 0.8), BLACK, smoothstep(-0.03, -0.015, dC)), 0.6 * fill(dC, px));
    over(acc, BLACK, 0.8 * fill(sdSeg(b, vec2(0.93, -0.12), vec2(0.86, -0.135), h) - 0.012, px));
    drawEye(acc, b, vec2(0.30, 0.13), 0.065, vec3(0.95, 0.80, 0.25), px);
    return acc;
}

vec4 drawTang(vec2 q, float ph, float pf, float px) {
    const vec3 BLUE   = vec3(0.10, 0.38, 1.00);
    const vec3 YELLOW = vec3(1.00, 0.84, 0.10);
    const vec3 BLACK  = vec3(0.02, 0.03, 0.08);
    float amp = 0.045 * sin(ph);
    vec2 b = vec2(q.x, q.y - bendAt(q.x, amp));
    float h;

    float dB = sdEllipse(b, vec2(0.05, 0.0), vec2(0.82, b.y > 0.0 ? 0.46 : 0.48));
    dB = smin(dB, sdSeg(b, vec2(-0.5, 0.0), vec2(-0.80, 0.0), h) - mix(0.19, 0.09, h), 0.08);

    // Long dorsal and anal fins hugging the back and belly.
    float dD = max(sdEllipse(b, vec2(-0.02, 0.0), vec2(0.80, 0.64)), max(b.x - 0.45, -0.68 - b.x));
    dD = max(dD, -b.y);
    float dA = max(sdEllipse(b, vec2(-0.04, 0.0), vec2(0.76, 0.58)), max(b.x - 0.12, -0.64 - b.x));
    dA = max(dA, b.y);
    // Crescent tail.
    vec2 t = tailSpace(q, -0.80, amp, ph);
    float dT = max(sdEllipse(t, vec2(-0.20, 0.0), vec2(0.25, 0.36)), t.x - 0.02);
    dT = max(dT, -sdEllipse(t, vec2(-0.50, 0.0), vec2(0.22, 0.27)));
    float pa = PI + 0.55 + 0.35 * sin(pf);
    vec2 pc = rot2(b - vec2(0.40, -0.10), -pa);
    float dC = sdEllipse(pc, vec2(0.16, 0.0), vec2(0.18, 0.075 * (0.75 + 0.25 * cos(pf))));

    // Royal blue with the black "palette" mark (and its blue window) along
    // the upper flank, running back to the tail; yellow tail root and tail.
    vec3 c = mix(BLUE * 1.15 + vec3(0.03, 0.06, 0.0), BLUE * 0.8, smoothstep(-0.4, 0.3, b.y));
    float pal = sdEllipse(b, vec2(-0.06, 0.13), vec2(0.62, 0.24));
    pal = min(pal, sdSeg(b, vec2(-0.5, 0.08), vec2(-0.80, 0.0), h) - 0.06);
    pal = min(pal, sdSeg(b, vec2(0.62, 0.12), vec2(0.40, 0.26), h) - 0.07);
    float win = sdEllipse(b, vec2(-0.16, 0.11), vec2(0.30, 0.08));
    c = mix(c, BLACK, fill(max(pal, -win), px));
    float ytri = sdTri(b, vec2(-0.56, -0.02), vec2(-0.84, 0.06), vec2(-0.84, -0.10));
    c = mix(c, YELLOW, fill(ytri, px));

    vec4 acc = vec4(0.0);
    float dAll = min(min(dB, dT), min(dD, dA));
    over(acc, BLACK, fill(dAll - 1.5 * px, px));
    vec3 tc = mix(rays(YELLOW, t, 20.0), BLACK, smoothstep(0.17, 0.21, abs(t.y)));
    over(acc, tc * (0.85 + 0.15 * sin(ph)), fill(dT, px));
    over(acc, mix(BLUE * 0.85, BLACK, smoothstep(-0.07, -0.04, dD)), fill(dD, px));
    over(acc, mix(BLUE * 0.9, BLACK, smoothstep(-0.06, -0.035, dA)), fill(dA, px));
    over(acc, shade(c, dB, b.y, 0.46), fill(dB, px));
    over(acc, mix(YELLOW, BLUE, smoothstep(0.14, 0.02, pc.x)), 0.55 * fill(dC, px));
    over(acc, BLACK, 0.8 * fill(sdSeg(b, vec2(0.87, -0.05), vec2(0.80, -0.07), h) - 0.012, px));
    drawEye(acc, b, vec2(0.62, 0.10), 0.075, vec3(0.30, 0.55, 1.0), px);
    return acc;
}

// ---------------------------------------------------------------------------
// The bait ball. It rests at an anchor point, turning and breathing, then
// every BOLT_EVERY seconds the fish turn together and stream to the next one.

vec2 anchor(float k, float aspect) {
    float x = mod(k, 2.0) < 0.5 ? mix(0.52, 0.62, hash1(k * 7.31 + 1.0))
                                : mix(0.70, 0.78, hash1(k * 3.17 + 2.0));
    return vec2(x * aspect, mix(0.28, 0.46, hash1(k * 5.71 + 3.0)));
}

// One little silver fish facing +x in cell units (about 0.8 long).
float tinyFish(vec2 q, float pxg) {
    float body = sdEllipse(q, vec2(0.0), vec2(0.40, 0.11));
    float tx = -q.x - 0.33;
    float tail = max(abs(q.y) - 0.015 - tx * 0.6, max(-tx, tx - 0.18));
    return fill(min(body, tail), pxg);
}

vec3 blendSchool(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;
    vec3 rgb = base.rgb;

    // Keep the top-left (where the shell text is) calmer.
    float textZone = (1.0 - smoothstep(0.40, 0.65, uv.x)) * smoothstep(0.40, 0.56, p.y);

    // --- School state (same for every pixel) --------------------------------
    float k = floor(t / BOLT_EVERY);
    float u = clamp((mod(t, BOLT_EVERY) - (BOLT_EVERY - BOLT_TIME)) / BOLT_TIME, 0.0, 1.0);
    vec2 A0 = anchor(k, aspect), A1 = anchor(k + 1.0, aspect);
    vec2 D = normalize(A1 - A0);
    float bell = pow(sin(PI * u), 2.0);                       // 0 at rest, 1 mid-bolt
    vec2 C = mix(A0, A1, smoothstep(0.10, 0.85, u))
           + 0.025 * vec2(sin(t * 0.37), sin(t * 0.51 + 1.0));
    // The spin slows to a stop during a bolt; this is its exact running angle.
    float I = BOLT_TIME * (u * 0.5 - sin(2.0 * PI * u) / (4.0 * PI));
    float spin = SPIN * (t - k * BOLT_TIME * 0.5 - I);

    // --- Density of the school at this pixel -------------------------------
    vec2 l = p - C;
    float dens = 0.0;
    if (dot(l, l) < pow(BALL_R * (1.6 + 2.6 * bell), 2.0)) {
        // Resting shape: a lumpy ball that stretches, bends into a ribbon and breathes.
        float phi = t * 0.21;
        vec2 m = rot2(l, -phi);
        m.x /= 1.0 + 0.35 * sin(t * 0.29);
        m.y -= 2.2 * m.x * m.x * sin(t * 0.23);
        m = rot2(m, phi);
        // Bolting: long and thin along the run, snaking.
        float a = dot(m, D), c = dot(m, vec2(-D.y, D.x));
        a /= 1.0 + 1.5 * bell;
        c = c * (1.0 + 0.5 * bell) + 0.05 * bell * sin(a * 30.0 - t * 6.0);
        float ang = atan(c, a);
        float R = BALL_R * (1.0 + 0.09 * sin(t * 1.3))
                * (1.0 + 0.12 * sin(3.0 * ang + t * 0.9) + 0.07 * sin(5.0 * ang - t * 1.4));
        dens = 1.0 - smoothstep(0.55, 1.0, length(vec2(a, c)) / R);
        dens *= 0.80 + 0.20 * sin(l.x * 23.0 + t * 1.1) * sin(l.y * 19.0 - t * 0.8);
    }

    if (dens > 0.001) {
        rgb = blendSchool(rgb, vec3(0.45, 0.60, 0.75), 0.06 * dens * SCHOOL);   // faint mass
        for (int L = 0; L < 2; L++) {
            float fl = float(L);
            float cell = CELL * (1.0 - 0.24 * fl);
            float th = spin * (1.0 - 0.22 * fl) + fl * 1.3;      // the far layer lags a bit
            vec2 g = rot2(l, -th) / cell;                      // rotating frame, cell units
            vec2 Df = rot2(D, -th);
            float pxg = 1.0 / (iResolution.y * cell);
            vec2 g0 = floor(g - 0.5);
            float light = 0.0;
            for (int j = 0; j < 4; j++) {
                vec2 id = g0 + vec2(float(j & 1), float(j >> 1));
                float h1 = hash2(id + fl * 17.0), h2 = hash2(id * 1.7 + 3.1 + fl);
                vec2 fc = id + 0.5 + (vec2(h1, h2) - 0.5) * 0.7;
                // Heading: round the ball, plus a little personal wander...
                float ah = atan(fc.x, -fc.y) + 0.35 * sin(t * 1.3 + h1 * 6.28);
                // ...and on a bolt they all snap toward the run, the front first.
                float along = clamp(dot(fc * cell, D) / BALL_R, -1.0, 1.0);
                float tf = smoothstep(0.0, 0.10, u - 0.06 * (1.0 - along))
                         * (1.0 - smoothstep(0.72, 0.95, u));
                float ad = atan(Df.y, Df.x);
                ah += (mod(ad - ah + PI, 2.0 * PI) - PI) * tf;
                vec2 hd = vec2(cos(ah), sin(ah));
                fc += hd * 0.14 * sin(t * 2.3 + h2 * 6.28);    // darting back and forth
                vec2 d = g - fc;
                vec2 q = vec2(dot(d, hd), dot(d, vec2(-hd.y, hd.x))) / (0.85 + 0.3 * h2);
                float cov = tinyFish(q, pxg);
                if (cov <= 0.0) continue;
                // Sides flash silver when they face the light; a wave rolls
                // through the school, and everyone flashes as they turn.
                vec2 pw = C + rot2(fc * cell, th);
                float flash = pow(0.5 + 0.5 * cos(2.0 * (ah + th) - pw.x * 11.0 - pw.y * 6.0 + t * 2.4), 6.0);
                flash += 3.0 * tf * (1.0 - tf);
                float show = smoothstep(h1 - 0.12, h1 + 0.12, dens * 1.4);
                light += cov * show * (0.32 + 1.1 * flash);
            }
            vec3 silver = mix(vec3(0.55, 0.66, 0.78), vec3(1.0), clamp(light - 0.4, 0.0, 1.0));
            rgb = blendSchool(rgb, silver, light * SCHOOL * (1.0 - 0.4 * fl) * (1.0 - 0.4 * textZone));
        }
    }

    // --- Big reef fish in front ---------------------------------------------
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    for (int i = 0; i < 3; i++) {
        float ph = 2.0 * PI * t / F_PER[i] + F_PH0[i];
        float x = (F_CX[i] + F_AMP[i] * sin(ph)) * aspect;
        float cs = cos(ph);
        float face = cs / sqrt(cs * cs + 0.07);                // turns smoothly at each end
        float sx = sign(face) * max(abs(face), 0.12);
        float size = F_SIZE[i];
        float y = F_Y[i] + 0.035 * sin(t * 0.45 + float(i) * 2.0);
        float vy = 0.035 * 0.45 * cos(t * 0.45 + float(i) * 2.0);
        float vx = F_AMP[i] * aspect * 2.0 * PI / F_PER[i] * abs(cs) + 0.02;
        float tilt = clamp(vy / vx, -0.3, 0.3);                // nose follows the rise and fall

        vec2 q = (p - vec2(x, y)) / size;
        if (abs(q.x) > 1.6 || q.y < -1.2 || q.y > 1.35) continue;   // cheap bounds
        q = rot2(q, -tilt * sign(sx));
        q.x /= sx;                                             // face the way it swims (3D turn)
        if (q.x < -1.45 || q.x > 1.1) continue;

        float px = 1.2 / (iResolution.y * size * max(abs(sx), 0.3));
        float tb = 2.0 * PI * F_BEAT[i] * t + float(i) * 1.7;
        float pf = tb * 1.7 + 0.8;
        vec4 f;
        if (i == 0)      f = drawTang(q, tb, pf, px);
        else if (i == 1) f = drawIdol(q, tb, pf, px);
        else             f = drawClown(q, tb, pf, px);

        float k2 = INTENSITY * (1.0 - TEXT_FADE * textZone);
        vec3 c = lum > 0.5 ? f.rgb * 0.9 : f.rgb;
        rgb = rgb * (1.0 - f.a * k2) + c * k2;
    }

    fragColor = vec4(rgb, base.a);
}
