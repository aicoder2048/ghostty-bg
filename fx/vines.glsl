// vines — leafy vines grow in from the edges, unfold leaves, flower, wither and regrow.
// zh: 藤蔓
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath (light shapes on dark themes, dark shapes on light themes).

const float INTENSITY = 0.85;   // overall strength (0 = off)
const int   VINES     = 6;      // vines alive at once (each on its own clock)
const int   SEGS      = 7;      // straight pieces per stem: the main per-pixel cost
const float PERIOD    = 13.0;   // seconds per vine life: grow, rest, wither, pause
const float GROW      = 4.5;    // seconds for the tip to reach full length
const float WITHER    = 9.0;    // when withering starts (fully faded 2 s later)
const float LEAF      = 0.078;  // leaf length, in window heights
const float FLOWER    = 0.030;  // flower radius, in window heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec3 blend(vec3 base, vec3 color, float a) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    a = clamp(a, 0.0, 1.0);
    return lum > 0.5 ? mix(base, color * 0.35, a * 0.8) : base + color * a;
}

// Distance to the segment a-b.
float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// A leaf growing from base along direction d. Returns (coverage, highlight):
// the highlight is the midrib plus a thin rim, so the leaf reads on dark themes
// while its body stays see-through.
vec2 leaf(vec2 p, vec2 base, vec2 d, float len, float aa) {
    if (len < 0.004) return vec2(0.0);
    vec2 q = p - base;
    float along = dot(q, d) / len;
    if (along < 0.0 || along > 1.0) return vec2(0.0);
    float across = abs(q.x * d.y - q.y * d.x);
    float hw = len * 0.30 * pow(sin(3.1416 * pow(along, 0.7)), 0.9);   // round base, pointed tip
    float inside = smoothstep(aa, -aa, across - hw);
    float rim = 1.0 - smoothstep(0.0, 0.005, hw - across);
    float vein = smoothstep(0.003, 0.0, across) * (1.0 - along);
    return vec2(inside, inside * max(rim, vein));
}

// A five-petal flower opening with open (0..1). Returns (coverage, centre).
vec2 flower(vec2 p, vec2 c, float open, float spin, float aa) {
    float R = FLOWER * open;
    vec2 q = p - c;
    float r = length(q);
    if (R < 0.002 || r > R * 1.1) return vec2(0.0);
    float ang = atan(q.y, q.x) + spin;
    float petal = R * (0.45 + 0.55 * abs(cos(2.5 * ang)));
    float a = smoothstep(aa, -aa, r - petal);
    return vec2(a, smoothstep(R * 0.30, R * 0.18, r));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float aa = 1.5 / iResolution.y;

    vec3 rgb = base.rgb;
    for (int i = 0; i < VINES; i++) {
        float fi = float(i);
        // Spread the vines over the cycle; the +0.6 makes one vine start growing
        // right away and others already part-grown when the effect switches on.
        float clock = iTime + fi * PERIOD / float(VINES) + 0.6 + 0.5 * hash1(fi * 3.7);
        float t = mod(clock, PERIOD);
        float cyc = floor(clock / PERIOD);
        float fade = 1.0 - smoothstep(WITHER, WITHER + 2.0, t);
        if (fade <= 0.0) continue;

        float seed = fi * 17.13 + cyc * 5.71;
        float h1 = hash1(seed + 1.0), h2 = hash1(seed + 2.0);
        float h3 = hash1(seed + 3.0), h4 = hash1(seed + 4.0);

        // Where it roots: mostly the right edge and the bottom; one vine on the
        // lower left, kept short so the shell text in the top-left stays clear.
        int edge = (i == 0 || i == 2 || i == 5) ? 0 : (i == 3 ? 2 : 1);   // 0 right, 1 bottom, 2 left
        vec2 root;
        float th0, bend, len;
        if (edge == 0) {
            root = vec2(aspect + 0.01, mix(0.0, 0.32, h1));
            th0 = mix(2.05, 2.55, h2);                  // up and inward
            bend = -mix(0.5, 1.0, h3);                  // then turns back up along the wall
            len = mix(0.45, 0.62, h4);
        } else if (edge == 1) {
            root = vec2(mix(0.28, 0.97, h1) * aspect, -0.01);
            th0 = 1.5708 + (h2 - 0.5) * 0.9;
            bend = (h3 - 0.5) * 1.4;
            len = mix(0.30, 0.46, h4);
        } else {
            root = vec2(-0.01, mix(0.0, 0.18, h1));
            th0 = mix(0.75, 1.20, h2);
            bend = mix(0.3, 0.7, h3);
            len = mix(0.36, 0.48, h4);
        }

        // Cheap early out: skip pixels nowhere near this vine.
        vec2 mid = root + 0.45 * len * vec2(cos(th0 + 0.5 * bend), sin(th0 + 0.5 * bend));
        if (length(p - mid) > 0.62 * len + LEAF + FLOWER) continue;

        // Growth: fast at first so it shows in the first second, easing in at the end.
        float x = clamp(t / GROW, 0.0, 1.0);
        float g = 1.0 - pow(1.0 - x, 1.7);
        float wither = 1.0 - fade;
        float wig = 6.2831 * hash1(seed + 5.0);
        float curl = (h3 > 0.5 ? 1.0 : -1.0) * 1.1;  // which way the tip hooks
        float segLen = len / float(SEGS);

        vec3 vc = vec3(0.0);
        float va = 0.0;
        vec2 P = root;
        float stem = 1e3;
        for (int k = 0; k < SEGS; k++) {
            float s0 = float(k) / float(SEGS);
            if (s0 >= g) break;
            float sm = s0 + 0.5 / float(SEGS);
            // Heading: a slow bend, a gentle wave, and a hook just behind the tip
            // that travels forward as the vine grows.
            float tipNear = clamp(1.0 - (g - sm) / 0.30, 0.0, 1.0);
            float th = th0 + bend * sm + 0.30 * sin(sm * 9.0 + wig) + curl * tipNear * tipNear;
            vec2 d = vec2(cos(th), sin(th));
            float frac = clamp((g - s0) * float(SEGS), 0.0, 1.0);
            vec2 E = P + d * segLen * frac;

            float w = mix(0.008, 0.0035, sm);
            stem = min(stem, segDist(p, P, E) - w);

            // Two leaves per piece, on opposite sides, unfolding once the tip
            // has passed: they swing out from the stem as they grow.
            vec2 n = vec2(-d.y, d.x);
            for (int j = 0; j < 2; j++) {
                float fj = float(j);
                float sl = s0 + (0.30 + 0.45 * fj) / float(SEGS);
                if (sl > g || sl < 0.06) continue;
                float unfold = smoothstep(sl, sl + 0.12, g);
                float side = (mod(float(k) + fj, 2.0) < 0.5) ? 1.0 : -1.0;
                vec2 ld = normalize(d + n * side * (0.3 + 1.0 * unfold) * (1.0 + 0.6 * wither));
                float ll = LEAF * unfold * (1.0 - 0.35 * sm) * (1.0 - 0.3 * wither);
                vec2 lf = leaf(p, P + d * segLen * (0.30 + 0.45 * fj), ld, ll, aa);
                vec3 lc = mix(vec3(0.18, 0.55, 0.26), vec3(0.62, 1.0, 0.55), lf.y);
                float la = lf.x * (0.45 + 0.55 * lf.y);
                vc = mix(vc, lc, la);
                va = max(va, la);
            }

            // A side flower partway up, opening a while after the tip goes by.
            if (k == SEGS / 2) {
                float op = smoothstep(sm + 0.15, sm + 0.40, g);
                vec2 fl = flower(p, P - n * 0.022 * (curl > 0.0 ? 1.0 : -1.0), op, wig, aa);
                vec3 fc = h4 < 0.33 ? vec3(1.0, 0.95, 0.95) : h4 < 0.66 ? vec3(1.0, 0.62, 0.80) : vec3(1.0, 0.88, 0.35);
                fc = mix(fc, vec3(1.0, 0.75, 0.20), fl.y);
                vc = mix(vc, fc, fl.x);
                va = max(va, fl.x);
            }

            P = E;
        }

        // The stem goes under the leaves' highlights but over their bodies.
        float sa = smoothstep(aa, -aa, stem);
        vc = mix(vc, vec3(0.50, 0.82, 0.38), sa * 0.9);
        va = max(va, sa * 0.9);

        // The tip flower opens as the vine reaches full length.
        float op = smoothstep(0.88, 1.0, g) * smoothstep(GROW - 0.6, GROW + 0.8, t);
        vec2 fl = flower(p, P, op * 1.2, wig + 1.0, aa);
        vec3 fc = h2 < 0.33 ? vec3(1.0, 0.95, 0.95) : h2 < 0.66 ? vec3(1.0, 0.62, 0.80) : vec3(1.0, 0.88, 0.35);
        fc = mix(fc, vec3(1.0, 0.75, 0.20), fl.y);
        vc = mix(vc, fc, fl.x);
        va = max(va, fl.x);

        // Withering: colours dry out toward tan as the vine fades away.
        vc = mix(vc, vec3(0.75, 0.62, 0.38) * 0.8, wither);
        float dim = edge == 2 ? 0.75 : 1.0;          // the left vine stays a little quieter
        rgb = blend(rgb, vc, va * fade * dim * INTENSITY);
    }

    fragColor = vec4(rgb, base.a);
}
