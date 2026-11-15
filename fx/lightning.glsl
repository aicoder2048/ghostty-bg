// lightning — every few seconds a jagged bolt (sometimes two) cracks down the upper sky with a soft flash.
// zh: 闪电
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.75;   // overall brightness (0 = off)
const float PERIOD    = 2.5;    // seconds between strikes
const float START     = 0.3;    // first strike this many seconds after switching on

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Straight-line noise (no smoothing), so the bolt has sharp kinks.
float jag(float x, float seed) {
    float i = floor(x), f = fract(x);
    return mix(hash1(i + seed), hash1(i + 1.0 + seed), f) - 0.5;
}

// Glow around a near-vertical path at horizontal distance dx: core plus halo.
float glowAt(float dx, float width) {
    float d = abs(dx);
    return smoothstep(width, 0.0, d) + 0.00025 / (d * d + 0.0004);
}

// The bolt's x at depth y (measured down from the top of the window).
float boltX(float y, float x0, float seed) {
    return x0 + 0.10 * jag(y * 7.0, seed) + 0.035 * jag(y * 23.0, seed + 5.0)
              + y * (hash1(seed + 6.0) - 0.5) * 0.3;
}

// One bolt with a single branch, from the top edge down to `bottom` (scene y).
float bolt(vec2 p, float x0, float seed) {
    float bottom = 0.25 + 0.25 * hash1(seed + 2.0);
    float y = 1.0 - p.y;
    float main = glowAt(p.x - boltX(y, x0, seed), 0.0032)
               * smoothstep(bottom - 0.02, bottom + 0.06, p.y);

    // A branch splits off partway down, leans away and fades out.
    float by = 0.20 + 0.25 * hash1(seed + 3.0);
    float dir = hash1(seed + 4.0) < 0.5 ? -1.0 : 1.0;
    float brx = boltX(by, x0, seed) + dir * max(y - by, 0.0) * 0.6 + 0.03 * jag(y * 19.0, seed + 9.0);
    float branch = glowAt(p.x - brx, 0.0022) * step(by, y) * smoothstep(by + 0.22, by, y) * 0.6;

    return min(main + branch, 1.6);
}

// Brightness over time: a crisp ~0.2 s strike with a fast shimmer, then two
// quick re-flashes, then dark until the next one.
float flicker(float dt) {
    if (dt < 0.0) return 0.0;
    float strike = step(dt, 0.22) * (0.85 + 0.15 * sin(dt * 90.0));
    float re1 = 0.75 * smoothstep(0.30, 0.31, dt) * smoothstep(0.38, 0.34, dt);
    float re2 = 0.45 * smoothstep(0.46, 0.47, dt) * smoothstep(0.53, 0.49, dt);
    return strike + re1 + re2 + 0.25 * exp(-dt * 6.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float cycle = floor((iTime - START) / PERIOD);
    float dt = iTime - START - cycle * PERIOD;       // seconds since this cycle's strike
    float seed = cycle * 17.0 + 3.0;

    vec3 color = vec3(0.0);
    float hit = flicker(dt);
    if (hit > 0.003) {
        // Strikes land anywhere in the right two-thirds, away from the text
        // at the top left, at a new spot each time.
        float x0 = aspect * (0.36 + 0.58 * hash1(seed + 1.0));
        float b = bolt(p, x0, seed);
        float flash = 0.12 * smoothstep(0.2, 1.0, p.y) * exp(-abs(p.x - x0) * 1.2);

        // About one strike in three brings a second bolt a moment later, well apart.
        if (hash1(seed + 8.0) < 0.35) {
            float x1 = x0 + (x0 > aspect * 0.65 ? -1.0 : 1.0) * aspect * (0.18 + 0.12 * hash1(seed + 9.0));
            float hit2 = flicker(dt - 0.06) / max(hit, 0.001);
            b += bolt(p, x1, seed + 31.0) * hit2;
            flash += 0.08 * smoothstep(0.2, 1.0, p.y) * exp(-abs(p.x - x1) * 1.2) * hit2;
        }
        color = vec3(0.80, 0.86, 1.0) * (min(b, 1.6) + flash) * hit;
    }

    fragColor = vec4(base.rgb + min(color, vec3(1.0)) * INTENSITY, base.a);
}
