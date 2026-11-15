// runes — faint glowing rune glyphs appear, float slowly upward and dissolve.
// zh: 符文
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.50;   // overall brightness (0 = off)
const int   COUNT     = 9;      // glyphs alive at any moment
const int   BRANCHES  = 5;      // side strokes per glyph (some are skipped)
const float SIZE      = 0.045;  // glyph half-height in screen heights

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0;
    return mix(mix(hash1(n), hash1(n + 1.0), f.x),
               mix(hash1(n + 57.0), hash1(n + 58.0), f.x), f.y);
}

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// A made-up rune: one vertical staff plus a few straight branches from points
// on the staff to points on a small grid (x in -0.6/0/0.6, y in -1..1).
// That is what makes angular carved letters look "runic" without being any
// real script. Returns the distance to the nearest stroke.
float glyph(vec2 q, float seed) {
    float sx = (floor(hash1(seed) * 3.0) - 1.0) * 0.6 * step(0.4, hash1(seed + 0.3));
    float d = segDist(q, vec2(sx, -1.0), vec2(sx, 1.0));
    for (int j = 0; j < BRANCHES; j++) {
        float s = seed + float(j) * 7.13;
        if (hash1(s + 0.1) < 0.3) continue;
        vec2 a = vec2(sx, floor(hash1(s + 0.2) * 5.0) * 0.5 - 1.0);
        float bx = (floor(hash1(s + 0.4) * 3.0) - 1.0) * 0.6;
        if (abs(bx - sx) < 0.1) bx = sx > 0.0 ? -0.6 : 0.6;
        float by = clamp(a.y + (floor(hash1(s + 0.5) * 4.0) - 1.5) * 0.6, -1.0, 1.0);
        d = min(d, segDist(q, a, vec2(bx, by)));
    }
    // About half of them sit inside a seal ring.
    if (hash1(seed + 0.9) < 0.5) d = min(d, abs(length(q) - 1.35));
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    vec3 glow = vec3(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        // Each slot shows one glyph per cycle, then picks a new one somewhere else.
        float period = 8.0 + 4.0 * hash1(fi * 3.7 + 0.2);
        float tt = iTime / period + hash1(fi * 9.1 + 0.7);
        float cyc = floor(tt);
        float life = fract(tt);
        float seed = fi * 17.3 + cyc * 3.11;

        vec2 pos = vec2((0.05 + 0.90 * hash1(seed + 1.1)) * aspect,
                        0.05 + 0.55 * hash1(seed + 2.2) + life * 0.14);
        float size = SIZE * mix(0.75, 1.15, hash1(seed + 3.3));
        vec2 q = (p - pos) / size;
        if (abs(q.x) > 1.6 || abs(q.y) > 1.6) continue;   // far away: skip the strokes

        float d = glyph(q, seed);
        float line = smoothstep(0.09, 0.02, d) + 0.35 * exp(-d * 9.0);

        // Fade in, hold, then crumble away: noise decides which bits go first.
        float fadeIn = smoothstep(0.0, 0.2, life);
        float gone = smoothstep(0.55, 1.0, life);
        float crumble = smoothstep(gone - 0.1, gone + 0.1, noise(q * 3.0 + seed));
        float shimmer = 0.8 + 0.2 * sin(iTime * 3.0 + fi);

        vec3 col = mix(vec3(0.45, 0.85, 1.0), vec3(0.80, 0.60, 1.0), hash1(seed + 4.4));
        glow += col * line * fadeIn * crumble * shimmer;
    }

    fragColor = vec4(base.rgb + min(glow, vec3(1.0)) * INTENSITY, base.a);
}
