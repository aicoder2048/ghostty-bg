// constellations — a star chart that draws itself: real constellations light up one at a time on the right, then thin lines join their stars.
// zh: 星座
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.90;   // overall strength (0 = off)
const float SIZE      = 0.36;   // figure height, in window heights
const float CYCLE     = 9.0;    // seconds per constellation
const float DRAW      = 3.2;    // seconds to draw all the lines of one figure
const float LINE      = 0.42;   // brightness of the figure lines
const float FIELD     = 0.55;   // brightness of the faint background starfield
const float STARCELL  = 0.034;  // background star grid (smaller = denser sky)

// Figures: Orion, Ursa Major (Big Dipper), Cassiopeia, Cygnus, Scorpius, Leo,
// Lyra. Each star is vec4(x, y, visual magnitude, B-V colour index), from real
// RA/Dec (east to the left, as on a sky chart), centred and scaled so the
// figure is 1 unit tall (or 1.4 wide). Each edge is vec4(star a, star b,
// start, end) where start/end are the fraction of the total line length drawn
// before it, so the pen moves at an even speed through the figure.
const int NC = 7;
const vec4 STAR[52] = vec4[](
    vec4(-0.007, 0.500, 3.400, -0.180),
    vec4(-0.258, 0.371, 0.500, 1.850),
    vec4(0.122, 0.317, 1.640, -0.220),
    vec4(-0.076, -0.106, 1.770, -0.210),
    vec4(-0.015, -0.068, 1.690, -0.180),
    vec4(0.039, -0.022, 2.230, -0.220),
    vec4(-0.166, -0.500, 2.060, -0.180),
    vec4(0.258, -0.425, 0.130, -0.030),
    vec4(-0.700, -0.347, 1.860, -0.190),
    vec4(-0.418, -0.034, 2.230, 0.020),
    vec4(-0.170, 0.024, 1.770, -0.020),
    vec4(0.129, 0.084, 3.310, 0.080),
    vec4(0.600, 0.347, 1.790, 1.070),
    vec4(0.700, 0.047, 2.370, -0.020),
    vec4(0.310, -0.103, 2.440, 0.040),
    vec4(0.700, -0.106, 2.270, 0.340),
    vec4(0.273, -0.396, 2.240, 1.170),
    vec4(0.017, 0.068, 2.150, -0.150),
    vec4(-0.384, 0.015, 2.680, 0.130),
    vec4(-0.700, 0.396, 3.380, -0.150),
    vec4(-0.208, 0.500, 1.250, 0.090),
    vec4(-0.012, 0.210, 2.230, 0.670),
    vec4(0.647, -0.500, 3.050, 1.130),
    vec4(0.366, 0.491, 2.870, -0.030),
    vec4(-0.299, -0.153, 2.480, 1.030),
    vec4(-0.647, -0.369, 3.210, 0.990),
    vec4(0.418, 0.500, 2.620, -0.070),
    vec4(0.463, 0.380, 2.290, -0.120),
    vec4(0.462, 0.231, 2.890, -0.190),
    vec4(0.168, 0.217, 1.060, 1.830),
    vec4(0.103, 0.142, 2.820, -0.250),
    vec4(-0.031, -0.118, 2.290, 1.150),
    vec4(-0.041, -0.279, 3.000, -0.200),
    vec4(-0.198, -0.500, 3.320, 0.410),
    vec4(-0.395, -0.490, 1.860, 0.400),
    vec4(-0.463, -0.320, 2.410, -0.220),
    vec4(-0.398, -0.238, 1.620, -0.220),
    vec4(0.469, -0.335, 1.350, -0.110),
    vec4(0.476, -0.106, 3.480, -0.030),
    vec4(0.330, 0.041, 2.080, 1.130),
    vec4(0.359, 0.212, 3.430, 0.310),
    vec4(0.614, 0.335, 3.880, 1.220),
    vec4(0.700, 0.229, 2.980, 0.800),
    vec4(-0.282, 0.073, 2.560, 0.120),
    vec4(-0.700, -0.211, 2.130, 0.090),
    vec4(-0.296, -0.170, 3.330, 0.000),
    vec4(0.313, 0.372, 0.030, 0.000),
    vec4(0.111, 0.500, 4.700, 0.160),
    vec4(0.097, 0.203, 4.300, 0.190),
    vec4(-0.177, 0.103, 4.300, 1.680),
    vec4(-0.313, -0.500, 3.250, -0.050),
    vec4(-0.042, -0.404, 3.500, 0.000));
const vec4 EDGE[50] = vec4[](
    vec4(0.0, 1.0, 0.000, 0.119),
    vec4(1.0, 3.0, 0.119, 0.334),
    vec4(3.0, 4.0, 0.334, 0.364),
    vec4(4.0, 5.0, 0.364, 0.394),
    vec4(5.0, 2.0, 0.394, 0.541),
    vec4(2.0, 0.0, 0.541, 0.636),
    vec4(3.0, 6.0, 0.636, 0.806),
    vec4(5.0, 7.0, 0.806, 1.000),
    vec4(8.0, 9.0, 0.000, 0.168),
    vec4(9.0, 10.0, 0.168, 0.269),
    vec4(10.0, 11.0, 0.269, 0.390),
    vec4(11.0, 12.0, 0.390, 0.605),
    vec4(12.0, 13.0, 0.605, 0.731),
    vec4(13.0, 14.0, 0.731, 0.897),
    vec4(14.0, 11.0, 0.897, 1.000),
    vec4(15.0, 16.0, 0.000, 0.265),
    vec4(16.0, 17.0, 0.265, 0.538),
    vec4(17.0, 18.0, 0.538, 0.745),
    vec4(18.0, 19.0, 0.745, 1.000),
    vec4(20.0, 21.0, 0.000, 0.131),
    vec4(21.0, 22.0, 0.131, 0.495),
    vec4(23.0, 21.0, 0.495, 0.672),
    vec4(21.0, 24.0, 0.672, 0.846),
    vec4(24.0, 25.0, 0.846, 1.000),
    vec4(26.0, 27.0, 0.000, 0.067),
    vec4(27.0, 28.0, 0.067, 0.144),
    vec4(27.0, 29.0, 0.144, 0.319),
    vec4(29.0, 30.0, 0.319, 0.371),
    vec4(30.0, 31.0, 0.371, 0.523),
    vec4(31.0, 32.0, 0.523, 0.607),
    vec4(32.0, 33.0, 0.607, 0.748),
    vec4(33.0, 34.0, 0.748, 0.851),
    vec4(34.0, 35.0, 0.851, 0.946),
    vec4(35.0, 36.0, 0.946, 1.000),
    vec4(37.0, 38.0, 0.000, 0.069),
    vec4(38.0, 39.0, 0.069, 0.131),
    vec4(39.0, 40.0, 0.131, 0.183),
    vec4(40.0, 41.0, 0.183, 0.268),
    vec4(41.0, 42.0, 0.268, 0.309),
    vec4(39.0, 43.0, 0.309, 0.492),
    vec4(43.0, 44.0, 0.492, 0.644),
    vec4(44.0, 45.0, 0.644, 0.766),
    vec4(45.0, 37.0, 0.766, 1.000),
    vec4(46.0, 47.0, 0.000, 0.091),
    vec4(47.0, 48.0, 0.091, 0.204),
    vec4(48.0, 46.0, 0.204, 0.308),
    vec4(48.0, 49.0, 0.308, 0.419),
    vec4(49.0, 50.0, 0.419, 0.654),
    vec4(50.0, 51.0, 0.654, 0.763),
    vec4(51.0, 48.0, 0.763, 1.000));
// first star, star count, first edge, edge count
const ivec4 CON[7] = ivec4[](
    ivec4(0, 8, 0, 8),
    ivec4(8, 7, 8, 7),
    ivec4(15, 5, 15, 4),
    ivec4(20, 6, 19, 5),
    ivec4(26, 11, 24, 10),
    ivec4(37, 9, 34, 9),
    ivec4(46, 6, 43, 7));
// half extents of each figure (unit = SIZE)
const vec2 HALF[7] = vec2[](
    vec2(0.258, 0.500),
    vec2(0.700, 0.347),
    vec2(0.700, 0.396),
    vec2(0.647, 0.500),
    vec2(0.463, 0.500),
    vec2(0.700, 0.335),
    vec2(0.313, 0.500));

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
vec3 hash3(vec2 p) {
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)), dot(p, vec2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

// Star colour from its B-V index: blue-white (Rigel) through white to
// orange (Betelgeuse, Antares). Kept gentle, like a photograph.
vec3 starColour(float bv) {
    vec3 c = mix(vec3(0.70, 0.80, 1.00), vec3(1.00, 0.97, 0.92), smoothstep(-0.3, 0.4, bv));
    c = mix(c, vec3(1.00, 0.72, 0.44), smoothstep(0.4, 1.2, bv));
    return mix(c, vec3(1.00, 0.55, 0.30), smoothstep(1.2, 1.8, bv));
}

// Star radius (window heights) from magnitude: bright stars are bigger dots.
float starRadius(float mag, float px) {
    return max(0.0020 + 0.0014 * clamp(3.6 - mag, 0.0, 4.0), 1.3 * px);
}

// Distance from p to the segment a-b.
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return length(pa - ba * h);
}

// A crisp star point: a sharp disc plus a tight halo a few radii wide.
float starPoint(float d, float r, float px) {
    float core = 1.0 - smoothstep(r - 0.6 * px, r + 0.6 * px, d);
    float halo = exp(-max(d - r, 0.0) / (0.9 * r)) * step(d, 5.0 * r);
    return core + 0.30 * halo;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip to y-up scene coordinates.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;
    vec3 col = vec3(0.0);

    // ------------------------------------------------ faint background sky
    // One possible star per grid cell, kept inside its cell so a single cell
    // lookup is enough. Dimmer over the top-left text block.
    {
        vec2 cell = floor(p / STARCELL);
        vec3 h = hash3(cell);
        if (h.x < 0.42) {
            vec2 sp = (cell + 0.2 + 0.6 * h.yz) * STARCELL;
            float d = length(p - sp);
            float b = 0.10 + 0.55 * pow(hash1(h.x * 91.7), 4.0);
            float r = (0.7 + 0.8 * b) * px;
            float tw = hash1(h.y * 57.3 + h.z);
            vec3 tint = starColour(hash1(h.z * 33.1) * 1.6 - 0.2);
            float k = 1.0 - smoothstep(r - 0.5 * px, r + 0.7 * px, d);
            if (tw > 0.93) {
                // A few twinklers: a slow swell to a bright peak with tiny spikes.
                float ph = iTime * (0.35 + 0.4 * h.y) + h.z * 6.283;
                float s = pow(0.5 + 0.5 * sin(ph), 6.0);
                b = mix(b, 0.85, s);
                vec2 q = abs(p - sp);
                float spike = (1.0 - smoothstep(0.3 * px, 0.9 * px, min(q.x, q.y)))
                            * (1.0 - smoothstep(0.0, 6.0 * px, max(q.x, q.y)));
                k = max(k, spike * s * 0.8);
            } else {
                b *= 0.85 + 0.15 * sin(iTime * (1.0 + 2.0 * tw) + tw * 40.0);
            }
            vec2 tl = (p - vec2(0.0, 1.0)) / vec2(0.55 * aspect, 0.55);
            float calm = mix(0.35, 1.0, smoothstep(0.6, 1.1, length(tl)));
            col += tint * k * b * FIELD * calm;
        }
    }

    // ------------------------------------------------ the constellation
    float n = floor(iTime / CYCLE);
    float t = iTime - n * CYCLE;                      // seconds into this figure
    int id = int(mod(n * 3.0, float(NC)));            // 3 is coprime to 7: all figures in turn
    ivec4 con = CON[id];
    vec2 half_ = HALF[id] * SIZE;

    // A new spot on the right half for each figure, fully inside the window.
    float hx = hash1(n * 7.13 + 1.0), hy = hash1(n * 3.71 + 2.0);
    float x0 = 0.56 * aspect + half_.x + 0.04, x1 = aspect - half_.x - 0.05;
    vec2 c = vec2(mix(x0, max(x0, x1), hx), mix(half_.y + 0.07, 0.84 - half_.y, hy * hy));

    vec2 q = p - c;
    if (all(lessThan(abs(q), half_ + 0.05))) {
        float lineFade = 1.0 - smoothstep(6.8, 7.8, t);
        float starFade = 1.0 - smoothstep(7.4, 8.8, t);
        float prog = clamp((t - 1.3) / DRAW, 0.0, 1.0);
        prog = prog * prog * (3.0 - 2.0 * prog) * 0.15 + prog * 0.85;   // soft start and stop

        // Stars: brightest first, each swelling in over ~0.6 s.
        for (int i = 0; i < 12; i++) {
            if (i >= con.y) break;
            vec4 s = STAR[con.x + i];
            vec2 sp = s.xy * SIZE;
            float d = length(q - sp);
            float r = starRadius(s.z, px);
            if (d > 6.0 * r) continue;
            float delay = 0.1 + 0.2 * clamp(s.z, 0.0, 4.7);
            float on = smoothstep(delay, delay + 0.6, t) * starFade;
            float bright = 0.55 + 0.45 * clamp((4.5 - s.z) / 4.5, 0.0, 1.0);
            bright *= 0.94 + 0.06 * sin(iTime * 3.1 + float(i) * 2.3);   // faint scintillation
            col += starColour(s.w) * starPoint(d, r, px) * bright * on;
        }

        // Lines: drawn edge after edge, stopping short of each star like a chart.
        for (int i = 0; i < 11; i++) {
            if (i >= con.w) break;
            vec4 e = EDGE[con.z + i];
            float k = clamp((prog - e.z) / max(e.w - e.z, 1e-4), 0.0, 1.0);
            if (k <= 0.0) break;                      // later edges are not drawn yet
            vec4 sa = STAR[int(e.x)], sb = STAR[int(e.y)];
            vec2 a = sa.xy * SIZE, b = sb.xy * SIZE;
            vec2 dir = normalize(b - a);
            vec2 A = a + dir * (2.2 * starRadius(sa.z, px) + 0.006);
            vec2 B = b - dir * (2.2 * starRadius(sb.z, px) + 0.006);
            if (dot(B - A, dir) <= 0.0) continue;
            vec2 tip = mix(A, B, k);
            float d = segment(q, A, tip);
            float w = 1.0 - smoothstep(0.35 * px, 1.25 * px, d);
            col += vec3(0.68, 0.80, 0.98) * w * LINE * lineFade;
            if (k < 1.0) {
                // The pen: a small bright moving point with a tight glow.
                float dt = length(q - tip);
                float pen = (1.0 - smoothstep(1.0 * px, 2.2 * px, dt)) + 0.5 * exp(-dt / (3.0 * px));
                col += vec3(0.85, 0.92, 1.0) * pen;
            }
        }
    }

    fragColor = vec4(base.rgb + min(col, vec3(1.0)) * INTENSITY, base.a);
}
