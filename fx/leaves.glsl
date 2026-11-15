// leaves — autumn leaves carried across by gusts of wind, turning as they fall.
// zh: 秋叶
// group: weather
// Part of ghostty-bg. Additive only: it adds light on top and never moves
// or distorts the text underneath.

const float INTENSITY = 0.60;   // overall brightness (0 = off)
const int   LAYERS    = 3;      // near, middle, far
const float WIND      = 0.11;   // sideways speed, in window-heights per second

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    // Ghostty's fragCoord has y pointing DOWN (0 at the top). The scene below is
    // easier to think about with y pointing up, so flip it once here.
    vec2 p0 = vec2(uv.x * iResolution.x / iResolution.y, 1.0 - uv.y);

    // The wind comes in gusts: it never stops, but it speeds up and eases off.
    float gust = iTime * WIND + 0.05 * sin(iTime * 0.45) + 0.02 * sin(iTime * 1.3);

    vec3 leaves = vec3(0.0);
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float scale = 4.0 + fi * 2.5;                 // far layers: smaller leaves
        float depth = 1.0 - fi * 0.22;                // far layers move slower

        vec2 p = p0;
        p.x -= gust * depth + fi * 0.53;              // blown to the right
        p.y += iTime * (0.045 + fi * 0.012) + fi * 0.31
             + 0.025 * sin(p.x * 6.0 + iTime * 0.8 + fi);   // falling, bobbing on the wind

        vec2 g = p * scale;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;

        float present = step(0.74, hash(id + fi * 9.0));              // ~26% of cells: sparse
        vec2 q = f - (vec2(hash(id + 2.2), hash(id + 5.8)) - 0.5) * 0.4;

        // Each leaf spins at its own pace.
        float angle = iTime * (0.5 + 1.1 * hash(id + 7.7)) + 6.2831 * hash(id + 3.1);
        float c = cos(angle), s = sin(angle);
        q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);

        // A leaf: an oval that comes to a point at both ends. Tumbling in 3D
        // shows up as the leaf getting narrower and wider.
        float len = mix(0.14, 0.22, hash(id + 8.4));
        float wide = len * (0.20 + 0.22 * abs(sin(iTime * 1.6 + 6.2831 * hash(id + 4.4))));
        float along = q.x / len;
        float edge = wide * (1.0 - along * along);
        float leaf = step(abs(along), 1.0) * smoothstep(0.012, 0.0, abs(q.y) - edge);

        // Orange, red or yellow, one colour per leaf.
        float tone = hash(id + 6.6);
        vec3 color = tone < 0.4 ? vec3(1.00, 0.55, 0.15)
                   : tone < 0.7 ? vec3(0.95, 0.30, 0.15)
                                : vec3(1.00, 0.80, 0.25);

        leaves += color * present * leaf * (0.85 - fi * 0.15);
    }

    fragColor = vec4(base.rgb + min(leaves, vec3(1.0)) * INTENSITY, base.a);
}
