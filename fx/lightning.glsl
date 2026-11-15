// lightning — now and then a jagged bolt flickers across the upper sky with a soft flash.
// zh: 闪电
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.70;   // overall brightness (0 = off)
const float PERIOD    = 7.0;    // seconds between possible strikes

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Straight-line noise (no smoothing), so the bolt has sharp kinks.
float jag(float x, float seed) {
    float i = floor(x), f = fract(x);
    return mix(hash1(i + seed), hash1(i + 1.0 + seed), f) - 0.5;
}

// Glow around a near-vertical path whose x depends on y: core plus halo.
float glowAt(float dx, float width) {
    float d = abs(dx);
    return smoothstep(width, 0.0, d) + 0.00025 / (d * d + 0.0004);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float cycle = floor(iTime / PERIOD);
    float dt = iTime - cycle * PERIOD - 1.0;         // seconds since this cycle's strike
    float skip = step(0.8, hash1(cycle * 3.1));      // about 1 in 5 cycles stays dark

    // Flicker: a hard hit, a short gap, a second weaker hit, then darkness.
    float hit = exp(-max(dt, 0.0) * 14.0) * step(0.0, dt)
              + 0.7 * exp(-max(dt - 0.18, 0.0) * 9.0) * step(0.18, dt)
              + 0.35 * exp(-max(dt - 0.42, 0.0) * 12.0) * step(0.42, dt);
    hit *= (1.0 - skip);

    vec3 color = vec3(0.0);
    if (hit > 0.003) {
        float seed = cycle * 17.0;
        // Strikes land in the right two-thirds, away from the text at the top left.
        float x0 = aspect * (0.50 + 0.42 * hash1(seed + 1.0));
        float bottom = 0.30 + 0.25 * hash1(seed + 2.0);  // how far down it reaches

        // Main bolt: big kinks plus small ones.
        float y = 1.0 - p.y;
        float bx = x0 + 0.10 * jag(y * 7.0, seed) + 0.035 * jag(y * 23.0, seed + 5.0) + y * 0.08;
        float main = glowAt(p.x - bx, 0.0030) * smoothstep(bottom - 0.02, bottom + 0.06, p.y);

        // One branch splitting off partway down, leaning away and fading out.
        float by = 0.25 + 0.2 * hash1(seed + 3.0);   // depth of the split (from top)
        float dir = hash1(seed + 4.0) < 0.5 ? -1.0 : 1.0;
        float sy = max(y - by, 0.0);
        float splitX = x0 + 0.10 * jag(by * 7.0, seed) + 0.035 * jag(by * 23.0, seed + 5.0) + by * 0.08;
        float brx = splitX + dir * sy * 0.6 + 0.03 * jag(y * 19.0, seed + 9.0);
        float branch = glowAt(p.x - brx, 0.0022) * step(by, y) * smoothstep(by + 0.22, by, y) * 0.6;

        float bolt = min(main + branch, 1.6);

        // Soft sky flash, strongest near the bolt and in the upper half.
        float flash = 0.10 * smoothstep(0.2, 1.0, p.y) * exp(-abs(p.x - x0) * 1.2);

        color = vec3(0.80, 0.86, 1.0) * (bolt + flash) * hit;
    }

    fragColor = vec4(base.rgb + min(color, vec3(1.0)) * INTENSITY, base.a);
}
