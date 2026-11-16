// hearts — glossy 3D hearts rise in layers while a big heart beats in the corner and bursts into a shower of hearts.
// zh: 爱心
// group: festival
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 0.85;   // overall strength (0 = off)
const float BIG       = 0.23;   // beating heart height, as a fraction of the window height
const float CYCLE     = 8.0;    // seconds between two bursts of the big heart
const float BEAT      = 0.8;    // seconds per heartbeat (lub-dub), about 75 bpm
const float NEAR      = 0.12;   // height of the nearest floating hearts (window fraction)
const int   FLOATERS  = 12;     // floating hearts: 5 far, 4 mid, 3 near
const int   SHOWER    = 16;     // small hearts thrown out by each burst

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float dot2(vec2 v) { return dot(v, v); }

// Signed distance to a heart: tip at (0,0), top lobes near y = 1.1 (by Inigo Quilez).
float sdHeart(vec2 p) {
    p.x = abs(p.x);
    if (p.y + p.x > 1.0)
        return sqrt(dot2(p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
    return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

// Heart centred on its middle; it is 1.1 units tall and 1.2 wide.
float heartC(vec2 q) { return sdHeart(q + vec2(0.0, 0.55)); }

// A puffy height field over the flat heart: round like a cushion at the edge,
// so the edge normal turns sideways and catches the rim light.
float puff(float d) {
    float s = clamp(-d / 0.30, 0.0, 1.0);
    return 0.30 * sqrt(s * (2.0 - s));
}

mat2 rot(float a) { return mat2(cos(a), -sin(a), sin(a), cos(a)); }

// Pick one of three palettes: red, pink, magenta. Returns the deep (shadow) tone;
// the bright tone comes out through `bright`.
vec3 palette(float h, out vec3 bright) {
    if (h < 0.40) { bright = vec3(1.00, 0.22, 0.30); return vec3(0.42, 0.00, 0.06); }
    if (h < 0.75) { bright = vec3(1.00, 0.50, 0.70); return vec3(0.58, 0.04, 0.24); }
    bright = vec3(0.95, 0.34, 0.90); return vec3(0.40, 0.00, 0.34);
}

// A shaded glossy heart. q is in centred heart units, aa the edge softness in the
// same units, soft (0..1) dims the gloss on far, out-of-focus hearts.
// Returns colour and coverage.
vec4 glossy(vec2 q, float aa, float soft, vec3 deep, vec3 bright) {
    float d = heartC(q);
    float alpha = smoothstep(aa, -aa, d);
    if (alpha <= 0.0) return vec4(0.0);

    // Normal of the puffy surface, from two nearby samples.
    const float e = 0.012;
    float z = puff(d);
    vec3 n = normalize(vec3(z - puff(heartC(q + vec2(e, 0.0))),
                            z - puff(heartC(q + vec2(0.0, e))), e));

    vec3 L = normalize(vec3(-0.45, 0.65, 0.62));                 // key light from the upper left
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
    float diff = clamp(dot(n, L), 0.0, 1.0);
    vec3 col = mix(deep, bright, smoothstep(0.15, 1.0, diff));
    col *= 0.85 + 0.15 * smoothstep(-0.55, 0.4, q.y);           // a touch darker toward the tip

    // Rim light from behind on the lower right edge.
    float rim = pow(1.0 - n.z, 2.0) * (0.35 + 0.65 * clamp(dot(n.xy, vec2(0.6, -0.8)), 0.0, 1.0));
    col += mix(bright, vec3(1.0, 0.85, 0.92), 0.5) * rim * 0.55;

    // Gloss: a sharp specular along the lit shoulder plus a soft window-shaped
    // highlight on the left lobe, the classic "candy" look.
    float nh = max(dot(n, H), 0.0);
    float spec = pow(nh, 60.0) * 0.9 + pow(nh, 10.0) * 0.12;
    vec2 hq = rot(-0.6) * (q - vec2(-0.27, 0.20));
    float blob = smoothstep(1.0, 0.35, length(hq / vec2(0.15, 0.075)));
    float dot2nd = smoothstep(0.05, 0.015, length(q - vec2(-0.08, 0.30)));
    col += vec3(1.0) * (spec + 0.75 * blob + 0.6 * dot2nd) * (1.0 - 0.8 * soft);
    return vec4(col, alpha);
}

// Heartbeat: a sharp "lub" and a smaller "dub" a moment later. t is seconds
// from the lub (may be slightly negative just before it).
float lubdub(float t) {
    return exp(-pow(t / 0.055, 2.0)) + 0.6 * exp(-pow((t - 0.22) / 0.06, 2.0));
}

vec3 glowBlend(vec3 base, vec3 col, float g) {
    float lum = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    g = clamp(g, 0.0, 1.0);
    return lum > 0.5 ? mix(base, col * 0.7, g * 0.5) : base + col * g;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    vec3 rgb = base.rgb;

    // Dim everything over the top-left corner where the shell text lives.
    float textMask = 1.0 - 0.65 * smoothstep(0.75, 0.25,
                     length((p - vec2(0.0, 1.0)) / vec2(0.55 * aspect, 0.55)));

    // ---- Floating hearts, far to near so near ones cover far ones ----
    for (int i = 0; i < FLOATERS; i++) {
        float fi = float(i);
        float layer = i < 5 ? 0.0 : (i < 9 ? 1.0 : 2.0);
        float h1 = hash1(fi * 12.9898 + 1.0);
        float h2 = hash1(fi * 78.233 + 2.0);
        float h3 = hash1(fi * 39.425 + 3.0);

        float size = mix(0.035, NEAR, layer * 0.5) * mix(0.8, 1.0, h3);   // window fraction
        float speed = mix(0.035, 0.075, layer * 0.5) * mix(0.85, 1.15, h2);
        float range = 1.0 + 2.6 * size;
        float travel = iTime * speed / range + h1;
        float trip = floor(travel);
        float y = fract(travel) * range - 1.3 * size;            // enters and leaves off screen

        // A new column each trip (changed only while off screen, so nothing pops).
        float hx = hash1(fi * 7.31 + trip * 13.7);
        float x = (layer > 1.5 ? mix(0.30, 0.95, hx) : mix(0.04, 0.96, hx)) * aspect;
        float w = mix(0.5, 0.9, h3);
        float ph = fi * 2.3 + trip;
        float amp = 0.015 + 0.02 * layer;
        x += amp * sin(iTime * w + ph);

        float S = size / 1.1;
        vec2 q = (p - vec2(x, y)) / S;
        if (dot2(q) > 0.9) continue;                              // outside this heart

        // Lean into the sway; every third heart also turns slowly as it rises.
        float ang = -0.25 * cos(iTime * w + ph);
        if (mod(fi, 3.0) < 1.0) ang += 0.35 * sin(iTime * 0.45 + fi);
        q = rot(ang) * q;
        q.x /= 0.85 + 0.15 * cos(iTime * 0.7 + fi * 1.7);       // a slight 3D turn

        float soft = layer < 0.5 ? 1.0 : (layer < 1.5 ? 0.3 : 0.0);
        float aa = 1.5 / (iResolution.y * S) + 0.07 * soft;      // far ones out of focus
        vec3 bright;
        vec3 deep = palette(hash1(fi * 4.1), bright);
        vec4 hc = glossy(q, aa, soft, deep, bright);

        float fade = smoothstep(1.0 + size, 0.82, y);             // melt away near the top
        float a = hc.a * fade * textMask * mix(0.55, 0.92, layer * 0.5);
        rgb = mix(rgb, hc.rgb, a * INTENSITY);
    }

    // ---- The big beating heart in the lower right ----
    float S = BIG / 1.1;
    vec2 C = vec2(aspect - 0.17 - 0.6 * S, 0.11 + 0.55 * S);
    float clock = iTime + 0.3;                                    // already beating at start
    float ct = mod(clock, CYCLE);
    float burstT = 6.4 + 0.15;                                    // the moment it pops
    float last = CYCLE - 0.8;                                     // regrowth starts here

    // Beat index and time since that beat's lub (slightly negative just before it).
    float k = floor(ct / BEAT);
    float tb = ct - k * BEAT;
    float bi = k;
    if (tb > 0.6) { bi += 1.0; tb -= BEAT; }
    float strong = abs(bi - 7.0) < 0.5 ? 2.2 : 1.0;              // the big beat before the burst

    float scale, show;
    if (ct < 6.4) {
        scale = 1.0 + 0.07 * strong * lubdub(tb);
        show = 1.0;
    } else if (ct < last) {
        // Swell and pop.
        scale = 1.07 + 0.35 * smoothstep(6.4, burstT, ct);
        show = 1.0 - smoothstep(6.45, burstT + 0.05, ct);
    } else {
        // Grow back with a little overshoot (ease-out-back).
        float g = (ct - last) / 0.8;
        float gm = g - 1.0;
        scale = 1.0 + 2.7 * gm * gm * gm + 1.7 * gm * gm;
        scale *= 1.0 + 0.07 * lubdub(tb) * step(9.5, bi);        // the first beat of the next round
        show = smoothstep(0.0, 0.25, g);
    }

    vec2 pc = p - C;
    if (dot2(pc) < pow(S * 3.0, 2.0)) {
        vec2 q = pc / (S * max(scale, 0.05));
        float d = heartC(q) * scale;                               // distance in base heart units

        // Soft halo that swells with each beat.
        float beatGlow = min((scale - 1.0) * 6.0, 1.0);
        float halo = exp(-max(d, 0.0) * 4.0) * (0.18 + 0.25 * beatGlow) * show;

        // A heart-shaped glow ring running outward from each lub.
        float ring = 0.0;
        if (ct < 6.4 && tb >= 0.0) {
            float r = tb * 1.1;
            ring = exp(-pow((d - r) / (0.03 + 0.05 * tb), 2.0)) * pow(1.0 - tb / BEAT, 2.0) * 0.55 * strong;
        }
        // A bigger ring when it bursts.
        float ab = ct - burstT;
        if (ab > -0.05 && ab < 1.2) {
            float r = max(ab, 0.0) * 1.6;
            ring += exp(-pow((d - r) / (0.05 + 0.08 * ab), 2.0)) * pow(1.0 - ab / 1.2, 2.0) * 0.9;
        }
        rgb = glowBlend(rgb, vec3(1.0, 0.30, 0.50), (halo + ring) * INTENSITY);

        if (show > 0.0) {
            vec4 hc = glossy(q, 1.5 / (iResolution.y * S * scale), 0.0,
                             vec3(0.45, 0.00, 0.07), vec3(1.0, 0.20, 0.30));
            rgb = mix(rgb, hc.rgb, hc.a * show * 0.95 * INTENSITY);
        }

        // Flash at the pop.
        float flash = exp(-pow(ab / 0.1, 2.0)) * exp(-max(d, 0.0) * 5.0) * 0.35;
        rgb = glowBlend(rgb, vec3(1.0, 0.75, 0.85), flash * INTENSITY);
    }

    // ---- The shower of small hearts after a burst ----
    float age = mod(clock - burstT, CYCLE);                       // seconds since the last pop
    if (age < 3.6 && iTime + 0.3 > burstT) {
        for (int j = 0; j < SHOWER; j++) {
            float fj = float(j);
            float a1 = hash1(fj * 17.13 + 5.0);
            float a2 = hash1(fj * 31.71 + 6.0);
            float a3 = hash1(fj * 53.37 + 7.0);
            // Spread round the whole circle but lean up and to the left, into the window.
            float th = 6.2831 * (fj + 0.6 * a1) / float(SHOWER);
            vec2 dir = normalize(vec2(cos(th), sin(th)) + vec2(-0.35, 0.35));
            float v = mix(0.35, 0.75, a2);
            const float drag = 1.6;
            vec2 pos = C + S * vec2((a1 - 0.5) * 0.6, (a3 - 0.5) * 0.5)
                     + dir * v * (1.0 - exp(-drag * age)) / drag
                     + vec2(0.02 * sin(age * 2.0 + fj), 0.05 * age * age * 0.5 + 0.03 * age);
            float size = mix(0.03, 0.06, a3) * smoothstep(0.0, 0.25, age);
            float Sj = max(size, 0.002) / 1.1;
            vec2 q = (p - pos) / Sj;
            if (dot2(q) > 0.9) continue;
            q = rot((a1 - 0.5) * 2.5 * (1.0 - exp(-age)) + 0.3 * sin(age * 1.5 + fj)) * q;
            vec3 bright;
            vec3 deep = palette(a2, bright);
            vec4 hc = glossy(q, 1.5 / (iResolution.y * Sj), 0.0, deep, bright);
            float fade = 1.0 - smoothstep(2.4, 3.6, age);
            rgb = mix(rgb, hc.rgb, hc.a * fade * textMask * 0.95 * INTENSITY);
        }
    }

    fragColor = vec4(rgb, base.a);
}
