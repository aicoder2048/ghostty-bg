// embers — a crackling campfire in the lower right, with sparks swirling up into the dark.
// zh: 篝火
// group: nature
// Part of ghostty-bg. It only draws on top and never moves or distorts the
// text underneath.

const float INTENSITY   = 0.90;   // overall strength (0 = off)
const float FIRE_X      = 0.73;   // fire centre, as a fraction of window width
const float FIRE_HEIGHT = 0.33;   // flame height, in window heights
const int   SPARKS      = 26;     // number of rising sparks
const float SPARK_SIZE  = 1.0;    // spark size multiplier
const float GLOW        = 0.85;   // strength of the warm light around the fire

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        s += a * vnoise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return s;
}

// Distance from point p to the segment a-b.
float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Fire colour ramp: deep red at the edges, orange, then yellow-white in the core.
vec3 fireColor(float t) {
    vec3 red    = vec3(0.70, 0.06, 0.01);
    vec3 orange = vec3(1.00, 0.42, 0.04);
    vec3 yellow = vec3(1.00, 0.82, 0.30);
    vec3 white  = vec3(1.00, 0.97, 0.85);
    vec3 c = mix(red, orange, smoothstep(0.0, 0.35, t));
    c = mix(c, yellow, smoothstep(0.35, 0.70, t));
    return mix(c, white, smoothstep(0.75, 1.0, t));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float t = iTime;
    vec2 c = vec2(FIRE_X * aspect, 0.0);             // fire sits on the bottom edge
    vec3 col = base.rgb;

    // Overall flicker shared by the glow and the embers, so they pulse together.
    float flick = 0.80 + 0.12 * sin(t * 7.3) * sin(t * 3.1) + 0.08 * sin(t * 17.0);

    // --- Warm light spilling over the lower part of the window -------------
    vec2 gd = (p - c - vec2(0.0, 0.10)) / vec2(1.25, 0.85);
    float glow = exp(-dot(gd, gd) * 4.0) * 0.7 + exp(-dot(gd, gd) * 22.0) * 0.6;
    col += vec3(1.0, 0.38, 0.08) * glow * GLOW * flick * INTENSITY;

    // Flame-local coords: 1 unit = flame height, origin at the base of the flame.
    vec2 q = (p - c - vec2(0.0, 0.06)) / FIRE_HEIGHT;

    // --- Logs: two crossed, dark, with glowing cracks ----------------------
    float d1 = segDist(q, vec2(-0.48, -0.17), vec2(0.42, 0.04));
    float d2 = segDist(q, vec2(0.48, -0.17), vec2(-0.40, 0.05));
    float d3 = segDist(q, vec2(-0.30, -0.16), vec2(0.32, -0.14));
    float logD = min(min(d1, d2), d3);
    float logA = smoothstep(0.065, 0.055, logD);
    if (logA > 0.0) {
        // Cracks that glow and breathe: noise along the bark, brighter near the fire.
        float crack = vnoise(q * vec2(28.0, 18.0) + vec2(0.0, t * 0.6));
        float hotSpot = smoothstep(0.55, 0.0, length(q - vec2(0.0, -0.05)));
        float ember = smoothstep(0.55, 0.85, crack) * (0.4 + 0.9 * hotSpot)
                    * (0.7 + 0.3 * sin(t * 5.0 + crack * 20.0));
        vec3 bark = vec3(0.10, 0.05, 0.03) * (1.0 - smoothstep(0.03, 0.065, logD) * 0.5);
        vec3 logCol = bark + vec3(1.0, 0.35, 0.05) * ember * 1.4;
        col = mix(col, logCol, logA * 0.92 * INTENSITY);
    }

    // --- Ember bed at the base ---------------------------------------------
    vec2 bq = (q - vec2(0.0, -0.17)) / vec2(0.55, 0.08);
    float bed = smoothstep(1.0, 0.2, length(bq));
    float coals = vnoise(q * vec2(22.0, 14.0) + vec2(t * 0.3, 0.0));
    col += vec3(1.0, 0.30, 0.04) * bed * (0.35 + 0.9 * coals * coals) * flick * INTENSITY;

    // --- Flame body --------------------------------------------------------
    if (q.y > -0.25 && q.y < 1.3 && abs(q.x) < 0.7) {
        float y = max(q.y, 0.0);
        // Noise that scrolls upward makes the flame lick and wobble.
        float n1 = fbm(vec2(q.x * 3.0, q.y * 2.2 - t * 2.6));
        float n2 = fbm(vec2(q.x * 6.0 + 3.0, q.y * 4.0 - t * 4.2));
        float x = q.x + (n1 - 0.5) * 0.35 * (0.2 + y) + 0.04 * sin(t * 1.7 + q.y * 3.0) * y;

        // Teardrop width: wide at the bottom, narrowing to a tip.
        float w = 0.40 * pow(clamp(1.0 - y / 1.05, 0.0, 1.0), 0.9)
                * smoothstep(-0.22, 0.10, q.y);
        float heat = 1.0 - abs(x) / max(w, 1e-3);
        // Tongues: break up the top with fast noise so it splits into licks.
        heat -= (0.95 - n2 * 1.5) * y * 1.0;
        heat += 0.15 * (1.0 - y);
        heat = clamp(heat, 0.0, 1.0);

        float a = smoothstep(0.0, 0.18, heat);
        vec3 fc = fireColor(pow(heat, 0.9) * (1.05 - 0.35 * y));
        // Mostly additive so it glows, but darken the back slightly so the core
        // still reads as white on a bright background.
        col = mix(col, col * 0.5, a * 0.35 * INTENSITY);
        col += fc * a * (0.75 + 0.6 * heat) * INTENSITY;
    }

    // --- Sparks ------------------------------------------------------------
    vec3 sparks = vec3(0.0);
    for (int i = 0; i < SPARKS; i++) {
        float fi = float(i);
        float a = hash1(fi * 12.9898 + 1.0);
        float b = hash1(fi * 78.233 + 2.0);
        float s = hash1(fi * 39.17 + 3.0);

        // Each spark lives for one cycle; random phase so every stage shows at t=0.
        float speed = 0.22 + 0.25 * b;
        float cycle = t * speed + a * 9.0;
        float life = fract(cycle);
        float gen = floor(cycle);
        float r = hash1(fi * 5.3 + gen * 17.7);       // new spark, new path
        float r2 = hash1(fi * 2.1 + gen * 31.3);

        // Some sparks only rise a little, a few climb most of the window.
        float topH = 0.30 + 0.70 * r2 * r2 + 0.15 * s;
        float zig = (0.03 + 0.05 * r) * (0.3 + life);
        float freq = 4.0 + 5.0 * a;

        // Position at time "life" and a little earlier, for the trail.
        float l0 = life;
        float l1 = max(life - 0.05, 0.0);
        vec2 x0 = vec2(c.x + (r - 0.5) * 0.18, 0.08);
        float drift = (r2 - 0.45) * 0.30;
        vec2 h0 = x0 + vec2(drift * l0 + zig * sin(l0 * freq * 3.0 + fi), topH * (l0 + 0.4 * l0 * l0) / 1.4);
        vec2 h1 = x0 + vec2(drift * l1 + zig * sin(l1 * freq * 3.0 + fi), topH * (l1 + 0.4 * l1 * l1) / 1.4);

        float d = segDist(p, h1, h0);
        float dh = length(p - h0);
        float size = (0.0045 + 0.0075 * s * s) * SPARK_SIZE;
        float fade = smoothstep(0.0, 0.06, life) * pow(1.0 - life, 1.3);
        float tw = 0.7 + 0.3 * sin(t * (13.0 + 9.0 * a) + fi * 4.0);

        // Fades along the trail so the head stays brightest.
        float along = clamp(length(p - h1) / max(length(h0 - h1), 1e-4), 0.0, 1.0);
        float core = size * size / (d * d + size * size * 0.35) * (0.25 + 0.75 * along);
        float halo = 0.35 * exp(-dh * dh / (size * size * 30.0));
        vec3 hot = mix(vec3(1.0, 0.22, 0.03), vec3(1.0, 0.80, 0.40), 1.0 - life);   // cools to red
        sparks += hot * (core + halo) * fade * tw;
    }
    col += min(sparks, vec3(1.2)) * INTENSITY;

    fragColor = vec4(min(col, vec3(1.0)), base.a);
}
