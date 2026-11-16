// geese — a skein of wild geese beats across the sky in a V, long necks stretched forward.
// zh: 雁阵
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (dark grey-brown silhouettes with a thin light top edge).

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float SIZE      = 0.050;  // one goose (bill to tail) in window WIDTHS
const float CROSS     = 16.0;   // seconds a skein takes to cross, tail included
const float PERIOD    = 17.0;   // seconds from one skein to the next
const float BEAT      = 2.3;    // wing beats per second
const float LAG       = 0.55;   // beat delay per rank back from the leader, radians
const vec3  FILL      = vec3(0.115, 0.095, 0.080);  // grey-brown silhouette
const vec3  EDGE      = vec3(0.950, 0.880, 0.760);  // light on the upper edges
const vec2  LIGHT     = vec2(-0.20, 0.98);          // edge light comes from above

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

// Capsule from a (radius ra) to b (radius rb): a tapering neck.
float taper(vec2 p, vec2 a, vec2 b, float ra, float rb) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - mix(ra, rb, h);
}

float triangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0,  v1 = p - p1,  v2 = p - p2;
    vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

// Signed distance to the line a->b; positive on its left (outside of a
// clockwise outline).
float edge(vec2 p, vec2 a, vec2 b) {
    vec2 e = normalize(b - a);
    return dot(p - a, vec2(-e.y, e.x));
}

// One wing seen from the side, from the shoulder. s = sin(beat phase):
// +1 = raised high and a little back, -1 = pushed down, 0 = level, which
// points it at the viewer, so it looks short. Wider at the root, a long
// pointed hand, a couple of nicks for the primary feathers.
float wing(vec2 q, float s, float len) {
    float th = 3.14159 - (1.18 + 0.13 * s) * s;     // angle of the wing from +x
    vec2 u = vec2(cos(th), sin(th));
    vec2 n = vec2(u.y, -u.x) * (s >= 0.0 ? 1.0 : -1.0);   // toward the leading edge
    float L = len * (0.32 + 0.68 * abs(s));         // foreshortened length
    vec2 w = vec2(dot(q, u), dot(q, n));

    vec2 R1 = vec2(-0.03,  0.100), R2 = vec2(-0.03, -0.100);
    vec2 WL = vec2(0.42 * L, 0.092), WT = vec2(0.58 * L, -0.068);
    vec2 TP = vec2(L, 0.012);
    // Convex outline as the max over its edges (no seams inside, unlike a
    // union of triangles, whose shared edges would read as an edge).
    float d = edge(w, R1, WL);
    d = max(d, edge(w, WL, TP));
    d = max(d, edge(w, TP, WT));
    d = max(d, edge(w, WT, R2));
    d = max(d, edge(w, R2, R1));
    // Slots between the outer primaries on the trailing edge.
    d = max(d, -(length(w - vec2(0.80 * L, -0.040)) - 0.022));
    d = max(d, -(length(w - vec2(0.91 * L, -0.020)) - 0.014));
    return d - 0.008;                               // soften the corners a touch
}

// A goose in profile flying toward +x, bill to tail about 1 unit. Returns the
// distance to body + near wing in .x and to the far wing in .y.
vec2 goose(vec2 q, float s, float sf) {
    q.y += 0.025 * s;                               // body rises on the downstroke

    float d = ellipse(q, vec2(-0.02, 0.0), vec2(0.25, 0.080));      // body
    d = min(d, ellipse(q, vec2(0.07, -0.012), vec2(0.17, 0.072)));  // full breast
    d = min(d, triangle(q, vec2(-0.20, 0.035), vec2(-0.20, -0.038), vec2(-0.41, 0.004)) - 0.008);  // tail
    d = min(d, taper(q, vec2(0.16, 0.018), vec2(0.43, 0.048), 0.056, 0.032));  // long neck
    d = min(d, ellipse(q, vec2(0.455, 0.052), vec2(0.058, 0.040)));            // head
    d = min(d, triangle(q, vec2(0.48, 0.068), vec2(0.48, 0.030), vec2(0.585, 0.042)));  // bill
    d = min(d, wing(q - vec2(0.03, 0.040), s, 0.66));

    float f = wing(q - vec2(0.00, 0.050), sf, 0.58);
    return vec2(d, f);
}

// The flight line: low on the left, high on the right, with a slow swell.
float pathY(float x, float aspect, float c) {
    float lo = 0.30 + 0.06 * hash1(c * 3.1 + 1.0);
    float hi = 0.64 + 0.08 * hash1(c * 5.7 + 2.0);
    return mix(lo, hi, x / aspect) + 0.025 * sin(x * 2.3 + c);
}

float pathSlope(float x, float aspect, float c) {
    float lo = 0.30 + 0.06 * hash1(c * 3.1 + 1.0);
    float hi = 0.64 + 0.08 * hash1(c * 5.7 + 2.0);
    return (hi - lo) / aspect + 0.0575 * cos(x * 2.3 + c);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime + 5.0;               // start with a skein already on its way in

    float D = 1e5;      // distance to the nearest body / near wing, in pixels
    float F = 1e5;      // distance to the nearest far wing, in pixels
    float vis = 1.0;    // strength of that goose (far skeins are fainter)

    float U0 = SIZE * aspect;            // goose length in scene units

    // Two skeins per cycle: the main V, and sometimes a smaller, fainter one
    // farther off, a little higher and a few seconds behind.
    for (int layer = 0; layer < 2; layer++) {
        float fl = float(layer);
        float tl = t - fl * 3.0;
        float c = floor(tl / PERIOD);
        float age = tl - c * PERIOD;
        if (age > CROSS) continue;
        if (layer == 1 && hash1(c * 7.7 + 0.3) < 0.4) continue;

        float scale = layer == 0 ? 1.0 : 0.58;
        float U = U0 * scale;
        float dir = mod(c, 2.0) < 0.5 ? -1.0 : 1.0;    // alternate right-to-left / left-to-right
        int count = layer == 0 ? 9 + int(hash1(c * 1.3 + 4.0) * 4.99)
                               : 5 + int(hash1(c * 2.9 + 6.0) * 2.99);
        float ranks = float((count) / 2);

        // The leader enters just past one edge and flies until the last
        // trailing goose has left the other edge.
        float tailLen = (ranks * 1.05 + 0.8) * U;
        float travel = aspect + 0.16 + tailLen;
        float lx = dir < 0.0 ? aspect + 0.08 - travel * age / CROSS
                             : -0.08 + travel * age / CROSS;
        float lift = layer == 0 ? 0.0 : 0.16;
        vec2 lead = vec2(lx, pathY(lx, aspect, c) + lift);
        float slope = pathSlope(lx, aspect, c);
        vec2 tang = normalize(vec2(1.0, slope));      // path direction, rightward form
        vec2 fwd = tang * dir;                        // flight direction
        vec2 side = vec2(-fwd.y, fwd.x);
        float tilt = atan(tang.y, tang.x);

        // Skip the whole skein if this pixel is nowhere near it.
        vec2 rel = p - lead;
        float back = -dot(rel, fwd);
        if (back < -1.0 * U || back > tailLen + U || abs(dot(rel, side)) > (ranks * 0.55 + 1.0) * U) continue;

        float fade = layer == 0 ? 1.0 : 0.55;

        for (int i = 0; i < 13; i++) {
            if (i >= count) break;
            float fi = float(i);
            float rank = floor((fi + 1.0) * 0.5);
            float arm = mod(fi, 2.0) < 0.5 ? 1.0 : -1.0;   // which arm of the V
            float h = hash1(fi * 13.7 + c * 3.3 + fl * 9.1);

            // The V flexes slowly; trailing geese drift and bob a little more.
            float b = rank * 1.05 * (1.0 + 0.04 * sin(t * 0.6 + arm))
                    + 0.10 * sin(t * 0.37 + fi * 1.9) * min(rank, 1.0);
            float sd = arm * rank * 0.48 * (1.0 + 0.07 * sin(t * 0.45 + arm * 1.3));
            vec2 pos = lead - fwd * b * U + side * sd * U;
            pos.y += 0.07 * U * sqrt(rank) * sin(t * 1.1 - rank * 0.7 + arm * 1.7 + h);

            vec2 q = (p - pos) / U;
            if (dot(q, q) > 0.64) continue;           // outside this goose

            q = rot(q, -tilt - 0.04 * cos(t * 1.1 - rank * 0.7 + arm * 1.7 + h));
            q.x *= dir;                               // mirror when flying left

            float ph = 6.28318 * BEAT * t - rank * LAG + 0.6 * h;   // trailing geese lag a little
            vec2 g = goose(q, sin(ph), sin(ph - 0.35));
            float px = U * iResolution.y;
            float dg = g.x * px, df = g.y * px;
            if (min(dg, df) < min(D, F)) vis = fade;
            D = min(D, dg);
            F = min(F, df);
        }
    }

    // Far wing a shade lighter behind the body; body and near wing on top.
    float aF = smoothstep(0.75, -0.75, F);
    float aD = smoothstep(0.75, -0.75, D);
    // Thin light edge on the upward-facing outline (top of wings, back, neck).
    // Each layer gets its own edge, so overlaps don't leave stray sparks. The
    // signs of dFdx(p.x) / dFdy(p.y) make "up" right whichever way the
    // renderer's window y points.
    vec2 sg = vec2(sign(dFdx(p.x)), sign(dFdy(p.y)));
    vec2 L = normalize(LIGHT);
    vec2 gD = vec2(dFdx(D), dFdy(D)) * sg;
    vec2 gF = vec2(dFdx(F), dFdy(F)) * sg;
    float litD = smoothstep(0.25, 0.8, dot(gD / (length(gD) + 1e-4), L));
    float litF = smoothstep(0.25, 0.8, dot(gF / (length(gF) + 1e-4), L));
    float rimD = smoothstep(-1.6, -0.6, D) * smoothstep(0.6, -0.4, D) * litD;
    float rimF = smoothstep(-1.6, -0.6, F) * smoothstep(0.6, -0.4, F) * litF * (1.0 - aD);
    float rim = max(rimD, 0.6 * rimF);

    // Keep the top-left (where the shell text usually is) mostly clear.
    float clearTL = (1.0 - smoothstep(0.30, 0.50, uv.x)) * (1.0 - smoothstep(0.40, 0.60, uv.y));
    float k = INTENSITY * vis * (1.0 - 0.75 * clearTL);

    vec3 rgb = mix(base.rgb, FILL * 1.6, aF * 0.80 * k);
    rgb = mix(rgb, FILL, aD * 0.92 * k);
    rgb += EDGE * rim * 0.42 * k * vis;   // tiny far geese get less edge, or they read as white specks
    fragColor = vec4(rgb, base.a);
}
