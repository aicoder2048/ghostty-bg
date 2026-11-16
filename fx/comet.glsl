// comet — a realistic comet like Hale-Bopp or NEOWISE drifts slowly across the right sky: tight coma, straight blue ion tail, curved dusty tail, crisp stars.
// zh: 彗星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.85;   // overall brightness (0 = off)
const float CROSSING  = 50.0;   // seconds for one slow drift across the right sky
const float TAIL      = 0.65;   // tail length, in window heights
const float CURVE     = 0.70;   // how strongly the dust tail bends back
const float STARS     = 0.80;   // starfield brightness
const float PI        = 3.14159265;

float hash1(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

// Smooth 1D value noise: used across the tails so streamers are straight rays.
float vnoise(float x) {
    float i = floor(x), f = fract(x);
    return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// One layer of pin-sharp stars on a grid; at most one star per cell.
vec3 starLayer(vec2 p, float cell, float px, float seed) {
    vec2 g = floor(p / cell);
    float h = hash2(g + seed);
    if (h > 0.45) return vec3(0.0);                       // most cells are empty
    vec2 c = (g + 0.2 + 0.6 * vec2(hash2(g + seed + 3.1), hash2(g + seed + 7.7))) * cell;
    float d = length(p - c);
    float m = h / 0.45;                                   // 0..1, reused for brightness
    float b = 0.10 + 0.90 * pow(1.0 - m, 5.0);            // few bright, many faint
    float r = px * (0.55 + 0.6 * b);                      // brighter stars look a touch larger
    float core = exp(-d * d / (r * r));
    // Colour temperature: mostly white, some blue-white, some warm orange.
    float k = hash2(g + seed + 11.3);
    vec3 col = k < 0.25 ? vec3(0.75, 0.85, 1.00)
             : k < 0.80 ? vec3(1.00, 0.98, 0.94)
             : k < 0.93 ? vec3(1.00, 0.86, 0.66)
                        : vec3(1.00, 0.72, 0.52);
    // A few twinkle (atmospheric scintillation): gentle, not blinking.
    float tw = 1.0;
    if (hash2(g + seed + 5.5) < 0.18)
        tw = 0.65 + 0.35 * sin(iTime * (2.0 + 3.0 * k) + h * 40.0);
    return col * core * b * tw;
}

// The comet. `k` (0..1) is where the head is along its drift.
vec3 comet(vec2 p, float aspect, float px, float k) {
    float s = 3.7;

    // Head drifts low across the right half, slowly rising toward the middle.
    vec2 from = vec2(aspect - 0.12, 0.24);
    vec2 to   = vec2(aspect * 0.66, 0.36);
    vec2 head = mix(from, to, k);

    // Tails point away from an implied sun below the lower left, i.e. up and to
    // the right; the direction turns a little during the pass.
    float ang = PI * 0.5 - 0.34 - 0.10 * k;
    vec2 A = vec2(cos(ang), sin(ang));       // anti-sun direction (ion tail axis)
    vec2 S = vec2(A.y, -A.x);                // sideways, toward the trailing side
    vec2 d = p - head;
    float along = dot(d, A);
    float across = dot(d, S);

    vec3 col = vec3(0.0);

    // Early out: pixels well outside the comet's footprint cost almost nothing.
    float r = length(d);
    if (along > -0.06 && along < TAIL * 1.6 && abs(across - CURVE * along * along) < 0.05 + along * 0.45) {
        float L = max(along, 0.0);
        float start = smoothstep(-0.004, 0.03, along);
        float tt = iTime;

        // ---- ion tail: straight, narrow, blue, fine streamers.
        // A slow ripple that travels outward, larger far from the head.
        float xi = across - 0.010 * L * L * sin(L * 9.0 - tt * 0.6 + s);
        float wi = 0.0025 + L * 0.040;
        float rayA = xi / (L + 0.02);                     // angle-like: streamers fan from the head
        float fil = vnoise(rayA * 160.0 + s) * 0.6 + vnoise(rayA * 420.0 + s * 2.0) * 0.4;
        fil = pow(fil, 3.0) * 2.4;
        float knots = 0.85 + 0.15 * sin(L * 28.0 - tt * 0.9 + s);   // faint clumps moving outward
        float prof = exp(-pow(xi / wi, 2.0));
        float ion = (0.45 * exp(-pow(xi / (wi * 0.35), 2.0)) + 0.55 * fil) * prof;
        ion *= exp(-L * 2.6 / TAIL) * start * knots;
        col += vec3(0.36, 0.56, 1.00) * ion * 0.85;

        // ---- dust tail: broader, curved back, yellowish white, soft striations.
        float xd = across - CURVE * L * L - 0.17 * L - 0.004 * L * sin(L * 5.0 - tt * 0.35 + s);
        float wd = 0.004 + L * 0.26;
        float w2 = xd > 0.0 ? wd * 0.55 : wd * 1.15;      // sharper on the outer (convex) edge
        float dust = exp(-pow(xd / w2, 2.0));
        float rayD = xd / (L + 0.03);
        float stri = 0.80 + 0.20 * vnoise(rayD * 55.0 + s * 3.0) + 0.08 * sin(L * 40.0 + rayD * 9.0);
        dust *= stri * exp(-L * 3.2 / TAIL) * start;
        col += vec3(1.00, 0.90, 0.72) * dust * 0.95;
    }

    // ---- coma and nucleus: compact, bright, faint teal outer coma, skewed a
    // touch into the tails.
    float rs = length(d - A * 0.004);
    float coma = 0.90 * exp(-rs / 0.0075) + 0.25 * exp(-rs / 0.022);
    float nucleus = smoothstep(px * 1.8, px * 0.3, r);
    col += mix(vec3(0.70, 0.95, 0.90), vec3(1.0, 0.98, 0.92), exp(-rs / 0.010)) * coma;
    col += vec3(1.0) * nucleus;

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);
    float px = 1.0 / iResolution.y;

    // Starfield: two layers of different density; dimmed over the text block.
    float textMask = 1.0 - 0.75 * smoothstep(0.25, 0.0, max(p.x / aspect - 0.45, 0.55 - p.y));
    vec3 col = (starLayer(p, 0.045, px, 0.0) + 0.7 * starLayer(p, 0.023, px, 17.0)) * STARS * textMask;

    // The head glides out and back on an eased path, so it never jumps,
    // never leaves the screen and is already there at t = 0. The tails keep
    // pointing away from the sun whichever way it drifts (as real ones do).
    float k = 0.5 - 0.5 * cos(PI * iTime / CROSSING);
    col += comet(p, aspect, px, k);

    col = min(col, vec3(1.0)) * INTENSITY;
    fragColor = vec4(base.rgb + col, base.a);
}
