// dandelion — dandelion seeds float up and sideways on the breeze, slowly turning.
// zh: 蒲公英
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.55;   // overall brightness (0 = off)
const int   LAYERS    = 2;      // near, far
const float WIND      = 0.05;   // sideways speed, in window-heights per second

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Distance from p to the segment a-b.
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// One seed, upright: a seed at the bottom, a thin stalk, and on top a fan of
// fine hairs ending in tiny dots. q is in seed units (about 1 tall).
float seed(vec2 q) {
    float stalk = 0.7 * smoothstep(0.014, 0.0, segment(q, vec2(0.0, -0.45), vec2(0.0, 0.05)));
    float body = smoothstep(0.05, 0.0, length((q - vec2(0.0, -0.47)) * vec2(2.2, 1.0)) - 0.04);

    // The tuft: hairs radiate from the top of the stalk, mostly upward.
    vec2 t = q - vec2(0.0, 0.05);
    float r = length(t);
    float a = atan(t.x, t.y);                                  // 0 = straight up
    float spokes = 14.0;
    float k = abs(fract(a / 3.1416 * spokes * 0.5) - 0.5);     // distance to nearest hair, in turns
    float hair = smoothstep(0.08, 0.0, k * r * 6.0) * step(r, 0.42) * step(abs(a), 1.45);
    float tips = smoothstep(0.06, 0.0, abs(r - 0.42)) * smoothstep(0.25, 0.0, k) * step(abs(a), 1.45);
    float fluff = smoothstep(0.45, 0.0, r) * step(abs(a), 1.5) * 0.18;  // soft haze between hairs

    return max(max(stalk, body), max(hair * 0.75, max(tips, fluff)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, 1.0 - uv.y);

    vec3 color = vec3(0.0);
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float scale = 3.0 + fi * 2.0;                  // far layer: smaller seeds
        float depth = 1.0 - fi * 0.35;                 // far layer drifts slower

        vec2 p = p0;
        p.x -= iTime * WIND * depth + fi * 0.37;       // carried to the right
        p.y -= iTime * 0.035 * depth + fi * 0.21       // rising
             + 0.03 * sin(p.x * 3.0 + iTime * 0.5 + fi);   // bobbing on the breeze

        vec2 g = p * scale;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        float present = step(0.80, hash(id + fi * 7.0));       // ~20% of cells: sparse
        vec2 q = f - (vec2(hash(id + 1.3), hash(id + 4.7)) - 0.5) * 0.2;

        // A gentle rocking turn, not a spin: seeds float upright-ish.
        float angle = 0.5 * sin(iTime * (0.3 + 0.4 * hash(id + 2.9)) + 6.2831 * hash(id + 8.1)) - 0.3;
        float c = cos(angle), s = sin(angle);
        q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);

        float size = mix(0.45, 0.65, hash(id + 5.5));
        color += vec3(0.95, 0.95, 0.88) * present * seed(q / size) * (1.0 - fi * 0.35);
    }

    // Fainter over the top-left, where the text usually is.
    float textArea = smoothstep(0.9, 0.2, uv.x) * smoothstep(0.4, 0.0, uv.y);
    color *= 1.0 - 0.5 * textArea;

    fragColor = vec4(base.rgb + min(color, vec3(1.0)) * INTENSITY, base.a);
}
