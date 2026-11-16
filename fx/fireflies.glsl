// fireflies — a night meadow of glowing fireflies rising from dark grass, flashing in waves.
// zh: 萤火虫
// group: animals
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY  = 0.95;  // overall strength (0 = off)
const float GRASS_H    = 0.17;  // typical grass height, in window-heights
const float GRASS_DARK = 0.82;  // how solid the grass silhouette is (1 = opaque)
const float WAVE_GAP   = 5.5;   // seconds between synchronised flash waves
const float WAVE_SPEED = 0.85;  // how fast a wave sweeps left to right, window-heights per second
const float BLINKS     = 0.85;  // strength of the random blinks between waves
const float EMBER      = 0.13;  // faint glow a firefly keeps between flashes
const float RISE       = 0.035; // how fast the swarm drifts upward, window-heights per second

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The synchronised wave: how lit a firefly at x is right now (0..1).
// The flash snaps on fast and fades over about a second, so each wave
// leaves a glowing trail behind its front.
float waveAt(float x, float jitter) {
    float since = mod(iTime + 0.4 - x / WAVE_SPEED - jitter, WAVE_GAP);
    return smoothstep(0.0, 0.10, since) * exp(-since * 1.3);
}

// One row of grass blades. All blades in a row bend along the same curve
// (sideways offset grows with y^2), so undoing the bend first lets each
// pixel look at a single blade. Returns coverage, plus edge-ness in .y
// for the rim light.
vec2 blades(vec2 p, float row, float spacing, float hMin, float hMax, float width) {
    float sway = 0.35 * sin(iTime * 0.7 + p.x * 1.7 + row * 2.1)
               + 0.15 * sin(iTime * 1.3 + p.x * 4.1 + row);
    float xb = p.x - sway * p.y * p.y * 2.0;
    float id = floor(xb / spacing);
    float r1 = hash1(id * 3.17 + row * 11.0);
    float r2 = hash1(id * 7.31 + row * 5.0);
    float h = GRASS_H * mix(hMin, hMax, r1 * r1);
    // Each blade also has its own fixed lean, so they cross a bit.
    float x0 = (id + 0.5 + (r2 - 0.5) * 0.5) * spacing + (r2 - 0.5) * 0.6 * p.y * p.y / max(h, 0.01);
    float t = clamp(p.y / h, 0.0, 1.0);
    float halfW = width * (1.0 - t) * (1.0 - t * 0.3);
    float dx = abs(xb - x0);
    float aa = 1.2 / iResolution.y;
    float cover = smoothstep(halfW + aa, halfW - aa, dx) * step(p.y, h);
    float edge = smoothstep(halfW * 0.35, halfW, dx) * cover;
    return vec2(cover, edge);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // ---- fireflies: 3 depth layers of a drifting cell grid, one fly per cell.
    // Layer 0 = far (small, behind the grass), 2 = near (big, in front).
    vec3 back = vec3(0.0);
    vec3 front = vec3(0.0);
    for (int l = 0; l < 3; l++) {
        float fl = float(l);
        float S = 7.5 - fl * 2.2;                     // cells per window-height
        float rc = 0.0040 + fl * 0.0040;              // core radius
        float rh = 0.014 + fl * 0.016;                // halo radius
        float bright = 0.75 + fl * 0.30;
        // The whole layer drifts up and a little sideways; near layers move faster.
        vec2 drift = vec2(0.012 * sin(iTime * 0.21 + fl) + iTime * 0.006 * (fl - 1.0),
                          iTime * RISE * (0.7 + 0.25 * fl) + fl * 0.37);
        vec2 g = (p - drift) * S;
        vec2 cid = floor(g);

        vec3 acc = vec3(0.0);
        for (int j = -1; j <= 1; j++)
        for (int i = -1; i <= 1; i++) {
            vec2 id = cid + vec2(float(i), float(j));
            float h0 = hash2(id + fl * 17.0);
            if (h0 > 0.88) continue;                  // some cells are empty
            float h1 = hash2(id + 3.3 + fl * 5.0);
            float h2 = hash2(id + 7.7 + fl * 9.0);
            float h3 = hash2(id + 1.9 + fl * 2.0);

            // A loop around the cell centre; together with the upward drift it
            // makes a slow rising spiral. Plus a little wavy wander.
            float w = (0.5 + 0.7 * h1) * (h2 > 0.5 ? 1.0 : -1.0);
            float a = iTime * w + h3 * 6.2831;
            vec2 c = 0.5 + 0.22 * vec2(cos(a), sin(a) * 0.7)
                   + 0.08 * vec2(sin(iTime * 0.9 + h2 * 9.0), sin(iTime * 1.3 + h1 * 7.0));
            vec2 pos = (id + c) / S + drift;          // fly position in window space

            // Fewer flies high up, and very few around the top-left text.
            float dens = 1.0 - 0.8 * smoothstep(0.30, 0.95, pos.y);
            vec2 tl = (pos - vec2(0.0, 1.0)) * vec2(0.55, 1.0);
            dens *= 1.0 - 0.92 * smoothstep(0.75, 0.25, length(tl));
            // Fade in as they climb out of the ground.
            dens *= smoothstep(-0.02, 0.05, pos.y);

            // Blinking: most join the sweeping wave, all blink on their own too.
            float sync = h1 < 0.75 ? waveAt(pos.x, h2 * 0.25) : 0.0;
            float per = 2.2 + 2.5 * h3;
            float since = mod(iTime + h0 * 7.0 * per, per);
            float solo = smoothstep(0.0, 0.08, since) * exp(-since * 1.8) * BLINKS;
            float lit = EMBER + max(sync, solo);

            float d = length(p - pos);
            float core = exp(-(d * d) / (rc * rc));
            float halo = exp(-d / rh) * 0.65 + exp(-d / (rh * 3.0)) * 0.06;
            vec3 col = vec3(1.0, 1.0, 0.72) * core + vec3(0.62, 1.0, 0.22) * halo;
            acc += col * lit * dens * (0.8 + 0.4 * h2);
        }
        if (l < 2) back += acc * bright;
        else       front += acc * bright;
    }

    // ---- grass silhouette along the bottom.
    float cover = 0.0;
    float edge = 0.0;
    if (p.y < GRASS_H * 2.0) {
        vec2 b0 = blades(p, 0.0, 0.011, 0.55, 1.05, 0.0045);   // dense back grass
        vec2 b1 = blades(p, 1.0, 0.019, 0.45, 1.30, 0.0065);   // mid grass
        vec2 b2 = blades(p, 2.0, 0.047, 0.90, 1.85, 0.0050);   // a few tall reeds
        cover = max(max(b0.x, b1.x), b2.x);
        edge = max(max(b0.y, b1.y), b2.y);

        // Cattail heads on some reeds: a small dark oval at the tip.
        float rs = 0.047;
        float sway = 0.35 * sin(iTime * 0.7 + p.x * 1.7 + 4.2) + 0.15 * sin(iTime * 1.3 + p.x * 4.1 + 2.0);
        float xb = p.x - sway * p.y * p.y * 2.0;
        float rid = floor(xb / rs);
        float r1 = hash1(rid * 3.17 + 22.0);
        float r2 = hash1(rid * 7.31 + 10.0);
        float rh = GRASS_H * mix(0.90, 1.85, r1 * r1);
        if (hash1(rid * 1.7 + 4.0) < 0.45) {
            float x0 = (rid + 0.5 + (r2 - 0.5) * 0.5) * rs + (r2 - 0.5) * 0.6 * rh;
            vec2 q = vec2(xb - x0, p.y - rh * 0.86) / vec2(0.0055, 0.022);
            cover = max(cover, smoothstep(1.05, 0.9, length(q)));
        }

        // A few low rounded shrubs with a leafy, bumpy top.
        float shrub = 0.0;
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float cx = aspect * (0.14 + 0.36 * fk + 0.06 * sin(fk * 4.0));
            float wd = 0.16 + 0.05 * fk;
            float dx = (p.x - cx) / wd;
            shrub = max(shrub, GRASS_H * (0.75 - 0.12 * fk) * sqrt(max(1.0 - dx * dx, 0.0)));
        }
        shrub += 0.006 * sin(p.x * 140.0) + 0.004 * sin(p.x * 61.0 + 1.0);
        float aa = 1.5 / iResolution.y;
        float sh = smoothstep(shrub + aa, shrub - aa, p.y) * step(0.01, shrub);
        edge = max(edge, smoothstep(shrub - 0.012, shrub, p.y) * sh);
        cover = max(cover, sh);

        // Solid ground at the very bottom.
        cover = max(cover, smoothstep(0.030, 0.012, p.y));
    }

    // The flash wave also lights up the grass it passes over.
    float waveHere = waveAt(p.x, 0.1);
    float lowGlow = exp(-max(p.y, 0.0) / 0.13);

    vec3 rgb = base.rgb + min(back, vec3(1.0)) * INTENSITY;
    rgb = mix(rgb, vec3(0.010, 0.022, 0.016), cover * GRASS_DARK * min(INTENSITY, 1.0));
    // Faint cool rim on blade edges, warmed up and brightened by the wave.
    vec3 rim = mix(vec3(0.18, 0.28, 0.30), vec3(0.55, 0.85, 0.25), waveHere);
    rgb += rim * edge * (0.25 + 0.75 * waveHere) * 0.55 * INTENSITY;
    // Soft green light pooling low over the meadow while the wave passes.
    rgb += vec3(0.35, 0.60, 0.12) * lowGlow * waveHere * 0.30 * INTENSITY;
    rgb += min(front, vec3(1.0)) * INTENSITY;

    fragColor = vec4(rgb, base.a);
}
