// comet — a realistic comet flies in from far away, swings past the sun large and bright, flares in an outburst, then recedes; each one from a new direction.
// zh: 彗星
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.85;   // overall brightness (0 = off)
const float CYCLE     = 15.0;   // seconds per comet: approach, pass, outburst, recede
const float TAIL      = 1.00;   // full tail length at closest approach, in window heights
const float CURVE     = 0.55;   // how strongly the dust tail bends back behind the orbit
const float OUTBURST  = 0.56;   // point in the cycle (0..1) where the nucleus flares
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
    float m = h / 0.45;
    float b = 0.10 + 0.90 * pow(1.0 - m, 5.0);            // few bright, many faint
    float r = px * (0.55 + 0.6 * b);
    float core = exp(-d * d / (r * r));
    float k = hash2(g + seed + 11.3);                     // colour temperature
    vec3 col = k < 0.25 ? vec3(0.75, 0.85, 1.00)
             : k < 0.80 ? vec3(1.00, 0.98, 0.94)
             : k < 0.93 ? vec3(1.00, 0.86, 0.66)
                        : vec3(1.00, 0.72, 0.52);
    float tw = 1.0;
    if (hash2(g + seed + 5.5) < 0.18)
        tw = 0.65 + 0.35 * sin(iTime * (2.0 + 3.0 * k) + h * 40.0);
    return col * core * b * tw;
}

// Three flight plans (x as a fraction of the width, y in window heights):
// where it first appears far away, where it passes closest, where it fades
// out, and the implied sun the tails point away from (always off to the
// left/below, so the tails stream right, away from the text).
void flightPlan(float v, out vec2 a, out vec2 m, out vec2 b, out vec2 sun) {
    if (v < 0.5) {          // from the upper right, down across, out to the lower middle
        a = vec2(0.88, 0.86); m = vec2(0.64, 0.27); b = vec2(0.40, 0.12); sun = vec2(0.22, -0.40);
    } else if (v < 1.5) {   // in from the right edge, hooks round the sun, back out upper right
        a = vec2(0.97, 0.50); m = vec2(0.58, 0.22); b = vec2(0.86, 0.80); sun = vec2(0.28, 0.42);
    } else {                // rises from the bottom middle, out to the upper right
        a = vec2(0.42, 0.06); m = vec2(0.66, 0.30); b = vec2(0.93, 0.76); sun = vec2(0.30, 0.62);
    }
}

// Quadratic Bezier through a (s=0), m (s=0.5), b (s=1).
vec2 bez(vec2 a, vec2 m, vec2 b, float s) {
    vec2 c = 2.0 * m - 0.5 * (a + b);
    return (1.0 - s) * (1.0 - s) * a + 2.0 * s * (1.0 - s) * c + s * s * b;
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

    // ---- where are we in this comet's visit? Start a fifth of the way in so
    // a comet is already approaching when the effect switches on.
    float ct = iTime / CYCLE + 0.20;
    float n = floor(ct);
    float u = fract(ct);
    float v = mod(n, 3.0);

    vec2 a, m, b, sun;
    flightPlan(v, a, m, b, sun);
    vec2 sc2 = vec2(aspect, 1.0);
    vec2 jit = (vec2(hash1(n * 7.1), hash1(n * 3.3)) - 0.5) * vec2(0.06, 0.04);
    a *= sc2; m = m * sc2 + jit; b *= sc2; sun *= sc2;

    // Kepler-like pacing: slow while far, fast while close.
    float s  = u - 0.65 * sin(2.0 * PI * u) / (2.0 * PI);
    float s2 = s + 0.01;
    vec2 head = bez(a, m, b, s);
    vec2 vel = normalize(bez(a, m, b, s2) - head + 1e-6);

    // Perspective: tiny far away, large when close. Activity (tail length,
    // coma brightness) grows faster near the sun.
    float near = pow(sin(PI * u), 1.6);
    float sc = mix(0.07, 1.0, near);
    float act = near * near;
    float fade = smoothstep(0.0, 0.06, u) * smoothstep(1.0, 0.90, u);

    // Tail frame: A points away from the sun; S is sideways toward the side
    // the dust tail lags to (opposite to the motion), blended so it never flips.
    vec2 A = normalize(head - sun);
    vec2 S0 = vec2(A.y, -A.x);
    float side = clamp(-dot(S0, vel) * 4.0, -1.0, 1.0);
    vec2 S = S0;

    // Local coordinates: divide by the perspective scale so the comet's shape
    // is drawn once at full size.
    vec2 d = (p - head) / sc;
    float lpx = px / sc;
    float along = dot(d, A);
    float across = dot(d, S) * (side < 0.0 ? -1.0 : 1.0);
    float bend = abs(side);
    float tl = TAIL * (0.25 + 0.75 * act);                 // tails grow near the sun

    vec3 cc = vec3(0.0);

    // ---- tails (skipped for pixels outside the comet's footprint)
    if (along > -0.08 && along < tl * 1.3 && abs(across - CURVE * bend * along * along) < 0.06 + along * 0.55) {
        float L = max(along, 0.0);
        float start = smoothstep(-0.004, 0.03, along);
        float tt = iTime;

        // Ion tail: straight, narrow, blue, fine streamers drifting outward.
        float xi = across - 0.012 * L * L * sin(L * 7.0 - tt * 0.9 + n);
        float wi = 0.003 + L * 0.045;
        float rayA = xi / (L + 0.02);
        float fil = vnoise(rayA * 150.0 + n) * 0.6 + vnoise(rayA * 380.0 + n * 2.0) * 0.4;
        fil = pow(fil, 3.0) * 2.4;
        float knots = 0.80 + 0.20 * sin(L * 22.0 - tt * 2.2 + n);   // clumps racing outward
        float prof = exp(-pow(xi / wi, 2.0));
        float ion = (0.45 * exp(-pow(xi / (wi * 0.35), 2.0)) + 0.55 * fil) * prof;
        ion *= exp(-L * 2.4 / tl) * start * knots;
        cc += vec3(0.36, 0.56, 1.00) * ion * 0.80 * (0.35 + 0.65 * act);

        // Dust tail: broader, curved back along the orbit, yellowish white.
        float xd = across - CURVE * bend * L * L - 0.16 * bend * L;
        float wd = 0.004 + L * 0.24 * (0.6 + 0.4 * act);   // spreads as it nears the sun
        float w2 = xd > 0.0 ? wd * 0.55 : wd * 1.15;       // sharper outer edge
        float dust = exp(-pow(xd / w2, 2.0));
        float rayD = xd / (L + 0.03);
        float stri = 0.80 + 0.20 * vnoise(rayD * 55.0 + n * 3.0) + 0.08 * sin(L * 40.0 + rayD * 9.0);
        dust *= stri * exp(-L * 3.0 / tl) * start;
        cc += vec3(1.00, 0.88, 0.68) * dust * 0.85 * (0.30 + 0.70 * act);
    }

    // ---- outburst: the nucleus flares, throws off an expanding dust shell
    // that is swept back into the tail, and sheds a few small fragments.
    float age = (u - OUTBURST) * CYCLE;                    // seconds since the flare
    float flare = 0.0;
    if (age > 0.0) {
        flare = exp(-age / 0.6) * smoothstep(0.0, 0.15, age);
        // Shell: thin, bright on the sunward side, centre pushed anti-sunward.
        vec2 sc0 = A * 0.010 * age * age;
        float R = 0.012 + 0.030 * age;
        float rr = length(d - sc0);
        float w = 0.003 + 0.004 * age;
        // Only the sunward hood is bright; the back side is blown into the tail.
        float facing = max(dot(normalize(d - sc0 + 1e-6), -A), 0.0);
        facing = 0.15 + 0.85 * facing * facing;
        float shell = exp(-pow((rr - R) / w, 2.0)) * facing * exp(-age / 1.6);
        // Puff: the inside of the shell is filled with faint fresh dust.
        float puff = exp(-pow(rr / (R * 1.1), 2.0)) * exp(-age / 1.2) * 0.25;
        cc += vec3(1.0, 0.92, 0.78) * (shell * 0.50 + puff);

        // Fragments: tiny secondary nuclei drifting off and back into the tail.
        float fr = exp(-age / 5.0);
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float ang = (hash1(n * 5.3 + fi * 1.7) - 0.5) * 2.4;     // mostly sunward/sideways
            vec2 dir = cos(ang) * (-A) + sin(ang) * S0;
            float spd = 0.014 + 0.012 * hash1(n + fi * 9.1);
            vec2 fp = dir * spd * age + A * 0.006 * age * age;
            vec2 q = d - fp;
            float fd = length(q);
            if (fd > 0.12) continue;
            float core = smoothstep(lpx * 1.6, lpx * 0.4, fd);
            float halo = exp(-fd / 0.005) * 0.55;
            // A short wisp of its own tail.
            float fa = dot(q, A), fx = dot(q, S0);
            float wisp = fa > 0.0 ? exp(-pow(fx / (0.002 + fa * 0.12), 2.0)) * exp(-fa / 0.04) * 0.35 : 0.0;
            cc += vec3(1.0, 0.95, 0.86) * (core * 0.8 + halo + wisp) * fr;
        }
    }

    // ---- coma and nucleus: compact, slightly teal outer coma, skewed a touch
    // into the tails; brightens near the sun and in the outburst. The coma is
    // kept at least a couple of pixels wide so the far comet reads as a star.
    float rs = length(d - A * 0.004);
    float cs = max(0.013, lpx * 1.4);
    float comaB = 0.45 + 0.45 * act + 0.35 * flare;
    float coma = comaB * exp(-rs / cs) + (0.10 + 0.20 * act + 0.25 * flare) * exp(-rs / (cs * 3.2));
    float nucleus = smoothstep(lpx * 1.8, lpx * 0.3, length(d)) * (0.7 + 0.3 * act);
    cc += mix(vec3(0.62, 0.92, 0.86), vec3(1.0, 0.97, 0.90), exp(-rs / (cs * 1.2))) * coma;
    cc += vec3(1.0) * nucleus;

    col += cc * fade * mix(1.0, textMask, 0.6);

    col = min(col, vec3(1.0)) * INTENSITY;
    fragColor = vec4(base.rgb + col, base.a);
}
