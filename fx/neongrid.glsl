// neongrid — a cinematic synthwave horizon: a neon grid floor glides toward you, a hazy slit sun sets behind wireframe mountains.
// zh: 霓虹网格
// group: geek
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY = 1.0;    // overall strength (0 = off)
const float HORIZON   = 0.34;   // horizon height above the bottom, in window-heights
const float SPEED     = 0.55;   // grid rows per second gliding toward you
const float GRID_GLOW = 0.55;   // brightness of the grid lines and their bloom
const float SUN_X     = 0.74;   // sun centre across the window (0 = left, 1 = right)
const float SUN_R     = 0.15;   // sun radius in window-heights
const float SUN_ALPHA = 0.55;   // how solid the sun is at its brightest
const float MOUNTAINS = 0.60;   // strength of the faint wireframe mountain silhouettes
const float PULSES    = 0.8;    // strength of the light pulses running along grid lines
const float HAZE      = 0.30;   // warm haze band hugging the horizon

const vec3 MAGENTA = vec3(1.00, 0.30, 0.78);
const vec3 VIOLET  = vec3(0.55, 0.30, 1.00);
const vec3 CYAN    = vec3(0.30, 0.85, 1.00);
const vec3 AMBER   = vec3(1.00, 0.72, 0.38);
const vec3 ROSE    = vec3(1.00, 0.36, 0.52);

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

// Smooth 1-D value noise for the mountain ridge.
float vnoise1(float x) {
    float i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash1(i), hash1(i + 1.0), f);
}

// Line glow wherever x is a whole number: a crisp anti-aliased core plus a wide
// soft bloom, both measured in screen pixels so far lines don't smear into mush.
vec2 glowLine(float x) {
    float w = max(fwidth(x), 1e-4);
    float px = abs(fract(x + 0.5) - 0.5) / w;
    // Where lines crowd closer than a few pixels they would shimmer (moire);
    // fade them out there so the distance dissolves into smooth haze instead.
    float crowd = 1.0 - smoothstep(0.15, 0.6, w);
    float core  = (1.0 - smoothstep(0.0, 1.4, px)) * crowd;
    float bloom = exp(-px * 0.35) * crowd * crowd;
    return vec2(core, bloom);
}

// Ridge height of the distant mountains (above the horizon, window-heights).
// Sharp-ish peaks come from 1 - |noise| folding; they rise toward both sides
// and dip a little where the sun sits so it shows through.
float ridge(float x, float aspect) {
    float n = 0.0;
    n += (1.0 - abs(vnoise1(x * 3.1) * 2.0 - 1.0)) * 0.55;
    n += (1.0 - abs(vnoise1(x * 7.3 + 4.0) * 2.0 - 1.0)) * 0.30;
    n += vnoise1(x * 17.0 + 9.0) * 0.15;
    float u = x / aspect;
    float sides = 0.55 + 0.45 * smoothstep(0.15, 0.0, abs(u - 0.5) - 0.35);
    float sunGap = 1.0 - 0.45 * exp(-pow((u - SUN_X) / 0.12, 2.0));
    return 0.13 * n * sides * sunGap;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so y points up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float cx = aspect * 0.5;
    float t = iTime;

    // Fade the whole scene in over the first ~1.5 s instead of popping on.
    float fadeIn = smoothstep(0.0, 1.5, t);

    // Everything lives in the lower half; the top of the window stays untouched.
    if (p.y > HORIZON + SUN_R * 2.4) {
        fragColor = base;
        return;
    }

    vec3 light = vec3(0.0);   // additive glow
    vec4 veil  = vec4(0.0);   // translucent colour laid over the photo (rgb, alpha)

    float h = p.y - HORIZON;                 // height above the horizon
    float scan = 0.93 + 0.07 * sin(fragCoord.y * 1.6 + t * 3.0); // gentle scanline shimmer

    // ---------------- Sky side: sun, mountains, haze ----------------
    if (h > -0.004) {
        // Sun: amber at the top melting to rose at the horizon, partly sunk.
        vec2 sc = vec2(SUN_X * aspect, HORIZON + SUN_R * 0.55);
        vec2 s = p - sc;
        float r = length(s);
        float v = clamp((s.y + SUN_R) / (2.0 * SUN_R), 0.0, 1.0); // 0 bottom .. 1 top
        float disc = smoothstep(SUN_R, SUN_R - 0.003, r);
        // Horizontal slits in the lower half, widening toward the horizon and
        // drifting slowly downward like the classic retro sun.
        float k = clamp((0.78 - v) / 0.55, 0.0, 1.0);
        float band = fract(v * 10.0 - t * 0.15);
        float slitW = k * 0.6;
        float slit = mix(0.08, 1.0, smoothstep(slitW - 0.05, slitW + 0.02, band));
        slit = mix(1.0, slit, step(0.001, k));
        vec3 sunCol = mix(ROSE, AMBER, smoothstep(0.1, 0.95, v));
        // Haze eats the bottom of the sun so it seems to sink into mist.
        float veilLow = smoothstep(0.0, 0.07, h);
        float sunA = disc * slit * SUN_ALPHA * (0.45 + 0.55 * veilLow) * mix(1.0, 0.75, smoothstep(0.6, 1.0, v));
        // Mountains in front hide the sun.
        float rh = ridge(p.x, aspect);
        float behind = smoothstep(rh - 0.002, rh + 0.002, h);
        sunA *= mix(0.25, 1.0, behind);
        veil = vec4(sunCol, sunA);
        // Soft corona and a wide warm glow around the sun.
        float corona = exp(-max(r - SUN_R, 0.0) * 22.0) * (1.0 - disc);
        light += mix(ROSE, AMBER, 0.4) * corona * 0.22;
        light += MAGENTA * exp(-r * 4.5) * 0.06;

        // Wireframe mountains: a glowing ridge line, faint contour rings and
        // vertical struts under it, all fading into the haze.
        if (h < rh + 0.02) {
            float dRidge = abs(h - rh) / max(fwidth(h - rh), 1e-4);
            float ridgeLine = exp(-dRidge * 0.8) * 0.7 + exp(-dRidge * 0.15) * 0.12;
            float inside = step(h, rh);
            float fh = h / max(rh, 1e-3);                     // 0 at horizon, 1 at the ridge
            vec2 contour = glowLine(h * 110.0);
            vec2 strut   = glowLine(p.x * 28.0 + h * 40.0 * sign(sin(p.x * 9.0)));
            float wire = (contour.x * 0.7 + strut.x * 0.45) * inside * (0.3 + 0.7 * fh);
            vec3 mCol = mix(VIOLET, CYAN, 0.35);
            light += mCol * (ridgeLine * 0.40 + wire * 0.30) * MOUNTAINS;
            // A dim translucent body so the mountains read as solid silhouettes.
            light += VIOLET * inside * 0.04 * MOUNTAINS * (1.0 - fh * 0.5);
        }

        // Warm haze band and the bright horizon line.
        light += mix(MAGENTA, AMBER, 0.35) * exp(-h * 18.0) * HAZE;
    }

    // ---------------- Floor: the perspective grid ----------------
    float dy = -h;
    if (dy > 0.0) {
        // Each pixel below the horizon maps to a point on a flat plane; the
        // closer to the horizon, the farther away (z) that point is.
        float z  = 0.32 / dy;                                 // ~1 at the bottom, huge at the horizon
        float gx = (p.x - cx) * z * 7.0;
        float gz = z * 2.2 + t * SPEED * 2.2;
        float depthFade = smoothstep(0.0, 0.12, dy);          // dense far lines melt into the haze
        float nearFade  = 0.75 + 0.25 * smoothstep(HORIZON, 0.0, dy); // slightly softer at the very bottom

        vec2 lx = glowLine(gx);                               // lines running away from you
        vec2 lz = glowLine(gz);                               // rows gliding toward you
        float grid = 0.0;
        vec3 gcol = vec3(0.0);
        gcol += CYAN    * (lx.x * 0.9 + lx.y * 0.22);
        gcol += MAGENTA * (lz.x * 1.0 + lz.y * 0.28);
        light += gcol * GRID_GLOW * depthFade * nearFade * scan;

        // Light pulses: a few of the long lines carry a bright bead racing
        // toward you; each line picks its own timing so they never sync.
        float col = floor(gx + 0.5);
        float hc = hash1(col * 1.37 + 3.0);
        float period = 4.0 + hc * 5.0;
        float ph = fract(t / period + hc);
        float zp = mix(14.0, 0.9, ph);                        // bead travels from far to near
        float bead = exp(-pow((z - zp) * 3.0 / max(zp, 0.6), 2.0));
        float onLine = lx.x + lx.y * 0.4;
        float lit = step(0.55, hc) * smoothstep(0.0, 0.15, ph) * smoothstep(1.0, 0.85, ph);
        light += mix(CYAN, vec3(0.9, 0.95, 1.0), 0.5) * bead * onLine * lit * PULSES * depthFade;

        // An occasional sideways pulse sweeping along one of the rows.
        float row = floor(gz + 0.5);
        float hr = hash1(row * 2.71 + 7.0);
        float sweep = fract(t * 0.11 + hr) * 2.0 - 1.0;       // -1..1 across the floor
        float sx = (p.x - cx) / cx;
        float runner = exp(-pow((sx - sweep) * 6.0, 2.0)) * step(0.82, hr);
        light += mix(MAGENTA, ROSE, 0.5) * runner * (lz.x + lz.y * 0.5) * PULSES * depthFade;

        // Reflection of the sun smeared on the floor and a violet haze toward the horizon.
        float refl = exp(-pow((p.x - SUN_X * aspect) / (SUN_R * 0.9), 2.0)) * exp(-dy * 14.0);
        light += mix(ROSE, AMBER, 0.3) * refl * 0.18;
        light += mix(VIOLET, MAGENTA, 0.5) * exp(-dy * 10.0) * HAZE * 0.6;
    }

    // Horizon line: thin bright core and a soft wide glow.
    float hpx = abs(h) / max(fwidth(h), 1e-4);
    light += mix(MAGENTA, AMBER, 0.25) * (exp(-hpx * 0.7) * 0.35 + exp(-abs(h) * 40.0) * 0.12);

    light *= INTENSITY * fadeIn;
    float a = veil.a * INTENSITY * fadeIn;

    // Lay the sun over the photo as translucent colour, then add the glow with
    // a screen blend so bright backgrounds don't blow out to white.
    vec3 col = mix(base.rgb, veil.rgb, clamp(a, 0.0, 1.0));
    light = min(light, vec3(1.0));
    col = 1.0 - (1.0 - col) * (1.0 - light);
    fragColor = vec4(col, base.a);
}
