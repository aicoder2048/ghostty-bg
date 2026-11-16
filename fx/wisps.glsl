// wisps — ghostly blue-green spirit flames drift, circle and split above a faintly lit mist.
// zh: 鬼火
// group: fantasy
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.75;   // overall brightness (0 = off)
const int   COUNT     = 5;      // wandering wisps (plus one that splits off wisp 0)
const float CORE      = 0.021;  // radius of a wisp's glowing core, in window heights
const float FLAME     = 0.105;  // length of the flame tongue
const float SMOKE     = 0.24;   // length of the smoky tendril behind the flame
const float MIST      = 1.00;   // strength of the ground mist (0 = none)
const float SPLIT_T   = 15.0;   // seconds between split-and-rejoin cycles
const float GATHER_T  = 24.0;   // seconds between gatherings

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

float noise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0;
    return mix(mix(hash1(n), hash1(n + 1.0), f.x),
               mix(hash1(n + 57.0), hash1(n + 58.0), f.x), f.y);
}

// Where the gathering happens: lower right, drifting a little.
vec2 gatherCenter(float t, float aspect) {
    return vec2(aspect * 0.76 + 0.06 * sin(t * 0.07), 0.24 + 0.03 * sin(t * 0.11));
}

// 0 = everyone wanders freely, 1 = everyone circles the gathering point.
float gatherAmount(float t) {
    float ph = mod(t + 6.0, GATHER_T);
    return smoothstep(0.0, 4.0, ph) * (1.0 - smoothstep(9.0, 13.0, ph));
}

// Smooth meandering path for wisp i, blended into a slow orbit while gathered.
// Only sums of slow sines, so motion is always eased and never jumps.
vec2 wispPos(float fi, float t, float aspect) {
    float a = hash1(fi * 12.9898 + 1.0);
    float b = hash1(fi * 78.233 + 2.0);
    float c = hash1(fi * 39.425 + 3.0);
    vec2 home = vec2(aspect * (0.50 + 0.42 * a), 0.10 + 0.24 * b);
    vec2 wander = home + vec2(
        0.16 * sin(t * (0.10 + 0.05 * c) + fi * 2.3) + 0.06 * sin(t * (0.23 + 0.07 * a) + fi * 5.1),
        0.05 * sin(t * (0.13 + 0.05 * b) + fi * 1.7) + 0.018 * sin(t * (0.9 + 0.4 * c) + fi * 3.0));
    // Pairs circling each other while gathered: alternate radii and directions.
    float ang = t * (0.45 + 0.1 * c) * (mod(fi, 2.0) < 0.5 ? 1.0 : -1.0) + fi * 1.2566;
    float rad = 0.06 + 0.04 * mod(fi, 2.0);
    vec2 orbit = gatherCenter(t, aspect) + rad * vec2(cos(ang) * 1.4, sin(ang) * 0.7);
    return mix(wander, orbit, gatherAmount(t) * (0.75 + 0.25 * c));
}

// Light of one wisp at point p: core, flame tongue trailing up and behind, smoke.
// Returns rgb light; 'halo' gets the soft surrounding glow (also used to light the mist).
vec3 wispLight(vec2 p, vec2 pos, vec2 vel, float fi, float t, float bright, out float halo) {
    vec2 d = p - pos;
    float r2 = dot(d, d);
    halo = bright * 0.014 / (r2 + 0.014);
    // Cheap early-out: pixels far from the flame only get the halo.
    if (r2 > (SMOKE + 0.04) * (SMOKE + 0.04)) return vec3(0.0);

    // The flame leans up and away from the direction of travel.
    vec2 lean = vel * 4.0;
    lean *= min(1.0, 0.8 / max(length(lean), 1e-4));   // cap the tilt so it never lies flat
    vec2 dir = normalize(vec2(0.0, 1.0) - lean);
    vec2 perp = vec2(dir.y, -dir.x);
    float along = dot(d, dir);
    float across = dot(d, perp);

    // Licking sway grows toward the tip.
    float s = max(along, 0.0);
    across += s * (0.16 * sin(s * 26.0 - t * 3.5 + fi * 3.0)
                 + 0.45 * (noise(vec2(s * 18.0 - t * 2.6, fi * 7.0)) - 0.5));

    // Core: a soft round glow, hot white-cyan in the middle.
    float core = exp(-r2 / (CORE * CORE));
    float inner = exp(-r2 / (CORE * CORE * 0.18));

    // Flame tongue: a teardrop that thins toward the tip, with flickering streaks.
    float u = clamp(along / FLAME, -1.0, 1.0);
    float w = CORE * (along < 0.0 ? 1.2 : 1.35 * pow(max(1.0 - u, 0.0), 0.65) + 0.002);
    float body = exp(-(across * across) / (w * w)) * (along < 0.0 ? exp(-along * along / (CORE * CORE * 1.3)) : smoothstep(1.0, 0.25, u));
    // Separate tongues: noise across the flame, scrolling upward.
    float streak = 0.35 + 0.9 * noise(vec2(across * 110.0 + fi * 5.0, along * 26.0 - t * 4.0 + fi * 9.0));
    float flame = body * streak;

    // Smoke: a wide, curling, fading tendril beyond the flame tip.
    float sm = 0.0;
    if (along > 0.0) {
        float v = along / SMOKE;
        float curl = across + 0.04 * v * sin(v * 9.0 - t * 1.2 + fi * 4.0);
        float sw = 0.010 + 0.035 * v;
        float n = noise(vec2(curl * 45.0, along * 18.0 - t * 1.6 + fi * 13.0));
        sm = exp(-curl * curl / (sw * sw)) * smoothstep(1.0, 0.1, v) * smoothstep(0.0, 0.25, v) * n * n;
    }

    vec3 col = vec3(0.30, 0.62, 0.78) * sm * 0.60           // cool grey-blue smoke
             + vec3(0.28, 0.88, 0.80) * flame * 0.60          // blue-green tongue
             + vec3(0.55, 0.98, 0.95) * core * 0.50           // pale cyan body
             + vec3(0.90, 1.00, 1.00) * inner * 0.45;         // small bright heart
    return col * bright;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float t = iTime;

    // Gentle fade-in over the first second so nothing pops on.
    float intro = smoothstep(0.0, 1.2, t);

    // Split cycle: wisp 0 flares, a second flame peels off, wanders, then rejoins.
    float sp = mod(t + 13.0, SPLIT_T);          // first split ~2 s after start
    float sep = smoothstep(0.5, 3.5, sp) * (1.0 - smoothstep(10.5, 14.0, sp));
    float flare = exp(-pow((sp - 0.8) / 0.7, 2.0)) + 0.5 * exp(-pow((sp - 13.6) / 0.6, 2.0));

    vec3 light = vec3(0.0);
    float glow = 0.0;
    vec2 pos0 = vec2(0.0), vel0 = vec2(0.0);
    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        vec2 pos = wispPos(fi, t, aspect);
        vec2 vel = (pos - wispPos(fi, t - 0.25, aspect)) * 4.0;   // per second
        if (i == 0) { pos0 = pos; vel0 = vel; }
        // Slow breathing plus a soft flicker; never fully off.
        float bright = (0.70 + 0.30 * sin(t * (0.3 + 0.1 * fi) + fi * 2.0))
                     * (0.85 + 0.15 * noise(vec2(t * 3.0, fi * 11.0)));
        if (i == 0) bright *= 1.0 + 0.9 * flare;
        float h;
        light += wispLight(p, pos, vel, fi, t, bright, h);
        glow += h;
    }

    // The split-off flame: starts on top of wisp 0 and drifts out along its own path.
    if (sep > 0.001) {
        vec2 own = wispPos(7.0, t, aspect);
        vec2 ownPrev = wispPos(7.0, t - 0.25, aspect);
        vec2 pos = mix(pos0, own, sep);
        vec2 prev = mix(pos0 - vel0 * 0.25, ownPrev, sep);
        float bright = (0.4 + 0.5 * sep) * (0.85 + 0.15 * noise(vec2(t * 3.2, 77.0)))
                     * smoothstep(0.0, 0.3, sep);
        float h;
        light += wispLight(p, pos, (pos - prev) * 4.0, 7.0, t, bright, h);
        glow += h;
    }

    // Soft halo around each wisp.
    light += vec3(0.25, 0.70, 0.72) * glow * 0.22;

    // Low mist hugging the bottom; it only really shows where the wisps light it.
    float mistBand = smoothstep(0.30, 0.02, p.y);
    if (mistBand > 0.0) {
        vec2 mp = vec2(p.x * 2.2 + t * 0.03, p.y * 7.0);
        float m = noise(mp + vec2(0.0, t * 0.05)) * 0.65 + noise(mp * 2.3 - vec2(t * 0.07, 0.0)) * 0.35;
        m = smoothstep(0.25, 0.9, m) * mistBand;
        float lit = 0.12 + 1.4 * glow;
        light += vec3(0.30, 0.62, 0.66) * m * lit * MIST * smoothstep(0.0, 0.5 * aspect, p.x + 0.2);
    }

    // Keep the top-left text area calm.
    float calm = 1.0 - 0.8 * (1.0 - smoothstep(0.35 * aspect, 0.65 * aspect, p.x)) * smoothstep(0.45, 0.75, p.y);

    vec3 add = light * INTENSITY * intro * calm;
    // Soft-clip so overlapping wisps glow rather than burn to white.
    add = 1.0 - exp(-add * 1.3);
    fragColor = vec4(base.rgb + add * 0.85, base.a);
}
