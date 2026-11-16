// lotus — a lively lotus pond along the bottom: big flowers opening and closing, bobbing pads, ripples and a visiting dragonfly.
// zh: 荷花
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.75;   // overall strength (0 = off)
const float WATER     = 0.235;  // far edge of the pond (the water line), in window-heights
const float BLOOM     = 11.0;   // seconds for one open-close cycle of a flower
const float DROP      = 4.5;    // seconds between drops for one ripple source (3 sources, staggered)
const float FLY       = 10.0;   // seconds between dragonfly visits
const float DRAGON    = 0.16;   // dragonfly length, in window-heights

// Lily pads, far to near: x (fraction of width), y, radius (half width), notch angle.
const vec4 PAD[9] = vec4[9](
    vec4(0.05, 0.195, 0.060, 1.0),
    vec4(0.33, 0.205, 0.065, 4.0),
    vec4(0.55, 0.190, 0.060, 2.5),
    vec4(0.77, 0.200, 0.070, 5.2),
    vec4(0.44, 0.140, 0.095, 0.7),
    vec4(0.90, 0.120, 0.105, 3.3),
    vec4(0.27, 0.090, 0.125, 2.0),
    vec4(0.12, 0.045, 0.160, 4.6),
    vec4(0.66, 0.035, 0.170, 1.4)
);

// Flowers, far to near: x (fraction of width), y where the stem leaves the water,
// size (bloom height, in window-heights), phase of the open-close cycle.
const vec4 FLOWER[5] = vec4[5](
    vec4(0.31, 0.205, 0.080, 3.0),
    vec4(0.44, 0.150, 0.115, 2.1),
    vec4(0.87, 0.130, 0.125, 0.9),
    vec4(0.14, 0.070, 0.185, 0.0),
    vec4(0.64, 0.055, 0.170, 4.2)
);

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 rot(vec2 q, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * q.x - s * q.y, s * q.x + c * q.y);
}

// Painter's "over": put a new shape (mask m, opacity a, colour c) on top of what is there.
void over(inout vec3 col, inout float sh, vec3 c, float m, float a) {
    col = mix(col, c, m);
    sh = max(sh * (1.0 - m), m * a);
}

// One petal standing on its base, pointing up (+y): broad in the middle, pointed tip.
// Returns the mask in x and how far across the petal we are in y (0 centre, 1 edge).
vec2 petal(vec2 q, float len, float wide) {
    float t = q.y / len;
    if (t < 0.0 || t > 1.0) return vec2(0.0);
    float w = wide * pow(sin(3.1416 * t), 0.65) * (1.0 - 0.3 * t) + 1e-4;
    return vec2(smoothstep(0.0025, 0.0, abs(q.x) - w), abs(q.x) / w);
}

// Where the open-close cycle of flower i is (0 = closed bud, 1 = wide open).
float openness(int i) {
    return 0.5 + 0.5 * sin(6.2831 * iTime / BLOOM + FLOWER[i].w * 1.7);
}

// Base of the bloom (top of the stem) of flower i, with its gentle bob and sway.
vec2 bloomBase(int i, float aspect) {
    vec4 f = FLOWER[i];
    float sway = 0.010 * sin(iTime * 0.7 + f.w * 2.0);
    float bob  = 0.005 * sin(iTime * 1.1 + f.w * 3.0);
    return vec2(f.x * aspect + sway, f.y + 0.45 * f.z + bob);
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). Flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 color = vec3(0.0);
    float shape = 0.0;

    // ---- The pond: water, ripples, pads, flowers (all in the bottom ~45%) ----
    if (p.y < 0.46) {
        // Water: a soft blue tint below a glowing, gently waving water line,
        // with drifting light streaks (sky reflections) on the surface.
        float wl = WATER + 0.004 * sin(p.x * 9.0 - iTime * 0.9);
        float below = smoothstep(wl + 0.002, wl - 0.002, p.y);
        float line = smoothstep(0.006, 0.0, abs(p.y - wl));
        float depth = clamp(p.y / WATER, 0.0, 1.0);                // 0 near us, 1 far
        float rows = sin(p.y * mix(70.0, 220.0, depth) + 0.6 * sin(p.x * 5.0 + iTime * 0.8));
        float dash = smoothstep(0.2, 0.9, sin(p.x * mix(6.0, 18.0, depth) - iTime * 0.6 + floor(p.y * 90.0) * 1.7));
        float streak = smoothstep(0.85, 1.0, rows) * dash * below;
        color = vec3(0.55, 0.78, 0.92);
        shape = below * 0.10 + line * 0.45 + streak * 0.25;

        // Ripple rings: three sources take turns, a drop falls and rings spread out.
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float tt = iTime / DROP + fi / 3.0 + 0.85;
            float cyc = floor(tt), ph = fract(tt);
            vec2 c = vec2((0.08 + 0.84 * hash1(cyc * 7.1 + fi * 3.3)) * aspect,
                          0.02 + 0.19 * hash1(cyc * 3.9 + fi * 5.7));
            float sc = mix(1.3, 0.6, c.y / WATER);                 // nearer = bigger
            if (ph < 0.06) {                                       // the falling drop
                vec2 dp = c + vec2(0.0, 0.12 * (1.0 - ph / 0.06));
                float drop = smoothstep(0.007, 0.0, length((p - dp) * vec2(1.0, 0.45)));
                over(color, shape, vec3(0.8, 0.92, 1.0), drop, 0.8);
            } else {
                float r = (ph - 0.06) / 0.94;
                float d = length((p - c) * vec2(1.0, 3.2)) / sc;
                float fade = (1.0 - r) * (1.0 - r);
                float ring = smoothstep(0.009, 0.0, abs(d - r * 0.22))
                           + 0.8 * smoothstep(0.007, 0.0, abs(d - r * 0.15))
                           + 0.5 * smoothstep(0.005, 0.0, abs(d - r * 0.08));
                over(color, shape, vec3(0.75, 0.90, 1.0), min(ring, 1.0) * fade, 0.85);
            }
        }

        // Lily pads: flat ovals seen at a low angle, notch cut out, veins and a bright rim.
        for (int i = 0; i < 9; i++) {
            vec4 pd = PAD[i];
            float fi = float(i);
            vec2 c = vec2(pd.x * aspect + 0.015 * sin(iTime * 0.17 + fi * 2.3),
                          pd.y + 0.006 * sin(iTime * (0.9 + 0.15 * fi) + fi * 1.9));
            float r = pd.z;
            if (abs(p.x - c.x) > r + 0.01 || abs(p.y - c.y) > r * 0.5) continue;
            float k = mix(2.3, 3.4, clamp(pd.y / WATER, 0.0, 1.0));   // flatter when far
            vec2 q = rot(p - c, 0.05 * sin(iTime * 0.6 + fi));
            vec2 qq = q * vec2(1.0, k);
            float rr = length(qq);
            float body = smoothstep(0.003, 0.0, rr - r);
            float a = atan(qq.y, qq.x) - pd.w;
            float cut = smoothstep(0.08, 0.15, abs(mod(a + 3.1416, 6.2831) - 3.1416));
            float m = body * cut;
            if (m <= 0.0) continue;
            float rim = smoothstep(r - 0.016, r - 0.003, rr);
            float vein = smoothstep(0.88, 1.0, cos(a * 4.5)) * smoothstep(0.1 * r, 0.35 * r, rr) * (1.0 - rim);
            // Darker in the middle, lighter outward, a pale rim and pale veins.
            vec3 green = mix(vec3(0.16, 0.45, 0.24), vec3(0.32, 0.68, 0.34), rr / r);
            green = mix(green, vec3(0.65, 0.92, 0.55), max(rim * 0.9, vein * 0.8));
            // A slow glint sliding across the pads like light on wet leaves.
            green += 0.15 * smoothstep(0.7, 1.0, sin(q.x * 25.0 - iTime * 1.3 + fi)) * (rr / r);
            over(color, shape, green, m, 0.70);
        }

        // Flowers: stem, a back row of wide petals, the seed pod, then a front row.
        for (int i = 0; i < 5; i++) {
            vec4 f = FLOWER[i];
            vec2 b = bloomBase(i, aspect);
            float len = f.z;
            // Stem: from the water up to the bloom, leaning with the sway.
            float sy = clamp((p.y - f.y) / (b.y - f.y), 0.0, 1.0);
            float sx = mix(f.x * aspect, b.x, sy * sy);
            float sw = mix(0.0045, 0.0030, sy) * (len / 0.15);
            float stem = smoothstep(sw, sw * 0.4, abs(p.x - sx)) * step(f.y - 0.004, p.y) * step(p.y, b.y + 0.01);
            over(color, shape, vec3(0.30, 0.60, 0.32), stem, 0.85);

            vec2 q = p - b;
            if (length(q - vec2(0.0, len * 0.5)) > len * 1.15) continue;
            float o = openness(i);
            // Back row: five petals; they fan out wide when open, close into a bud.
            for (int k = 0; k < 5; k++) {
                float ang = (float(k) - 2.0) * mix(0.10, 0.58, o);
                vec2 m = petal(rot(q, ang), len * 0.92, len * mix(0.20, 0.27, o));
                vec3 pink = mix(vec3(0.95, 0.55, 0.72), vec3(0.88, 0.28, 0.52), clamp(q.y / len, 0.0, 1.0));
                pink *= 1.0 - 0.35 * smoothstep(0.75, 1.0, m.y);        // darker edge separates petals
                over(color, shape, pink, m.x, 0.95);
            }
            // The golden seed pod shows more as the flower opens.
            float pod = smoothstep(0.003, 0.0, length((q - vec2(0.0, len * 0.30)) * vec2(1.0, 1.7)) - len * mix(0.10, 0.20, o));
            over(color, shape, vec3(1.0, 0.85, 0.35), pod * smoothstep(0.15, 0.5, o), 1.0);
            // Front row: three paler, more upright petals.
            for (int k = 0; k < 3; k++) {
                float ang = (float(k) - 1.0) * mix(0.08, 0.50, o);
                vec2 r = rot(q + vec2(0.0, 0.006), ang);
                vec2 m = petal(r, len * mix(0.95, 0.80, o), len * mix(0.20, 0.27, o));
                vec3 pink = mix(vec3(1.0, 0.92, 0.94), vec3(1.0, 0.48, 0.68), clamp(r.y / len, 0.0, 1.0));
                pink *= 1.0 - 0.30 * smoothstep(0.75, 1.0, m.y);
                pink += 0.15 * smoothstep(0.25, 0.0, m.y);              // a light centre vein
                over(color, shape, pink, m.x, 1.0);
            }
        }
    }

    // ---- The dragonfly: darts in, hovers over a flower, darts away ----
    float ft = iTime + 0.9;                                        // already arriving at t = 0
    float tt = mod(ft, FLY);
    float cyc = floor(ft / FLY);
    if (tt < 8.0) {
        int fi = int(mod(cyc * 3.0 + 3.0, 5.0));                   // a different flower each visit
        vec2 b = bloomBase(fi, aspect);
        vec2 target = b + vec2(0.0, FLOWER[fi].z * 1.05 + 0.03);
        float side = mod(cyc, 2.0) < 0.5 ? 1.0 : -1.0;
        vec2 entry = vec2(side > 0.0 ? aspect + 0.15 : -0.15, 0.36);
        vec2 exitp = vec2(side > 0.0 ? -0.15 : aspect + 0.15, 0.30);
        vec2 pos;
        vec2 dir = target - entry;
        if (tt < 1.8) {
            float s = smoothstep(0.0, 1.0, tt / 1.8);
            pos = mix(entry, target, s) + vec2(0.0, 0.07 * sin(s * 3.1416));
        } else if (tt < 6.5) {
            // Hover with a nervous jitter, and one quick hop sideways and back.
            float hop = smoothstep(3.8, 4.0, tt) * (1.0 - smoothstep(5.2, 5.4, tt));
            pos = target + vec2(0.006 * sin(tt * 7.0) + 0.003 * sin(tt * 19.0),
                                0.005 * sin(tt * 5.0 + 1.0) + 0.002 * sin(tt * 23.0))
                         + hop * vec2(-0.05 * side, 0.015);
            dir = vec2(-side, 0.15 * sin(tt * 1.3));
        } else {
            float s = (tt - 6.5) / 1.5;
            s = s * s;
            pos = mix(target, exitp, s) + vec2(0.0, 0.08 * sin(s * 3.1416));
            dir = exitp - target;
        }
        float S = DRAGON;
        vec2 q = rot(p - pos, -atan(dir.y, dir.x));                // local frame, +x = forward
        if (length(q) < S * 0.75) {
            // Four see-through wings, beating so fast they shimmer.
            for (int w = 0; w < 4; w++) {
                float fw = float(w);
                float up = fw < 2.0 ? 1.0 : -1.0;
                bool front = mod(fw, 2.0) < 0.5;
                vec2 root = vec2(front ? 0.27 * S : 0.20 * S, 0.0);
                float wa = up * ((front ? 1.30 : 1.80) + 0.18 * sin(iTime * 55.0 + fw));
                vec2 wq = rot(q - root, -wa);
                float e = length(vec2((wq.x - 0.24 * S) / (0.24 * S), wq.y / (0.055 * S)));
                float wing = smoothstep(1.0, 0.85, e);
                float edge = smoothstep(0.75, 0.95, e) * wing;
                float shim = 0.50 + 0.15 * sin(iTime * 40.0 + fw * 1.7);
                over(color, shape, mix(vec3(0.85, 0.95, 1.0), vec3(1.0), edge), wing, shim + 0.3 * edge);
            }
            // Body: long thin abdomen, chunky thorax, round head with big eyes.
            float h = clamp((0.20 * S - q.x) / (0.80 * S), 0.0, 1.0);
            float abd = smoothstep(0.003, 0.0, abs(q.y) - 0.028 * S * (1.0 - 0.5 * h))
                      * step(-0.60 * S, q.x) * step(q.x, 0.22 * S);
            float bands = 0.8 + 0.2 * step(0.5, fract(h * 7.0));
            float thx = smoothstep(0.003, 0.0, length((q - vec2(0.27 * S, 0.0)) * vec2(1.0, 1.4)) - 0.07 * S);
            float head = smoothstep(0.003, 0.0, length(q - vec2(0.40 * S, 0.0)) - 0.055 * S);
            vec3 teal = vec3(0.25, 0.85, 0.95);
            over(color, shape, teal * bands, abd, 1.0);
            over(color, shape, mix(teal, vec3(0.2, 0.6, 1.0), 0.4), thx, 1.0);
            over(color, shape, vec3(0.45, 1.0, 0.8), head, 1.0);
        }
    }

    fragColor = vec4(blend(base.rgb, color, shape * INTENSITY), base.a);
}
