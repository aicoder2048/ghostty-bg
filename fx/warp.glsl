// warp — cinematic hyperspace: tinted star streaks pour from a vanishing point, with slow nebula swirl and periodic surges.
// zh: 星河穿梭
// group: space
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.75;   // overall strength (0 = off)
const float SPEED     = 0.55;   // cruise speed of the stars (keep it calm)
const float SURGE     = 1.6;    // extra distance travelled during each acceleration surge
const float PERIOD    = 9.0;    // seconds between surges
const float NEBULA    = 0.22;   // strength of the faint coloured tunnel
const float CALM_TL   = 0.30;   // how much light is left over the top-left text block (0..1)

float hash1(float n) { return fract(sin(n) * 43758.5453123); }

float vnoise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash1(dot(i, vec2(1.0, 57.0)));
    float b = hash1(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
    float c = hash1(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
    float d = hash1(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Surge timing. The surge window is a smootherstep inside each period, so the
// travelled distance is continuous (no popping) and its derivative is a soft bell.
// Window sits early in the cycle so the first surge arrives within ~2 s.
const float W0 = 0.12, W1 = 0.42;
float surgeStep(float x) {               // 0 -> 1 across the window
    float s = clamp((x - W0) / (W1 - W0), 0.0, 1.0);
    return s * s * s * (s * (s * 6.0 - 15.0) + 10.0);
}
float surgeEnv(float x) {                // 0..1 bell, peak mid-window
    float s = clamp((x - W0) / (W1 - W0), 0.0, 1.0);
    return 16.0 * s * s * (1.0 - s) * (1.0 - s);
}

// One layer of streaks on a polar grid: the angle is cut into thin rays and each
// ray into cells along log(radius). Sliding cells outward in log space gives
// perspective for free: dots near the centre grow into long, bright streaks.
vec3 layer(vec2 d, float r, float a, float sectors, float spd, float phase,
           float env, float seed) {
    float s = floor(a * sectors);
    float h = hash1(s * 1.731 + seed);
    float centre = (s + 0.5 + (h - 0.5) * 0.6) / sectors;
    float perp = abs(a - centre) * 6.28318 * r;

    float u = log(r) * 2.6 - phase * spd + h * 17.0;
    float cell = floor(u);
    float f = fract(u);
    float hc = hash1(cell * 13.17 + s * 7.31 + seed);
    if (hc < 0.62) return vec3(0.0);                     // most cells are empty

    float hb = hash1(cell * 3.7 + s * 1.9 + seed * 5.0);
    float head = 0.55 + 0.4 * hb;
    float len = (0.06 + 0.22 * hb) * (1.0 + 2.0 * env);   // streaks stretch in a surge
    float tail = smoothstep(head - len, head, f) * smoothstep(head + 0.025, head, f);
    tail *= tail;                                          // bright head, soft fading tail

    float w = 0.0012 + 0.0022 * r;
    float core = smoothstep(w, 0.0, perp);
    float halo = exp(-perp / (w * 3.5));

    float bright = (0.35 + 0.65 * hb) * smoothstep(0.03, 0.40, r);   // fade in from the centre
    vec3 fringe = mix(vec3(0.62, 0.48, 1.0), vec3(0.40, 0.85, 1.0), hash1(s + seed * 2.0));
    return tail * bright * (core * vec3(0.86, 0.93, 1.0) + halo * fringe * 0.35);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN; flip once so the scene is y-up.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    // Vanishing point right of centre and a little low, so the top-left stays calm.
    vec2 c = vec2(aspect * 0.64, 0.44) + 0.02 * vec2(sin(iTime * 0.07), cos(iTime * 0.05));
    vec2 d = p - c;
    float r = max(length(d), 1e-4);
    float a = atan(d.y, d.x) / 6.28318 + 0.5;

    float cyc = iTime / PERIOD;
    float x = fract(cyc);
    float env = surgeEnv(x);
    float phase = iTime * SPEED + SURGE * (floor(cyc) + surgeStep(x));

    vec3 col = layer(d, r, a, 64.0, 1.00, phase, env, 0.0)
             + layer(d, r, a, 100.0, 0.75, phase, env, 11.3) * 0.75
             + layer(d, r, a, 150.0, 0.55, phase, env, 23.9) * 0.55;

    // Soft nebula tunnel: spiral bands broken up by noise, slowly rotating.
    float lr = log(r);
    float ang = a * 6.28318;
    float band = 0.5 + 0.5 * sin(ang * 3.0 + lr * 3.5 - iTime * 0.12
                                 + 1.3 * sin(ang * 2.0 - lr * 2.0 + iTime * 0.07));
    float t = iTime * 0.04;
    mat2 rot = mat2(cos(t), -sin(t), sin(t), cos(t));
    float n = vnoise(rot * d * 3.0 + vec2(lr * 1.5 - phase * 0.3, 0.0));
    float ring = smoothstep(0.04, 0.25, r) * exp(-r * 1.6);
    vec3 nebCol = mix(vec3(0.42, 0.28, 0.75), vec3(0.18, 0.55, 0.70), band);
    col += nebCol * band * (0.4 + 0.8 * n) * ring * NEBULA * (1.0 + 0.6 * env);

    // Centre glow: a faint ever-present core that blooms during each surge.
    col += vec3(0.80, 0.88, 1.0) * (0.05 + 0.32 * env) * exp(-r * r / (0.006 + 0.02 * env));

    // Keep the top-left (where the shell text lives) thin and dim.
    float tl = smoothstep(0.62, 0.20, uv.x) * smoothstep(0.55, 0.15, uv.y);
    col *= mix(1.0, CALM_TL, tl);

    col = min(col, vec3(1.0)) * INTENSITY;
    fragColor = vec4(base.rgb + col * (1.0 - 0.5 * base.rgb), base.a);
}
