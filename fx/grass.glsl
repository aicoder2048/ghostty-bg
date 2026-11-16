// grass — a realistic meadow along the bottom: thin blades and wild-grass seed heads sway and bend as gusts roll across.
// zh: 草浪
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY  = 0.90;   // overall strength (0 = off)
const float HEIGHT     = 0.27;   // front-row blade height, in window heights
const float GUST       = 1.05;   // how hard a gust bends the blades
const float GUST_GAP   = 7.0;    // seconds between big gusts
const float GUST_SPEED = 0.55;   // how fast a gust rolls across, window heights per second
const float SWAY       = 0.08;   // constant gentle sway
const float HEADS      = 0.11;   // share of stems that carry a seed head
const float DRY        = 0.16;   // share of dry, straw-coloured blades
const float SHEEN      = 0.38;   // how much light the bent tips catch in a gust

const int   LAYERS = 4;          // depth rows, back to front
const vec3  SUN    = vec3(1.0, 0.94, 0.76);

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

// Paint colour c with coverage k over a premultiplied accumulator.
void over(inout vec4 acc, vec3 c, float k) {
    acc.rgb = c * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}

// A crest of wind travelling left to right; 1 at its peak, 0 when calm.
float pulse(float x, float gap, float spd, float ph, float n) {
    float w = 6.2831 / gap;
    return pow(0.5 + 0.5 * cos(w * (iTime - x / spd) + ph), n);
}

// Big gusts every GUST_GAP s (the first one crosses the left edge at ~1 s),
// plus a weaker, faster ripple so the meadow is never fully still.
float gust(float x) {
    return pulse(x, GUST_GAP, GUST_SPEED, -6.2831 / GUST_GAP, 8.0)
         + 0.35 * pulse(x, 4.3, 0.8, 2.0, 6.0);
}

// How far the grass leans at x: a slight steady lean, gentle sway, and the gust.
float leanAt(float x, float fl) {
    return 0.14
         + SWAY * (0.6 * sin(1.9 * iTime + 2.7 * x + fl) + 0.4 * sin(3.3 * iTime + 6.1 * x + 1.7 * fl))
         + GUST * gust(x);
}

// Taller and shorter clumps, a little lower toward the left (where text lives).
float patchHeight(float x, float aspect) {
    return (0.86 + 0.16 * sin(x * 2.9 + 1.3) + 0.08 * sin(x * 7.3 + 0.4))
         * mix(0.80, 1.06, clamp(x / aspect, 0.0, 1.0));
}

// Wild-grass seed head in local coords (along the stem tip, across it).
// Foxtail: a dense bristly spike. Otherwise: alternating wheat-like spikelets,
// some with long awns. Returns colour + coverage.
vec4 seedHead(float along, float across, float L, float aa, float r1, float r2, float kind, float g) {
    float u = along / L;
    if (u < -0.05 || u > 1.6) return vec4(0.0);
    float W = L * 0.15;
    vec3 c;
    float a;

    if (kind < 0.5) {
        // Foxtail: fuller near the base, a fringe of fine bristles.
        float uc = clamp(u, 0.0, 1.0);
        float prof = W * 2.0 * sqrt(uc * (1.0 - uc)) * (1.0 - 0.3 * uc);
        float br = W * 0.75 * pow(0.5 + 0.5 * sin(along / L * 90.0 + sign(across) * 1.6), 5.0)
                 * smoothstep(0.0, 0.15, uc) * smoothstep(1.0, 0.8, uc);
        float d = abs(across) - (prof + br);
        a = clamp(-d / aa + 0.5, 0.0, 1.0) * clamp(min(u, 1.0 - u) * L / aa + 0.5, 0.0, 1.0);
        vec3 core = mix(vec3(0.42, 0.45, 0.24), vec3(0.58, 0.52, 0.32), r1);
        vec3 tipc = mix(vec3(0.80, 0.76, 0.56), vec3(0.86, 0.78, 0.60), r2);
        c = mix(core, tipc, smoothstep(prof * 0.4, prof + br * 0.8, abs(across)));
        c *= 0.86 + 0.14 * sin(along / L * 140.0) * sin(across / W * 9.0);
        c *= across < 0.0 ? 1.10 : 0.82;                    // lit from the upper left
    } else {
        // Spikelets: little grains stacked alternately up the axis, smaller at the top.
        const float N = 7.0;
        float sp = L / N;
        float j0 = floor(along / sp);
        a = 0.0;
        c = vec3(0.0);
        vec3 grain = mix(vec3(0.70, 0.62, 0.38), vec3(0.56, 0.58, 0.33), r1 * r1);
        for (int k = 0; k < 2; k++) {
            float j = j0 + float(k) - 1.0;
            if (j < 0.0 || j >= N) continue;
            float side = mod(j, 2.0) < 1.0 ? 1.0 : -1.0;
            float s = 1.0 - 0.35 * j / N;
            vec2 v = vec2(along - (j + 0.75) * sp, across - side * W * 0.45 * s);
            float ang = side * 0.45;                       // grains splay outward
            vec2 e = vec2(cos(ang) * v.x + sin(ang) * v.y, -sin(ang) * v.x + cos(ang) * v.y);
            vec2 R = vec2(sp * 0.95, W * 0.55) * s;
            float d = (length(e / R) - 1.0) * R.y;
            float ka = clamp(-d / aa + 0.5, 0.0, 1.0);
            vec3 gc = grain * (0.80 + 0.35 * smoothstep(-R.x, R.x, e.x)) * (e.y * side > 0.0 ? 0.88 : 1.08);
            c = mix(c, gc, ka);
            a = max(a, ka);
            // Awns: hair-thin bristles continuing from each grain (barley-like heads only).
            if (r2 > 0.5) {
                vec2 dirA = vec2(cos(ang * 0.6), side * sin(ang * 0.6));
                vec2 w0 = vec2(along, across) - (vec2((j + 0.75) * sp, side * W * 0.45 * s) + dirA * R.x);
                float t = clamp(dot(w0, dirA), 0.0, L * 0.6);
                float dl = length(w0 - dirA * t) - 0.35 * aa;
                float ka2 = clamp(-dl / aa + 0.5, 0.0, 1.0) * 0.55 * (1.0 - t / (L * 0.6));
                c = mix(c, vec3(0.80, 0.74, 0.54), ka2 * (1.0 - ka));
                a = max(a, ka2);
            }
        }
    }
    c = mix(c, SUN * 0.95, g * 0.25);                       // catches light in a gust
    return vec4(c, a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    if (p.y > HEIGHT * 1.45 + 0.06) {                      // nothing up here
        fragColor = base;
        return;
    }

    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    float shade = lum > 0.5 ? 0.6 : 1.0;                   // darker meadow on light themes
    float aa = 1.0 / iResolution.y;
    vec3 rgb = base.rgb;

    // Dark thatch at the very bottom so the roots sit in something.
    float ground = smoothstep(0.035, 0.0, p.y);
    rgb = mix(rgb, vec3(0.09, 0.10, 0.06) * shade, ground * 0.70 * INTENSITY);

    for (int l = 0; l < LAYERS; l++) {
        float fl = float(l);
        float depth = fl / float(LAYERS - 1);              // 0 = far row, 1 = front row
        float H       = HEIGHT * mix(0.48, 1.0, depth);
        float spacing = mix(0.0055, 0.0135, depth);
        float width   = mix(0.0015, 0.0040, depth);        // half-width at the base
        float alpha   = mix(0.58, 0.90, depth);
        float haze    = (1.0 - depth) * 0.45;

        if (p.y > H * 1.45 + 0.06) continue;

        // All blades in a row bend along the same curve (sideways offset ~ y^2),
        // so we can trace this pixel back to its likely root and test 7 blades.
        float K = 0.55 / H;
        float y2 = p.y * p.y;
        float xr = p.x - leanAt(p.x, fl) * K * y2;
        xr = p.x - leanAt(xr, fl) * K * y2;
        float cell = floor(xr / spacing);

        vec4 acc = vec4(0.0);
        for (int k = -3; k <= 3; k++) {
            float id = cell + float(k);
            float seed = id * 1.37 + fl * 31.7;
            float r1 = hash1(seed), r2 = hash1(seed + 2.1), r3 = hash1(seed + 4.3);
            float r4 = hash1(seed + 6.7), r5 = hash1(seed + 8.9), r6 = hash1(seed + 11.3);

            float x0 = (id + r1) * spacing;
            float g = gust(x0);
            // Shared lean + small fixed curl + a flutter that grows in the gust.
            float ln = leanAt(x0, fl) + 0.72 * (r2 - 0.5) * abs(r2 - 0.5)
                     + 0.035 * (0.4 + g) * sin(iTime * (2.2 + 1.3 * r3) + r1 * 6.28);
            bool stem = depth > 0.2 && r4 < HEADS;
            float h = H * patchHeight(x0, aspect) * mix(0.42, 1.12, r3 * r3 * (3.0 - 2.0 * r3));
            if (stem) h *= 1.28;
            h *= 1.0 - 0.13 * min(ln * ln, 2.0);           // a bent blade reaches less high

            float t = p.y / h;
            float cx = x0 + ln * K * y2;
            float slope = 2.0 * ln * K * p.y;
            float dx = (p.x - cx) * inversesqrt(1.0 + slope * slope);

            if (t < 1.0) {
                float hw;
                vec3 c;
                if (stem) {
                    hw = mix(0.0006, 0.0010, depth) * (1.0 - 0.3 * t);
                    c = mix(vec3(0.42, 0.46, 0.24), vec3(0.62, 0.58, 0.36), t);
                } else {
                    // Slight sheath swelling near the base, then a long natural taper.
                    hw = width * mix(0.6, 1.5, r5 * r5) * pow(1.0 - t, 0.7) * (0.8 + 0.2 * smoothstep(0.0, 0.12, t));
                    if (r6 < DRY) {
                        c = mix(vec3(0.62, 0.54, 0.34), vec3(0.78, 0.70, 0.48), r2);
                    } else {
                        vec3 olive  = vec3(0.36, 0.39, 0.17);
                        vec3 green  = vec3(0.27, 0.39, 0.18);
                        vec3 yellow = vec3(0.50, 0.55, 0.26);
                        vec3 cool   = vec3(0.21, 0.34, 0.22);
                        c = mix(mix(olive, green, r2), mix(yellow, cool, r3), r5 * 0.65);
                    }
                    // Tips go a little paler and yellower, like sun-dried ends.
                    c = mix(c, c * vec3(1.20, 1.12, 0.85) + 0.03, smoothstep(0.65, 1.0, t) * 0.6);
                    // Folded leaf: lit half, shaded half, and a fine pale midrib.
                    float s = dx / max(hw, 1e-5);
                    c *= mix(0.80, 1.08, smoothstep(0.3, -0.3, s));
                    float rib = exp(-s * s / 0.03) * smoothstep(0.05, 0.3, t) * (1.0 - t);
                    c += 0.10 * rib * smoothstep(0.8, 2.5, hw / aa);
                }
                // Darker near the ground where light can't reach.
                c *= mix(0.40, 1.0, smoothstep(0.0, 0.45, t));
                // Bent tips turn toward the light: a sheen that travels with the gust.
                float sh = g * smoothstep(0.35, 1.0, t);
                c = mix(c, SUN, sh * SHEEN);
                float a = clamp((hw - abs(dx)) / aa + 0.5, 0.0, 1.0);
                over(acc, c, a);
            }

            if (stem) {
                // Seed head continuing from the stem tip, nodding a bit more than the stem.
                vec2 tip = vec2(x0 + ln * K * h * h, h);
                vec2 dir = normalize(vec2(2.0 * ln * K * h + 0.15 * ln, 1.0));
                vec2 q = p - tip;
                float L = mix(0.026, 0.046, depth) * mix(0.8, 1.2, r1);
                vec4 hd = seedHead(dot(q, dir) + 0.002, dot(q, vec2(dir.y, -dir.x)), L, aa, r1, r2, r5, g);
                over(acc, hd.rgb, hd.a);
            }
        }

        if (acc.a > 0.0) {
            vec3 c = acc.rgb / acc.a;
            // Far rows: duller and darker, as if seen through a little air.
            c = mix(c, vec3(0.15, 0.19, 0.18), haze);
            // The whole field brightens slightly under a gust (blades show their pale sides).
            c *= 1.0 + 0.10 * gust(p.x);
            rgb = mix(rgb, c * shade, acc.a * alpha * INTENSITY);
        }
    }

    fragColor = vec4(rgb, base.a);
}
