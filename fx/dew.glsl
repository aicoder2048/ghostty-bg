// dew — dew drops bead on the glass; now and then one slowly slides down, leaving a trail.
// zh: 露珠
// group: nature
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.50;   // overall brightness (0 = off)
const float COLUMNS   = 14.0;   // lanes that a sliding drop can run down

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A drop on glass, seen from the front. q is in drop units (radius 1).
// Light passes through it, so the rim on the lower side glows and a small
// bright highlight sits near the top-left.
float drop(vec2 q) {
    float r = length(q * vec2(1.0, 0.92));
    float inside = smoothstep(1.0, 0.85, r);
    float rim = inside * smoothstep(0.55, 0.95, r) * (0.35 + 0.65 * smoothstep(0.3, -0.8, q.y));
    float spot = smoothstep(0.32, 0.0, length(q - vec2(-0.35, 0.40)));
    return inside * 0.08 + rim * 0.55 + spot;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float aspect = iResolution.x / iResolution.y;
    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);

    float light = 0.0;

    // Resting beads: two grids, big and small, each cell maybe holding one.
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float scale = 9.0 + fi * 9.0;
        vec2 g = p * scale + fi * 3.7;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;
        float present = step(0.72 + fi * 0.08, hash(id + fi * 11.0));
        vec2 off = (vec2(hash(id + 2.1), hash(id + 6.3)) - 0.5) * 0.5;
        float rad = mix(0.10, 0.22, hash(id + 9.9));
        light += present * drop((f - off) / rad) * (1.0 - fi * 0.3);
    }

    // Sliding drops: in some lanes a drop creeps down over ~30 s, pauses, repeats.
    float lane = floor(p.x / aspect * COLUMNS);
    float lx = (lane + 0.5) / COLUMNS * aspect;
    float h = hash(vec2(lane, 3.3));
    if (h > 0.55) {
        float cycle = iTime / (25.0 + 20.0 * h) + h * 5.0;
        float phase = fract(cycle);
        float start = 0.35 + 0.6 * hash(vec2(lane, floor(cycle)));
        // Slides for the first 70% of the cycle, slowing and speeding a little.
        float s = clamp(phase / 0.7, 0.0, 1.0);
        float y = start - (s + 0.03 * sin(s * 20.0)) * (start + 0.1);
        float x = lx + 0.004 * sin(y * 12.0 + lane);    // wanders slightly side to side

        float rad = 0.018;
        light += drop((p - vec2(x, y)) / rad) * smoothstep(1.0, 0.85, phase);

        // The wet trail above it: a thin, faint streak that dries out over time.
        float tx = lx + 0.004 * sin(p.y * 12.0 + lane);
        float above = step(y, p.y) * step(p.y, start);
        float trail = smoothstep(0.004, 0.0, abs(p.x - tx)) * above
                    * exp(-(p.y - y) * 3.0) * smoothstep(1.0, 0.75, phase);
        light += trail * 0.35;
    }

    // Fainter over the top-left, where the text usually is.
    light *= 1.0 - 0.6 * smoothstep(0.7, 0.0, uv.x) * smoothstep(0.45, 0.0, uv.y);

    vec3 color = vec3(0.85, 0.93, 1.0) * min(light, 1.0);
    fragColor = vec4(base.rgb + color * INTENSITY, base.a);
}
