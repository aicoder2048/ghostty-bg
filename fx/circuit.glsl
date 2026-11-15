// circuit — circuit-board traces along the edges, with light pulses racing to their pads.
// zh: 电路
// group: geek
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.65;   // overall brightness (0 = off)
const float SPEED     = 0.45;   // pulse speed, in window-heights per second
const float LANE      = 0.020;  // gap between parallel traces in a bundle
const int   BUNDLES   = 5;
const int   LANES     = 3;      // traces per bundle (BUNDLES * LANES loop passes)

// Each bundle leaves a window edge, bends 45 degrees once, then runs along the
// edge to a row of pads. Laid out in the edge's own frame: s along the edge,
// n inward from it.
//   A: side (0 bottom, 1 top, 2 left, 3 right), start along the edge (0-1),
//      run direction along the edge (+1/-1), first inward leg
//   B: diagonal leg, final run length
const vec4 A[5] = vec4[5](
    vec4(0.0, 0.50,  1.0, 0.030),
    vec4(3.0, 0.16,  1.0, 0.030),
    vec4(3.0, 0.84, -1.0, 0.030),
    vec4(1.0, 0.92, -1.0, 0.030),
    vec4(2.0, 0.18,  1.0, 0.030)
);
const vec2 B[5] = vec2[5](
    vec2(0.05, 0.30),
    vec2(0.05, 0.24),
    vec2(0.05, 0.12),
    vec2(0.05, 0.16),
    vec2(0.05, 0.20)
);

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Distance from p to the segment a-b, and how far along it (0 at a, 1 at b).
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 light = vec3(0.0);

    for (int b = 0; b < BUNDLES; b++) {
        float side = A[b].x;
        float edgeLen = side < 1.5 ? aspect : 1.0;
        // This pixel in the bundle's edge frame (s along the edge, n inward).
        vec2 q = side < 0.5 ? p
               : side < 1.5 ? vec2(p.x, 1.0 - p.y)
               : side < 2.5 ? vec2(p.y, p.x)
                            : vec2(p.y, aspect - p.x);
        float s0 = A[b].y * edgeLen, dir = A[b].z, n1 = A[b].w;
        float k = B[b].x;

        for (int j = 0; j < LANES; j++) {
            float fj = float(j);
            float w = fj * LANE;
            // Offset a polyline with a 45-degree bend: tan(22.5) keeps the lanes parallel.
            vec2 p0 = vec2(s0 - w * dir, 0.0);
            vec2 p1 = vec2(s0 - w * dir, n1 + w * 0.4142);
            vec2 p2 = vec2(s0 + dir * (k - w * 0.4142), n1 + k + w);
            float run = B[b].y * (0.75 + 0.25 * hash1(float(b * 7 + j)));
            vec2 p3 = vec2(p2.x + dir * run, p2.y);

            vec2 d0 = segment(q, p0, p1);
            vec2 d1 = segment(q, p1, p2);
            vec2 d2 = segment(q, p2, p3);
            float l0 = length(p1 - p0), l1 = length(p2 - p1), l2 = run;
            float total = l0 + l1 + l2;

            // Closest leg, and how far along the whole trace that point is.
            float d = d0.x, arc = d0.y * l0;
            if (d1.x < d) { d = d1.x; arc = l0 + d1.y * l1; }
            if (d2.x < d) { d = d2.x; arc = l0 + l1 + d2.y * l2; }

            // One pulse per trace at a time: it runs in from the edge to the pad,
            // then there is a short gap before the next one.
            float period = total + 0.25 + 0.4 * hash1(float(b * 13 + j) + 0.5);
            float u = mod(iTime * SPEED + hash1(float(b * 5 + j) + 2.0) * period, period);
            float behind = u - arc;
            float pulse = behind >= 0.0 ? exp(-behind * 16.0) : 0.0;
            pulse *= step(arc, total);

            float line = smoothstep(0.0028, 0.0012, d);
            light += vec3(0.15, 0.80, 0.60) * line * 0.22;                       // the copper, dim
            light += vec3(0.70, 1.00, 0.95) * pulse * (line * 1.3 + exp(-d * 250.0) * 0.35);

            // The pad at the end flashes when the pulse arrives, then cools down.
            float dp = length(q - p3);
            float pad = smoothstep(0.0095, 0.0080, dp) * smoothstep(0.0025, 0.0035, dp);
            float flash = u > total ? exp(-(u - total) * 7.0) : 0.0;
            light += vec3(1.00, 0.80, 0.35) * (pad * (0.30 + 1.4 * flash) + exp(-dp * 90.0) * flash * 0.35);

            // A small via where the trace leaves the edge leg.
            float dv = length(q - p1);
            light += vec3(0.15, 0.80, 0.60) * smoothstep(0.0055, 0.0045, dv) * smoothstep(0.0015, 0.0025, dv) * 0.35;
        }
    }

    fragColor = vec4(base.rgb + min(light, vec3(1.0)) * INTENSITY, base.a);
}
