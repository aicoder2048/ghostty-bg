// crystals — amethyst and quartz crystals grow step by step in the lower right, charge with inner light, crack and shatter into spinning shards, then grow again.
// zh: 水晶
// group: fantasy
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float OPACITY   = 0.78;   // how solid the gem bodies look
const float HEIGHT    = 0.33;   // tallest crystal as a fraction of the window height
const float CLUSTER_X = 0.30;   // distance of the cluster root from the right edge (window heights)
const float CYCLE     = 12.0;   // seconds for one grow -> charge -> shatter cycle
const float GROW_DUR  = 2.6;    // seconds each crystal takes to reach full length
const float STEPS     = 5.0;    // growth happens in this many visible spurts
const float T_CHARGE  = 6.1;    // inner light starts rising from the base
const float T_CRACK   = 7.8;    // crack lines start to spread
const float T_SHATTER = 8.75;   // the crystals burst into shards
const int   SHARDS    = 36;     // flying shards per burst

const float PI = 3.14159265;

const vec3 AME_DEEP  = vec3(0.42, 0.20, 0.68);   // amethyst colour at the tips
const vec3 AME_PALE  = vec3(0.80, 0.74, 0.90);   // milky, nearly clear amethyst base
const vec3 QUARTZ    = vec3(0.82, 0.87, 0.93);   // clear quartz body
const vec3 CHARGE    = vec3(0.86, 0.70, 1.00);   // inner light colour

// Crystals in draw order (back to front). X: root offset (units of HEIGHT),
// A: lean (+ = leans left), L: length, W: half-width (units of HEIGHT),
// S: start time in the cycle, K: 0 amethyst / 1 clear quartz,
// P: parent crystal for side buds (-1 = grows from the ground), Y: where on the
// parent it buds (fraction of the parent's length), R: hexagon rotation.
const int N = 10;
const float CX[N] = float[N](-0.32,  0.30, -0.50,  0.47, -0.10,  0.0,  0.10,  0.0,   0.0,  -0.24);
const float CA[N] = float[N]( 0.40, -0.36,  0.78, -0.72,  0.16,  0.82, -0.10, -0.70, -1.00,  0.05);
const float CL[N] = float[N]( 0.60,  0.64,  0.42,  0.40,  0.84,  0.34,  1.00,  0.38,  0.24,  0.34);
const float CW[N] = float[N]( 0.070, 0.074, 0.056, 0.054, 0.094, 0.046, 0.110, 0.050, 0.038, 0.058);
const float CS[N] = float[N]( 0.55,  0.85,  1.40,  1.70,  0.0,   2.55,  0.15,  2.90,  3.35,  1.10);
const float CK[N] = float[N]( 0.0,   1.0,   1.0,   0.0,   0.0,   0.0,   0.0,   1.0,   0.0,   1.0);
const int   CP[N] = int[N]  ( -1,    -1,    -1,    -1,    -1,    4,     -1,    6,     6,     -1);
const float CY[N] = float[N]( 0.0,   0.0,   0.0,   0.0,   0.0,   0.36,  0.0,   0.30,  0.56,  0.0);
const float CR[N] = float[N]( 0.20,  0.55,  0.10,  0.40,  0.32,  0.05,  0.12,  0.45,  0.25,  0.38);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
vec2  hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Where crystal i is rooted (buds sit on their parent's axis, so they appear to
// sprout from its face because they are drawn in front of it).
vec2 crystalBase(int i, vec2 root) {
    int pi = CP[i];
    if (pi < 0) return root + vec2(CX[i] * HEIGHT, 0.0);
    vec2 pdir = vec2(-sin(CA[pi]), cos(CA[pi]));
    return root + vec2(CX[pi] * HEIGHT, 0.0) + pdir * CY[i] * CL[pi] * HEIGHT;
}

// Growth 0..1 in visible spurts: each step rests, then extends quickly (eased).
float growth(int i, float tc) {
    float g = clamp((tc - CS[i]) / GROW_DUR, 0.0, 1.0) * STEPS;
    return min((floor(g) + smoothstep(0.45, 1.0, fract(g))) / STEPS, 1.0);
}

// Side view of a hexagonal prism rotated by th around its axis. u runs -1..1
// across the silhouette. Returns the angle of the face normal under u, and the
// distance (in u units) to the nearest inner face edge.
float hexFace(float u, float th, out float edgeD) {
    float S = 0.0;
    for (int k = 0; k < 6; k++) S = max(S, abs(sin(th + float(k) * PI / 3.0)));
    float uu = u * S;
    float na = th + PI / 6.0;
    float best = 1e3;
    edgeD = 1e3;
    for (int k = 0; k < 6; k++) {
        float a0 = th + float(k) * PI / 3.0;
        float an = a0 + PI / 6.0;
        if (cos(an) <= 0.0) continue;                   // face points away from us
        float x0 = sin(a0), x1 = sin(a0 + PI / 3.0);
        float lo = min(x0, x1), hi = max(x0, x1);
        float d = max(lo - uu, uu - hi);                // <= 0 inside this face's span
        if (d < best) { best = d; na = an; }
        if (cos(a0) > 0.45) edgeD = min(edgeD, abs(uu - x0));   // edge between two visible faces
    }
    edgeD /= S;
    return na;
}

// Distance to the cell borders of a jittered grid (the crack network).
float crackNet(vec2 x) {
    vec2 n = floor(x), f = fract(x);
    vec2 mr = vec2(0.0), mg = vec2(0.0);
    float md = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 g = vec2(float(i), float(j));
        vec2 r = g + hash2(n + g) - f;
        float d = dot(r, r);
        if (d < md) { md = d; mr = r; mg = g; }
    }
    md = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 g = mg + vec2(float(i), float(j));
        vec2 r = g + hash2(n + g) - f;
        if (dot(mr - r, mr - r) > 1e-5)
            md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
    }
    return md;
}

// Signed distance to a triangle (negative inside).
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

// A tight four-point sparkle with 1-pixel arms.
float star(vec2 d, float r, float px) {
    float arms = exp(-abs(d.x) / (0.7 * px)) * exp(-abs(d.y) / r)
               + exp(-abs(d.y) / (0.7 * px)) * exp(-abs(d.x) / r);
    return arms + exp(-dot(d, d) / (2.0 * px * px));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec2 root = vec2(aspect - CLUSTER_X, -0.012);
    vec2 rel = p - root;

    // Far from the cluster and its flying shards nothing is drawn: skip all work.
    if (rel.x < -0.62 || rel.x > 0.55 || p.y > 0.62) {
        fragColor = base;
        return;
    }

    float t = iTime;
    float tc = mod(t, CYCLE);
    float px = 1.0 / iResolution.y;

    // One key light from the upper left, swaying slowly so glints travel over the facets.
    vec3 L = normalize(vec3(-0.55 + 0.45 * sin(t * 0.55), 0.55, 0.62));
    vec3 Hv = normalize(L + vec3(0.0, 0.0, 1.0));

    vec3 col = base.rgb;      // gem bodies are composited over this
    vec3 light = vec3(0.0);   // additive light: edges, glints, inner charge, cracks

    // How lit-up the crystals are from the inside, and when they vanish.
    float charge = clamp((tc - T_CHARGE) / 1.5, 0.0, 1.0);          // front position (0 base .. 1 tip)
    float gone = smoothstep(T_SHATTER, T_SHATTER + 0.12, tc);       // 1 once shattered

    // ---- Crystals ---------------------------------------------------------
    if (gone < 1.0 && rel.y < HEIGHT * 1.05 && rel.x > -0.36 && rel.x < 0.34) {
        for (int i = 0; i < N; i++) {
            float fi = float(i);
            float g = growth(i, tc);
            vec2 o = crystalBase(i, root);

            // Nucleation: a small spark where a crystal is about to sprout.
            float since = tc - CS[i];
            if (since > -0.25 && since < 0.6) {
                vec2 dn = p - o;
                if (dot(dn, dn) < 0.0009) {
                    float k = smoothstep(-0.25, 0.05, since) * smoothstep(0.6, 0.2, since);
                    light += mix(CHARGE, vec3(1.0), 0.5) * star(dn, 0.012, px) * k * 0.7;
                }
            }
            if (g <= 0.0) continue;

            float len = CL[i] * HEIGHT * g;
            float w = CW[i] * HEIGHT * (0.45 + 0.55 * sqrt(g));   // they thicken as they grow
            vec2 dir = vec2(-sin(CA[i]), cos(CA[i]));
            vec2 perp = vec2(dir.y, -dir.x);
            vec2 d = p - o;
            vec2 q = vec2(dot(d, perp), dot(d, dir));   // x across, y up the crystal

            vec2 c = q - vec2(0.0, len * 0.5);
            if (dot(c, c) > pow(len * 0.5 + w + 0.02, 2.0)) continue;

            // Column with a six-sided pyramidal tip.
            float tipLen = min(w * 1.7, len);
            float shoulder = len - tipLen;
            float inTip = step(shoulder, q.y);
            float s = inTip > 0.5 ? (len - q.y) / tipLen : 1.0;      // tip faces narrow to the apex
            float hw = w * s;
            float sd = abs(q.x) - hw;
            sd *= mix(1.0, tipLen / length(vec2(tipLen, w)), inTip);  // true distance on the slanted edges
            if (CP[i] < 0) sd = max(sd, -q.y);
            else sd = max(sd, -q.y - w * 0.6);                        // buds start inside their parent
            if (sd > 1.5 * px) continue;
            float inside = smoothstep(px, -px, sd);

            // Which flat facet is under this pixel, and its normal in screen space.
            float edgeU;
            float na = hexFace(clamp(q.x / max(hw, 1e-5), -1.0, 1.0), CR[i] * PI, edgeU);
            vec3 nl = inTip > 0.5 ? normalize(vec3(sin(na) * 0.62, 0.78, cos(na) * 0.62))
                                  : vec3(sin(na), 0.0, cos(na));
            vec2 nxy = nl.x * perp + nl.y * dir;
            vec3 n = vec3(nxy, nl.z);
            float diff = max(dot(n, L), 0.0);
            float spec = pow(max(dot(n, Hv), 0.0), 28.0);

            // Body colour: amethyst is pale at the base and deep violet toward the
            // tip (as in real points); quartz is near-clear with a cool tint.
            float yn = clamp(q.y / max(len, 1e-4), 0.0, 1.0);
            vec3 tint = CK[i] < 0.5 ? mix(AME_PALE, AME_DEEP, smoothstep(0.15, 0.85, q.y / (CL[i] * HEIGHT)))
                                    : QUARTZ;
            float shade = 0.28 + 0.85 * diff + (inTip > 0.5 ? 0.12 : 0.0);
            vec3 body = tint * shade;
            float alpha = (CK[i] < 0.5 ? 1.0 : 0.62) * (0.55 + 0.45 * diff);
            alpha *= OPACITY * inside * (1.0 - gone) * INTENSITY;
            col = mix(col, body, alpha);

            // Flat facet flash when a face lines up with the light.
            light += inside * (1.0 - gone) * vec3(1.0, 0.98, 1.0) * spec * 0.55;

            // Faint horizontal growth striations at the step heights (quartz prism faces have them).
            float stepH = CL[i] * HEIGHT / STEPS;
            float sy = abs(fract(q.y / stepH + 0.5) - 0.5) * stepH;
            light += tint * smoothstep(px, 0.0, sy) * (1.0 - inTip) * step(q.y, shoulder - 2.0 * px)
                   * inside * 0.10 * (1.0 - gone);

            // Crisp edges: silhouette, facet ridges, and the prism/tip boundary.
            float rim = smoothstep(1.2 * px, 0.0, abs(sd));
            float ridge = smoothstep(1.0 * px, 0.0, edgeU * hw) * inside;
            float shoulderLine = smoothstep(1.0 * px, 0.0, abs(q.y - shoulder)) * inside * step(2.0 * px, shoulder);
            vec3 edgeCol = mix(tint, vec3(1.0), 0.6);
            light += edgeCol * (rim * (0.30 + 0.5 * spec) + (ridge + shoulderLine) * (0.18 + 0.6 * spec))
                   * (1.0 - gone);

            // Inner light charging from the base to the tips, flickering faster near the end.
            if (charge > 0.0) {
                float front = charge * 1.12;
                float lit = smoothstep(front, front - 0.08, yn);
                float band = exp(-pow((yn - front) / 0.035, 2.0));
                float hum = 0.85 + 0.15 * sin(t * (18.0 + 30.0 * smoothstep(T_CRACK, T_SHATTER, tc)) + fi);
                float facetMod = 0.6 + 0.4 * diff;                  // stays faceted, not a blob
                light += inside * CHARGE * (lit * 0.6 * facetMod * hum + band * 1.0) * (1.0 - gone);
            }

            // Cracks: a network of fine bright lines spreading up each crystal.
            if (tc > T_CRACK) {
                float k = (tc - T_CRACK) / (T_SHATTER - T_CRACK);
                float reach = k * 1.25 - hash1(fi * 3.7) * 0.15;
                float cell = HEIGHT * 0.07;
                float cn = crackNet(q / cell + fi * 17.3) * cell;
                float widen = 1.0 + 3.0 * smoothstep(T_SHATTER - 0.15, T_SHATTER + 0.1, tc);
                float line = smoothstep(widen * px, 0.0, cn) * step(yn, reach) * inside;
                light += vec3(1.0, 0.94, 1.0) * line * 0.9 * (1.0 - gone);
                col = mix(col, base.rgb, line * 0.5 * smoothstep(T_SHATTER - 0.15, T_SHATTER, tc));
            }

            // Tip glint: a small crisp sparkle at the apex now and then.
            vec2 apex = o + dir * len;
            vec2 da = p - apex;
            if (g > 0.99 && dot(da, da) < 0.0009) {
                float tw = pow(max(sin(t * 0.8 + hash1(fi * 9.1) * 6.28), 0.0), 40.0);
                light += vec3(1.0) * star(da, 0.014, px) * (tw + 0.4 * charge) * 0.8 * (1.0 - gone);
            }
        }
    }

    // ---- Shards -----------------------------------------------------------
    float a = tc - T_SHATTER;
    if (a > 0.0 && a < 3.0) {
        float fade = smoothstep(2.9, 1.7, a);
        float flash = exp(-a * 5.0);
        vec2 centre = root + vec2(0.0, HEIGHT * 0.35);
        for (int j = 0; j < SHARDS; j++) {
            float fj = float(j);
            int ci = j - N * (j / N);                      // which crystal it came from
            float h1 = hash1(fj * 12.9 + 1.3), h2 = hash1(fj * 7.7 + 4.1);
            float h3 = hash1(fj * 3.3 + 9.2), h4 = hash1(fj * 5.1 + 2.7);

            vec2 dir = vec2(-sin(CA[ci]), cos(CA[ci]));
            vec2 perp = vec2(dir.y, -dir.x);
            float len = CL[ci] * HEIGHT, w = CW[ci] * HEIGHT;
            vec2 o = crystalBase(ci, root) + dir * len * mix(0.15, 0.9, h1) + perp * w * (h2 - 0.5) * 1.2;

            // Burst outward and up, slowed by drag, then gravity takes over.
            vec2 out_ = normalize(o - centre + vec2(1e-4, 0.0));
            vec2 v = out_ * (0.28 + 0.38 * h3) + vec2(0.0, 0.30 + 0.25 * h4);
            vec2 pos = o + v * (1.0 - exp(-2.2 * a)) / 2.2 - vec2(0.0, 0.11 * a * a);

            vec2 dp = p - pos;
            float sz = HEIGHT * (0.06 + 0.08 * h2);
            if (dot(dp, dp) > sz * sz) continue;

            float spin = (h1 - 0.5) * 9.0 * a + h4 * 6.28;
            vec2 m = rot(dp, -spin);
            // A long, sharp sliver: three jittered vertices.
            vec2 v0 = vec2(0.0, sz * (0.75 + 0.2 * h3));
            vec2 v1 = vec2(-sz * (0.22 + 0.18 * h4), -sz * (0.35 + 0.3 * h1));
            vec2 v2 = vec2( sz * (0.20 + 0.20 * h2), -sz * (0.45 + 0.25 * h3));
            float sdv = sdTri(m, v0, v1, v2);
            if (sdv > 1.5 * px) continue;
            float inS = smoothstep(px, -px, sdv);

            // Two flat facets split along the long axis; their brightness swaps as it tumbles.
            vec2 mid = 0.5 * (v1 + v2);
            float side = sign((v0.x - mid.x) * (m.y - mid.y) - (v0.y - mid.y) * (m.x - mid.x));
            float tumble = spin * 1.3 + side * 1.2;
            float br = 0.35 + 0.65 * (0.5 + 0.5 * cos(tumble));
            float glint = pow(0.5 + 0.5 * cos(tumble), 18.0);
            vec3 tint = CK[ci] < 0.5 ? mix(AME_PALE, AME_DEEP, h1) : QUARTZ;

            col = mix(col, tint * br, inS * OPACITY * (CK[ci] < 0.5 ? 0.95 : 0.6) * fade * INTENSITY);
            float rim = smoothstep(1.2 * px, 0.0, abs(sdv));
            light += (mix(tint, vec3(1.0), 0.6) * rim * (0.35 + 0.6 * glint)
                    + vec3(1.0) * inS * glint * 0.45
                    + CHARGE * inS * flash * 0.6) * fade;
        }
    }

    light *= INTENSITY;
    fragColor = vec4(col + light / (1.0 + 0.35 * light), base.a);
}
